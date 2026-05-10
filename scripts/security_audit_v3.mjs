// Security audit v3 - Check policies via pg_policies system view
// and check if the migration was properly applied
// Also test that anon CAN see public+approved videos

const SUPABASE_URL = 'https://zwjdxizbakfhklpjoalt.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp3amR4aXpiYWtmaGtscGpvYWx0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYxNTY2NzgsImV4cCI6MjA3MTczMjY3OH0.DYVh9bSM37OC6Admo7RANJrVcpg2pzX5NEc01hPcJy0';

async function signUpUser(email, password) {
  const resp = await fetch(`${SUPABASE_URL}/auth/v1/signup`, {
    method: 'POST',
    headers: { 'apikey': SUPABASE_ANON_KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password })
  });
  return { status: resp.status, data: await resp.json() };
}

async function authFetch(endpoint, token) {
  const resp = await fetch(`${SUPABASE_URL}${endpoint}`, {
    headers: {
      'apikey': SUPABASE_ANON_KEY,
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    }
  });
  const text = await resp.text();
  let data;
  try { data = JSON.parse(text); } catch { data = text; }
  return { status: resp.status, data, count: Array.isArray(data) ? data.length : 'N/A' };
}

async function rpcCall(fnName, params, token) {
  const h = {
    'apikey': SUPABASE_ANON_KEY,
    'Authorization': `Bearer ${token || SUPABASE_ANON_KEY}`,
    'Content-Type': 'application/json'
  };
  const resp = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${fnName}`, {
    method: 'POST',
    headers: h,
    body: JSON.stringify(params)
  });
  const text = await resp.text();
  let data;
  try { data = JSON.parse(text); } catch { data = text; }
  return { status: resp.status, data };
}

console.log('=== FutbolTalent Pro - Security Audit V3 ===\n');

// ─── Check if we can query system catalog for policies ───
console.log('═══ CHECK 1: Query RLS policies via authenticated user ═══');
const ts = Date.now();
const adminEmail = `audit_v3_${ts}@test-ft.com`;
const adminPwd = 'AuditV3Pass2026!@#$';
const signup = await signUpUser(adminEmail, adminPwd);
const token = signup.data?.access_token;

if (token) {
  console.log('Authenticated user created for system queries.\n');
  
  // Try to read pg_policies (usually not available via REST, but let's try)
  // We'll check videos and user_progress policies by examining behavior instead.

  // ─── CHECK: What videos does this random user see? ───
  console.log('═══ CHECK 2: Random user - videos by properties ═══');
  const allVids = await authFetch('/rest/v1/videos?select=id,is_public,moderation_status,user_id&limit=100', token);
  console.log(`Total visible: ${allVids.count}`);
  
  if (Array.isArray(allVids.data)) {
    const byPublic = {};
    const byMod = {};
    allVids.data.forEach(v => {
      byPublic[v.is_public] = (byPublic[v.is_public] || 0) + 1;
      byMod[v.moderation_status] = (byMod[v.moderation_status] || 0) + 1;
    });
    console.log(`  By is_public: ${JSON.stringify(byPublic)}`);
    console.log(`  By moderation_status: ${JSON.stringify(byMod)}`);

    // Check which user_ids are visible
    const uniqueUsers = [...new Set(allVids.data.map(v => v.user_id))];
    console.log(`  Unique video owners visible: ${uniqueUsers.length}`);
    
    // For each visible user, check if they are minors with pending guardian
    for (const uid of uniqueUsers.slice(0, 5)) {
      const userInfo = await authFetch(`/rest/v1/users?select=user_id,is_minor,guardian_status,visibility_status&user_id=eq.${uid}`, token);
      if (Array.isArray(userInfo.data) && userInfo.data.length > 0) {
        const u = userInfo.data[0];
        console.log(`    Owner ${uid}: minor=${u.is_minor} guardian=${u.guardian_status} vis=${u.visibility_status}`);
        if (u.is_minor && u.guardian_status === 'pending') {
          console.log('    ⚠️  This is a minor with pending guardian - videos SHOULD NOT be visible!');
          // Check if any of these are the visible ones
          const minorVids = allVids.data.filter(v => v.user_id === uid);
          console.log(`    Videos visible from this minor: ${minorVids.length}`);
          minorVids.forEach(v => console.log(`      id=${v.id} public=${v.is_public} mod=${v.moderation_status}`));
        }
      }
    }
  }
  console.log();

  // ─── CHECK 3: Videos specifically from minors with pending guardian ───
  console.log('═══ CHECK 3: Videos from minors with pending guardian ═══');
  const minors = await authFetch('/rest/v1/users?select=user_id&is_minor=eq.true&guardian_status=eq.pending&limit=50', token);
  console.log(`Minors with pending guardian: ${minors.count}`);
  
  if (Array.isArray(minors.data)) {
    let leakedCount = 0;
    for (const minor of minors.data.slice(0, 10)) {
      const minorVids = await authFetch(`/rest/v1/videos?select=id,is_public,moderation_status&user_id=eq.${minor.user_id}&limit=10`, token);
      if (Array.isArray(minorVids.data) && minorVids.data.length > 0) {
        console.log(`  Minor ${minor.user_id}: ${minorVids.data.length} videos visible`);
        minorVids.data.forEach(v => console.log(`    id=${v.id} public=${v.is_public} mod=${v.moderation_status}`));
        leakedCount += minorVids.data.length;
      }
    }
    if (leakedCount === 0) {
      console.log('  ✅ No videos from pending-guardian minors visible to random user');
    } else {
      console.log(`  ⚠️  CRITICAL: ${leakedCount} videos from pending-guardian minors ARE visible!`);
    }
  }
  console.log();

  // ─── CHECK 4: user_progress from others ───
  console.log('═══ CHECK 4: user_progress access ═══');
  const progress = await authFetch('/rest/v1/user_progress?select=id,user_id&limit=10', token);
  console.log(`user_progress visible: ${progress.count}`);
  if (progress.count > 0) {
    console.log('⚠️  Random user sees user_progress (should be 0 for random user)');
  } else {
    console.log('✅ Random user cannot see any user_progress');
  }
  console.log();

  // ─── CHECK 5: Test is_player_guardian_approved function ───
  console.log('═══ CHECK 5: Function tests ═══');
  
  // Test with a minor who has pending guardian
  if (Array.isArray(minors.data) && minors.data.length > 0) {
    const pendingMinor = minors.data[0].user_id;
    const approvedResult = await rpcCall('is_player_guardian_approved', { p_player_id: pendingMinor }, token);
    console.log(`is_player_guardian_approved(${pendingMinor}): ${JSON.stringify(approvedResult.data)} (status ${approvedResult.status})`);
    console.log(`  Expected: false (minor with pending guardian)`);
    
    // Test with an approved minor
    const approvedMinors = await authFetch('/rest/v1/users?select=user_id&is_minor=eq.true&guardian_status=eq.approved&limit=1', token);
    if (Array.isArray(approvedMinors.data) && approvedMinors.data.length > 0) {
      const approvedMinor = approvedMinors.data[0].user_id;
      const approvedResult2 = await rpcCall('is_player_guardian_approved', { p_player_id: approvedMinor }, token);
      console.log(`is_player_guardian_approved(${approvedMinor}): ${JSON.stringify(approvedResult2.data)} (status ${approvedResult2.status})`);
      console.log(`  Expected: true (minor with approved guardian)`);
    }
  }
}

console.log('\n=== Audit V3 Complete ===');
