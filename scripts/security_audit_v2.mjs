// Security audit v2 - deeper investigation  
// Tests with correct anon approach (RangeError header for count, individual checks)

const SUPABASE_URL = 'https://zwjdxizbakfhklpjoalt.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp3amR4aXpiYWtmaGtscGpvYWx0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYxNTY2NzgsImV4cCI6MjA3MTczMjY3OH0.DYVh9bSM37OC6Admo7RANJrVcpg2pzX5NEc01hPcJy0';

// Parse the JWT to extract the user token from probe 6
function parseJwt(token) {
  const base64Url = token.split('.')[1];
  const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
  const jsonPayload = Buffer.from(base64, 'base64').toString();
  return JSON.parse(jsonPayload);
}

async function anonFetch(endpoint) {
  const resp = await fetch(`${SUPABASE_URL}${endpoint}`, {
    headers: {
      'apikey': SUPABASE_ANON_KEY,
      'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Prefer': 'count=exact'
    }
  });
  const text = await resp.text();
  let data;
  try { data = JSON.parse(text); } catch { data = text; }
  const contentRange = resp.headers.get('content-range');
  return { status: resp.status, data, contentRange, count: Array.isArray(data) ? data.length : 'N/A', headers: Object.fromEntries(resp.headers.entries()) };
}

async function authFetch(endpoint, token) {
  const resp = await fetch(`${SUPABASE_URL}${endpoint}`, {
    headers: {
      'apikey': SUPABASE_ANON_KEY,
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Prefer': 'count=exact'
    }
  });
  const text = await resp.text();
  let data;
  try { data = JSON.parse(text); } catch { data = text; }
  const contentRange = resp.headers.get('content-range');
  return { status: resp.status, data, contentRange, count: Array.isArray(data) ? data.length : 'N/A' };
}

async function signUpUser(email, password) {
  const resp = await fetch(`${SUPABASE_URL}/auth/v1/signup`, {
    method: 'POST',
    headers: {
      'apikey': SUPABASE_ANON_KEY,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ email, password })
  });
  return { status: resp.status, data: await resp.json() };
}

console.log('=== FutbolTalent Pro - Security Audit V2 ===\n');
console.log(`Project: zwjdxizbakfhklpjoalt`);
console.log(`Time: ${new Date().toISOString()}\n`);

// ─── Check anon JWT claims ───
console.log('─── JWT Analysis ───');
const anonClaims = parseJwt(SUPABASE_ANON_KEY);
console.log(`Role: ${anonClaims.role}`);
console.log(`Ref: ${anonClaims.ref}`);
console.log();

// ─── PROBE 1: anon reads videos (full debug) ───
console.log('═══ PROBE 1: anon reads ALL videos ═══');
const r1 = await anonFetch('/rest/v1/videos?select=id,is_public,moderation_status,user_id&limit=5');
console.log(`HTTP Status: ${r1.status}`);
console.log(`Content-Range: ${r1.contentRange}`);
console.log(`Data type: ${typeof r1.data}`);
if (r1.status === 401) {
  console.log(`Response body: ${JSON.stringify(r1.data)}`);
  console.log('NOTE: 401 = anon has no access at all (no GRANT or RLS blocks). This is SECURE but check if GRANT exists.');
} else if (r1.status === 200) {
  console.log(`Rows returned: ${r1.count}`);
  if (Array.isArray(r1.data)) {
    r1.data.forEach(v => console.log(`  id=${v.id} public=${v.is_public} mod=${v.moderation_status}`));
  }
}
console.log();

// ─── PROBE 2: anon reads user_progress (full debug) ───
console.log('═══ PROBE 2: anon reads user_progress ═══');
const r2 = await anonFetch('/rest/v1/user_progress?select=id,user_id&limit=5');
console.log(`HTTP Status: ${r2.status}`);
if (r2.status === 401) {
  console.log(`Response body: ${JSON.stringify(r2.data)}`);
  console.log('NOTE: 401 = anon has no access. SECURE.');
} else if (r2.status === 200) {
  console.log(`Rows returned: ${r2.count}`);
}
console.log();

// ─── PROBE 3: Create random authenticated user ───
console.log('═══ PROBE 3: Creating random authenticated user ═══');
const ts = Date.now();
const randomEmail = `audit_v2_${ts}@test-ft.com`;
const randomPassword = 'AuditPass2026!@#$';
const signup = await signUpUser(randomEmail, randomPassword);
console.log(`Signup status: ${signup.status}`);

let randomToken = null;
if (signup.data.access_token) {
  randomToken = signup.data.access_token;
  const claims = parseJwt(randomToken);
  console.log(`User ID: ${claims.sub}`);
  console.log(`Role: ${claims.role}`);
} else {
  console.log(`Signup response: ${JSON.stringify(signup.data).slice(0, 300)}`);
}
console.log();

if (randomToken) {
  // ─── PROBE 4: Random user reads ALL videos ───
  console.log('═══ PROBE 4: Random user reads ALL videos ═══');
  const r4 = await authFetch('/rest/v1/videos?select=id,is_public,moderation_status,user_id&limit=50', randomToken);
  console.log(`HTTP Status: ${r4.status}, Rows: ${r4.count}, Range: ${r4.contentRange}`);
  if (Array.isArray(r4.data)) {
    const nonPublic = r4.data.filter(v => v.is_public !== true);
    const nonApproved = r4.data.filter(v => v.moderation_status !== 'approved');
    console.log(`  Total: ${r4.data.length}`);
    console.log(`  Non-public: ${nonPublic.length}`);
    console.log(`  Non-approved: ${nonApproved.length}`);
    if (nonPublic.length > 0) {
      console.log('  ⚠️  CRITICAL: Random user sees non-public videos!');
      nonPublic.forEach(v => console.log(`    id=${v.id} public=${v.is_public} mod=${v.moderation_status} user=${v.user_id}`));
    }
    if (nonApproved.length > 0) {
      console.log('  ⚠️  CRITICAL: Random user sees non-approved videos!');
      nonApproved.forEach(v => console.log(`    id=${v.id} public=${v.is_public} mod=${v.moderation_status} user=${v.user_id}`));
    }
    if (nonPublic.length === 0 && nonApproved.length === 0) {
      console.log('  ✅ Random user only sees public+approved videos');
    }
  }
  console.log();

  // ─── PROBE 5: Random user reads private videos ───
  console.log('═══ PROBE 5: Random user reads private videos ═══');
  const r5 = await authFetch('/rest/v1/videos?select=id,is_public,moderation_status&is_public=eq.false&limit=10', randomToken);
  console.log(`HTTP Status: ${r5.status}, Rows: ${r5.count}`);
  if (r5.count > 0) {
    console.log('⚠️  CRITICAL: Random user CAN read private videos!');
  } else {
    console.log('✅ Random user CANNOT read private videos');
  }
  console.log();

  // ─── PROBE 6: Random user reads pending videos ───
  console.log('═══ PROBE 6: Random user reads pending videos ═══');
  const r6 = await authFetch('/rest/v1/videos?select=id,is_public,moderation_status&moderation_status=eq.pending&limit=10', randomToken);
  console.log(`HTTP Status: ${r6.status}, Rows: ${r6.count}`);
  if (r6.count > 0) {
    console.log('⚠️  CRITICAL: Random user CAN read pending videos!');
  } else {
    console.log('✅ Random user CANNOT read pending videos');
  }
  console.log();

  // ─── PROBE 7: Random user reads user_progress ───
  console.log('═══ PROBE 7: Random user reads user_progress ═══');
  const r7 = await authFetch('/rest/v1/user_progress?select=id,user_id&limit=10', randomToken);
  console.log(`HTTP Status: ${r7.status}, Rows: ${r7.count}`);
  if (r7.count > 0) {
    console.log('⚠️  CRITICAL: Random user CAN read user_progress!');
    if (Array.isArray(r7.data)) {
      r7.data.forEach(p => console.log(`  user_id=${p.user_id}`));
    }
  } else {
    console.log('✅ Random user CANNOT read user_progress');
  }
  console.log();
}

// ─── PROBE 8: Weak password test ───
console.log('═══ PROBE 8: Weak password signup test ═══');
const weakEmail = `weak_pwd_${ts}@test-ft.com`;
const weakResult = await signUpUser(weakEmail, '123456');
console.log(`Status: ${weakResult.status}`);
if (weakResult.data.access_token || weakResult.data.id) {
  console.log('⚠️  CRITICAL: Weak password (123456) signup SUCCEEDED!');
  console.log(`  BUG-ONB-010 still OPEN - password policy NOT enforced on Auth`);
  console.log(`  User ID: ${weakResult.data.id || weakResult.data.user?.id}`);
} else {
  console.log('✅ Weak password rejected by Auth');
  console.log(`  Response: ${JSON.stringify(weakResult.data).slice(0, 200)}`);
}

// ─── PROBE 9: Verify videos in DB have the expected variety ───
console.log('\n═══ PROBE 9: Check if DB actually has private/pending videos ═══');
// We can only check from an admin perspective or check what authenticated sees
if (randomToken) {
  // Check total count of videos visible
  const rAll = await authFetch('/rest/v1/videos?select=id&limit=100', randomToken);
  console.log(`Total videos visible to random user: ${rAll.count}`);
  
  // Check users table for minor status
  const rUsers = await authFetch('/rest/v1/users?select=user_id,is_minor,guardian_status,visibility_status&is_minor=eq.true&limit=10', randomToken);
  console.log(`Minor users visible: ${rUsers.count}`);
  if (Array.isArray(rUsers.data) && rUsers.data.length > 0) {
    rUsers.data.forEach(u => console.log(`  user_id=${u.user_id} minor=${u.is_minor} guardian=${u.guardian_status} vis=${u.visibility_status}`));
  }
}

console.log('\n=== Audit V2 Complete ===');
