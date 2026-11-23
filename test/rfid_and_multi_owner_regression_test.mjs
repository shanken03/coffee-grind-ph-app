// test/rfid_and_multi_owner_regression_test.mjs
// Verifies that the unified firestore.rules preserves ALL production multi-owner and RFID hardware device rules.

function makeJwt(payload) {
  const header = Buffer.from(JSON.stringify({ alg: "none", typ: "JWT" })).toString('base64url');
  const body = Buffer.from(JSON.stringify(payload)).toString('base64url');
  return `${header}.${body}.`;
}

// 1. Owner Tokens
const ownerIanToken = makeJwt({
  sub: "ian_uid",
  user_id: "ian_uid",
  email: "iankakilala@gmail.com",
  aud: "coffee-grind-ph-dce9c"
});

const ownerReinToken = makeJwt({
  sub: "rein_uid",
  user_id: "rein_uid",
  email: "reintamayao00@gmail.com",
  aud: "coffee-grind-ph-dce9c"
});

const ownerUidToken = makeJwt({
  sub: "AF1tkOhq7EUuyKST9HVyANhkVec2",
  user_id: "AF1tkOhq7EUuyKST9HVyANhkVec2",
  aud: "coffee-grind-ph-dce9c"
});

// 2. Hardware Device Token
const deviceSantaCruzToken = makeJwt({
  sub: "device_sc_001",
  user_id: "device_sc_001",
  aud: "coffee-grind-ph-dce9c"
});

const deviceLspuToken = makeJwt({
  sub: "device_lspu_001",
  user_id: "device_lspu_001",
  aud: "coffee-grind-ph-dce9c"
});

// 3. Regular Branch POS Token
const branchPosToken = makeJwt({
  sub: "VbbTKsNnSwMQ7rnDU8fsYM7dod12",
  user_id: "VbbTKsNnSwMQ7rnDU8fsYM7dod12",
  email: "santacruz@gmail.com",
  aud: "coffee-grind-ph-dce9c"
});

const host = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const baseUrl = `http://${host}/v1/projects/coffee-grind-ph-dce9c/databases/(default)/documents`;

async function request(method, docPath, data, token, mask) {
  let url = `${baseUrl}/${docPath}`;
  if (mask && mask.length > 0) {
    url += '?' + mask.map(f => `updateMask.fieldPaths=${encodeURIComponent(f)}`).join('&');
  }

  const headers = { 'Content-Type': 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;

  const res = await fetch(url, {
    method,
    headers,
    body: data ? JSON.stringify(data) : undefined
  });

  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch (_) {}
  return { status: res.status, ok: res.ok, json, text };
}

async function runTests() {
  console.log('=== STARTING PRODUCTION MULTI-OWNER & RFID REGRESSION TESTS ===\n');
  let passed = 0;
  let failed = 0;

  function assert(condition, testName, details) {
    if (condition) {
      console.log(`[PASS] ${testName}`);
      passed++;
    } else {
      console.error(`[FAIL] ${testName}`);
      if (details) console.error('       Details:', details);
      failed++;
    }
  }

  // --- PART 1: MULTI-OWNER AUTHENTICATION VERIFICATION ---
  console.log('--- PART 1: MULTI-OWNER AUTHENTICATION VERIFICATION ---');

  // Test 1: Ian Kakilala owner access
  const ianWrite = await request('PATCH', 'admin_clock_probes/probe_ian', {
    fields: { probedAt: { stringValue: '2026-11-18T00:00:00Z' }, by: { stringValue: 'ian' } }
  }, ownerIanToken);
  assert(ianWrite.ok, '1. Owner Ian (iankakilala@gmail.com) can write to admin collections', ianWrite.text);

  // Test 2: Rein Tamayao owner access
  const reinWrite = await request('PATCH', 'admin_clock_probes/probe_rein', {
    fields: { probedAt: { stringValue: '2026-11-18T00:00:00Z' }, by: { stringValue: 'rein' } }
  }, ownerReinToken);
  assert(reinWrite.ok, '2. Owner Rein (reintamayao00@gmail.com) can write to admin collections', reinWrite.text);

  // Test 3: Owner UID (AF1tkOhq7EUuyKST9HVyANhkVec2) access
  const uidOwnerWrite = await request('PATCH', 'admin_clock_probes/probe_uid', {
    fields: { probedAt: { stringValue: '2026-11-18T00:00:00Z' }, by: { stringValue: 'uid_owner' } }
  }, ownerUidToken);
  assert(uidOwnerWrite.ok, '3. Owner by UID (AF1tkOhq7EUuyKST9HVyANhkVec2) can write to admin collections', uidOwnerWrite.text);

  // Test 4: Branch POS cannot write to admin_clock_probes
  const posAdminWrite = await request('PATCH', 'admin_clock_probes/probe_pos_hack', {
    fields: { probedAt: { stringValue: '2026-11-18T00:00:00Z' } }
  }, branchPosToken);
  assert(posAdminWrite.status === 403, '4. Branch POS cannot write to admin_clock_probes (403)', posAdminWrite.status);


  // --- PART 2: RFID HARDWARE DEVICE & REGISTRY VERIFICATION ---
  console.log('\n--- PART 2: RFID HARDWARE DEVICE & REGISTRY VERIFICATION ---');

  // Seed device account for Santa Cruz device
  const seedDeviceSC = await request('PATCH', 'device_accounts/device_sc_001', {
    fields: {
      deviceId: { stringValue: 'device_sc_001' },
      branchId: { stringValue: 'br_1790905840872' },
      branchName: { stringValue: 'Santa Cruz' },
      active: { booleanValue: true }
    }
  }, ownerIanToken);
  assert(seedDeviceSC.ok, 'Setup: Seed Santa Cruz device account as Owner', seedDeviceSC.text);

  // Seed employee RFID tag in rfid_registry
  const seedRfid = await request('PATCH', 'rfid_registry/E2801160600002', {
    fields: {
      rfidUid: { stringValue: 'E2801160600002' },
      employeeId: { stringValue: 'EMP_001' },
      employeeName: { stringValue: 'Juan Dela Cruz' },
      branchId: { stringValue: 'br_1790905840872' },
      branchName: { stringValue: 'Santa Cruz' },
      active: { booleanValue: true }
    }
  }, ownerIanToken);
  assert(seedRfid.ok, 'Setup: Seed employee RFID registry as Owner', seedRfid.text);

  // Test 5: Device can get its own device account document
  const deviceGetOwn = await request('GET', 'device_accounts/device_sc_001', null, deviceSantaCruzToken);
  assert(deviceGetOwn.ok, '5. Santa Cruz Device can get its own device account doc', deviceGetOwn.status);

  // Test 6: Device cannot get another device account document
  const deviceGetOther = await request('GET', 'device_accounts/device_lspu_001', null, deviceSantaCruzToken);
  assert(deviceGetOther.status === 403 || deviceGetOther.status === 404, '6. Santa Cruz Device cannot get another device account (403/404)', deviceGetOther.status);

  // Test 7: Active device authorized for Santa Cruz can get RFID registry doc
  const deviceGetRfid = await request('GET', 'rfid_registry/E2801160600002', null, deviceSantaCruzToken);
  assert(deviceGetRfid.ok, '7. Authorized Device can look up RFID registry tag for its branch', deviceGetRfid.status);

  // Test 8: Non-device branch POS cannot get RFID registry doc
  const posGetRfid = await request('GET', 'rfid_registry/E2801160600002', null, branchPosToken);
  assert(posGetRfid.status === 403, '8. Branch POS cannot access rfid_registry (403)', posGetRfid.status);


  // --- PART 3: RFID ENROLLMENT SESSION VERIFICATION ---
  console.log('\n--- PART 3: RFID ENROLLMENT SESSION VERIFICATION ---');

  // Owner creates an enrollment session waiting for scan
  const futureTime = new Date(Date.now() + 300000).toISOString();
  const seedEnroll = await request('PATCH', 'rfid_enrollment/device_sc_001', {
    fields: {
      deviceId: { stringValue: 'device_sc_001' },
      branchId: { stringValue: 'br_1790905840872' },
      status: { stringValue: 'waiting' },
      expiresAt: { timestampValue: futureTime }
    }
  }, ownerIanToken);
  assert(seedEnroll.ok, 'Setup: Owner creates RFID enrollment session for device_sc_001', seedEnroll.text);

  // Test 9: Device can read its own enrollment session
  const readEnrollOwn = await request('GET', 'rfid_enrollment/device_sc_001', null, deviceSantaCruzToken);
  assert(readEnrollOwn.ok, '9. Device can read its own enrollment session', readEnrollOwn.status);

  // Test 10: Another device cannot read device_sc_001 enrollment session
  const readEnrollOther = await request('GET', 'rfid_enrollment/device_sc_001', null, deviceLspuToken);
  assert(readEnrollOther.status === 403, '10. Unauthorized device cannot read another device enrollment session (403)', readEnrollOther.status);

  // Test 11: Branch POS cannot access attendance records
  const posAttendance = await request('GET', 'attendance/EMP_001_2026-11-18', null, branchPosToken);
  assert(posAttendance.status === 403 || posAttendance.status === 404, '11. Branch POS cannot read attendance records', posAttendance.status);

  console.log(`\n=============================================================`);
  console.log(`PRODUCTION MULTI-OWNER & RFID REGRESSION: ${passed} PASSED, ${failed} FAILED`);
  console.log(`=============================================================`);

  if (failed > 0) {
    process.exit(1);
  }
}

runTests().catch(err => {
  console.error('Test execution error:', err);
  process.exit(1);
});
