// Security audit script for FutbolTalent Pro Supabase project
// Tests RLS policies on videos and user_progress tables

const SUPABASE_URL = 'https://zwjdxizbakfhklpjoalt.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp3amR4aXpiYWtmaGtscGpvYWx0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYxNTY2NzgsImV4cCI6MjA3MTczMjY3OH0.DYVh9bSM37OC6Admo7RANJrVcpg2pzX5NEc01hPcJy0';

const headers = {
  'apikey': SUPABASE_ANON_KEY,
  'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
  'Content-Type': 'application/json',
  'Prefer': 'return=representation'
};

async function fetchSupabase(endpoint, extraHeaders = {}) {
  const resp = await fetch(`${SUPABASE_URL}${endpoint}`, {
    headers: { ...headers, ...extraHeaders }
  });
  const text = await resp.text();
  let data;
  try { data = JSON.parse(text); } catch { data = text; }
  return { status: resp.status, data };
}

async function signUpTestUser(email, password) {
  const resp = await fetch(`${SUPABASE_URL}/auth/v1/signup`, {
    method: 'POST',
    headers: {
      'apikey': SUPABASE_ANON_KEY,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ email, password })
  });
  const data = await resp.json();
  return { status: resp.status, data };
}

async function signInUser(email, password) {
  const resp = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: {
      'apikey': SUPABASE_ANON_KEY,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ email, password })
  });
  const data = await resp.json();
  return { status: resp.status, data };
}

function headersWithToken(token) {
  return {
    'apikey': SUPABASE_ANON_KEY,
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  };
}

async function fetchWithToken(endpoint, token) {
  const resp = await fetch(`${SUPABASE_URL}${endpoint}`, {
    headers: headersWithToken(token)
  });
  const text = await resp.text();
  let data;
  try { data = JSON.parse(text); } catch { data = text; }
  return { status: resp.status, data, count: Array.isArray(data) ? data.length : 'N/A' };
}

console.log('=== FutbolTalent Pro - Security Audit ===\n');
console.log(`Project: zwjdxizbakfhklpjoalt`);
console.log(`Time: ${new Date().toISOString()}\n`);

// ─── PROBE 1: anon reads all videos ───
console.log('─── PROBE 1: anon reads ALL videos ───');
const allVids = await fetchSupabase('/rest/v1/videos?select=id,is_public,moderation_status,user_id&limit=20');
console.log(`Status: ${allVids.status}`);
console.log(`Count: ${Array.isArray(allVids.data) ? allVids.data.length : 'N/A'}`);
if (Array.isArray(allVids.data)) {
  allVids.data.forEach(v => console.log(`  id=${v.id} public=${v.is_public} mod=${v.moderation_status} user=${v.user_id}`));
}
console.log();

// ─── PROBE 2: anon reads videos where is_public=false ───
console.log('─── PROBE 2: anon reads videos is_public=false ───');
const privateVids = await fetchSupabase('/rest/v1/videos?select=id,is_public,moderation_status&is_public=eq.false&limit=10');
console.log(`Status: ${privateVids.status}`);
console.log(`Count: ${Array.isArray(privateVids.data) ? privateVids.data.length : 'N/A'}`);
if (Array.isArray(privateVids.data) && privateVids.data.length > 0) {
  console.log('⚠️  CRITICAL: anon CAN read private videos!');
  privateVids.data.forEach(v => console.log(`  id=${v.id} public=${v.is_public} mod=${v.moderation_status}`));
} else {
  console.log('✅ anon CANNOT read private videos');
}
console.log();

// ─── PROBE 3: anon reads videos where moderation_status != approved ───
console.log('─── PROBE 3: anon reads videos moderation_status=pending ───');
const pendingVids = await fetchSupabase('/rest/v1/videos?select=id,is_public,moderation_status&moderation_status=eq.pending&limit=10');
console.log(`Status: ${pendingVids.status}`);
console.log(`Count: ${Array.isArray(pendingVids.data) ? pendingVids.data.length : 'N/A'}`);
if (Array.isArray(pendingVids.data) && pendingVids.data.length > 0) {
  console.log('⚠️  CRITICAL: anon CAN read pending videos!');
  pendingVids.data.forEach(v => console.log(`  id=${v.id} public=${v.is_public} mod=${v.moderation_status}`));
} else {
  console.log('✅ anon CANNOT read pending videos');
}
console.log();

// ─── PROBE 4: anon reads user_progress ───
console.log('─── PROBE 4: anon reads user_progress ───');
const anonProgress = await fetchSupabase('/rest/v1/user_progress?select=id,user_id&limit=10');
console.log(`Status: ${anonProgress.status}`);
console.log(`Count: ${Array.isArray(anonProgress.data) ? anonProgress.data.length : 'N/A'}`);
if (Array.isArray(anonProgress.data) && anonProgress.data.length > 0) {
  console.log('⚠️  CRITICAL: anon CAN read user_progress!');
} else {
  console.log('✅ anon CANNOT read user_progress');
}
console.log();

// ─── PROBE 5: anon reads minor/pending videos ───
console.log('─── PROBE 5: anon tries to read videos of minors ───');
// Try to find videos from users who are minors via a join (won't work directly via REST, so we just check all returned videos)
const allPublicVids = await fetchSupabase('/rest/v1/videos?select=id,is_public,moderation_status,user_id&limit=50');
console.log(`All videos visible to anon: ${Array.isArray(allPublicVids.data) ? allPublicVids.data.length : 'error/empty'}`);
console.log();

// ─── PROBE 6: Password policy test ───
console.log('─── PROBE 6: Signup with weak password (123456) ───');
const weakEmail = `security_test_${Date.now()}@test-ft.com`;
const weakSignup = await signUpTestUser(weakEmail, '123456');
console.log(`Status: ${weakSignup.status}`);
if (weakSignup.status === 200 && weakSignup.data.id) {
  console.log('⚠️  CRITICAL: Weak password signup SUCCEEDED! BUG-ONB-010 NOT FIXED.');
  console.log(`  User ID: ${weakSignup.data.id}`);
} else {
  console.log('✅ Weak password signup REJECTED');
  console.log(`  Error: ${JSON.stringify(weakSignup.data)}`);
}
console.log();

// ─── PROBE 7: Sign in as random user and test access ───
console.log('─── PROBE 7: Random user access test ───');
const randomEmail = `random_audit_${Date.now()}@test-ft.com`;
const randomPassword = 'RandomPass123!@#';
const randomSignup = await signUpTestUser(randomEmail, randomPassword);
console.log(`Signup random user: status=${randomSignup.status}`);

if (randomSignup.status === 200 && randomSignup.data.access_token) {
  const token = randomSignup.data.access_token;
  console.log(`Random user has token, testing access...`);
  
  // 7a: random user reads private videos
  console.log('\n  7a: Random user reads private videos');
  const randPrivate = await fetchWithToken('/rest/v1/videos?select=id,is_public,moderation_status&is_public=eq.false&limit=10', token);
  console.log(`  Status: ${randPrivate.status}, Count: ${randPrivate.count}`);
  if (randPrivate.count > 0) {
    console.log('  ⚠️  CRITICAL: Random user CAN read private videos!');
  } else {
    console.log('  ✅ Random user CANNOT read private videos');
  }

  // 7b: random user reads pending videos
  console.log('\n  7b: Random user reads pending videos');
  const randPending = await fetchWithToken('/rest/v1/videos?select=id,is_public,moderation_status&moderation_status=eq.pending&limit=10', token);
  console.log(`  Status: ${randPending.status}, Count: ${randPending.count}`);
  if (randPending.count > 0) {
    console.log('  ⚠️  CRITICAL: Random user CAN read pending videos!');
  } else {
    console.log('  ✅ Random user CANNOT read pending videos');
  }

  // 7c: random user reads user_progress
  console.log('\n  7c: Random user reads user_progress');
  const randProgress = await fetchWithToken('/rest/v1/user_progress?select=id,user_id&limit=10', token);
  console.log(`  Status: ${randProgress.status}, Count: ${randProgress.count}`);
  if (randProgress.count > 0) {
    console.log('  ⚠️  CRITICAL: Random user CAN read others\' user_progress!');
  } else {
    console.log('  ✅ Random user CANNOT read user_progress');
  }

  // 7d: random user reads all videos (should only see public+approved)
  console.log('\n  7d: Random user reads all videos');
  const randAll = await fetchWithToken('/rest/v1/videos?select=id,is_public,moderation_status,user_id&limit=30', token);
  console.log(`  Status: ${randAll.status}, Count: ${randAll.count}`);
  if (Array.isArray(randAll.data)) {
    const nonPublic = randAll.data.filter(v => !v.is_public);
    const nonApproved = randAll.data.filter(v => v.moderation_status !== 'approved');
    if (nonPublic.length > 0) {
      console.log(`  ⚠️  Random user sees ${nonPublic.length} non-public videos!`);
    }
    if (nonApproved.length > 0) {
      console.log(`  ⚠️  Random user sees ${nonApproved.length} non-approved videos!`);
    }
    if (nonPublic.length === 0 && nonApproved.length === 0) {
      console.log('  ✅ Random user only sees public+approved videos');
    }
  }
} else {
  console.log(`Random user signup failed or no auto-confirm: ${JSON.stringify(randomSignup.data).slice(0, 200)}`);
}

console.log('\n=== Audit Complete ===');
