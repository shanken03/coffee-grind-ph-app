// Firebase Firestore Security Rules Test Suite for Checkpoints 6.3 & 6.3.1
// Runs against the local Cloud Firestore Emulator via REST API using unsigned JWTs

const host = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const projectId = 'coffee-grind-ph-dce9c';
const baseUrl = `http://${host}/v1/projects/${projectId}/databases/(default)/documents`;
const commitUrl = `http://${host}/v1/projects/${projectId}/databases/(default)/documents:commit`;

function makeJwt(payload) {
  const header = Buffer.from(JSON.stringify({ alg: "none", typ: "JWT" })).toString('base64url');
  const body = Buffer.from(JSON.stringify(payload)).toString('base64url');
  return `${header}.${body}.`;
}

const ownerToken = makeJwt({
  sub: "owner_admin",
  user_id: "owner_admin",
  email: "iankakilala@gmail.com",
  aud: projectId
});

const santaCruzToken = makeJwt({
  sub: "VbbTKsNnSwMQ7rnDU8fsYM7dod12",
  user_id: "VbbTKsNnSwMQ7rnDU8fsYM7dod12",
  email: "santacruz@gmail.com",
  aud: projectId
});

const lspuToken = makeJwt({
  sub: "uGOP7Jd3K1RMttlZDI6WqrhwRLd2",
  user_id: "uGOP7Jd3K1RMttlZDI6WqrhwRLd2",
  email: "lspu@gmail.com",
  aud: projectId
});

async function getDoc(docPath, token) {
  const headers = {};
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const res = await fetch(`${baseUrl}/${docPath}`, { method: 'GET', headers });
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch (_) {}
  return { status: res.status, ok: res.ok, json, text };
}

async function patchDoc(docPath, fields, token, mask) {
  let url = `${baseUrl}/${docPath}`;
  if (mask && mask.length > 0) {
    url += '?' + mask.map(f => `updateMask.fieldPaths=${encodeURIComponent(f)}`).join('&');
  }
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const res = await fetch(url, {
    method: 'PATCH',
    headers,
    body: JSON.stringify({ fields })
  });
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch (_) {}
  return { status: res.status, ok: res.ok, json, text };
}

async function deleteDoc(docPath, token) {
  const headers = {};
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const res = await fetch(`${baseUrl}/${docPath}`, { method: 'DELETE', headers });
  const text = await res.text();
  return { status: res.status, ok: res.ok, text };
}

async function commitWrites(writes, token) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const res = await fetch(commitUrl, {
    method: 'POST',
    headers,
    body: JSON.stringify({ writes })
  });
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch (_) {}
  return { status: res.status, ok: res.ok, json, text };
}

function docName(collectionAndDoc) {
  return `projects/${projectId}/databases/(default)/documents/${collectionAndDoc}`;
}

async function run() {
  console.log('=== STARTING CHECKPOINTS 6.3 & 6.3.1 FIRESTORE SECURITY RULES EMULATOR TESTS ===\n');
  let passed = 0;
  let failed = 0;

  function assert(condition, name, details) {
    if (condition) {
      console.log(`[PASS] ${name}`);
      passed++;
    } else {
      console.error(`[FAIL] ${name}`);
      if (details) console.error('       Details:', details);
      failed++;
    }
  }

  // -------------------------------------------------------------
  // SETUP: SEED BRANCH ACCOUNTS & BASELINE QUOTAS AS OWNER
  // -------------------------------------------------------------
  console.log('[Setup] Seeding branch accounts and baseline quotas as Owner...');

  await patchDoc('branch_accounts/VbbTKsNnSwMQ7rnDU8fsYM7dod12', {
    branchId: { stringValue: 'br_1790905840872' },
    branchName: { stringValue: 'Santa Cruz' },
    role: { stringValue: 'branch' },
    status: { stringValue: 'active' },
    active: { booleanValue: true }
  }, ownerToken);

  await patchDoc('branch_accounts/uGOP7Jd3K1RMttlZDI6WqrhwRLd2', {
    branchId: { stringValue: 'br_1790923872261' },
    branchName: { stringValue: 'LSPU' },
    role: { stringValue: 'branch' },
    status: { stringValue: 'active' },
    active: { booleanValue: true }
  }, ownerToken);

  // 5 Santa Cruz Quota Documents
  await patchDoc('branch_product_servings/br_1790905840872_PROD_SPANISH', {
    branchId: { stringValue: 'br_1790905840872' },
    productId: { stringValue: 'PROD_SPANISH' },
    manualMaxServings: { integerValue: '50' },
    remainingServings: { integerValue: '10' },
    isEnabled: { booleanValue: true }
  }, ownerToken);

  await patchDoc('branch_product_servings/br_1790905840872_PROD_AMERICANO', {
    branchId: { stringValue: 'br_1790905840872' },
    productId: { stringValue: 'PROD_AMERICANO' },
    manualMaxServings: { integerValue: '50' },
    remainingServings: { integerValue: '20' },
    isEnabled: { booleanValue: true }
  }, ownerToken);

  await patchDoc('branch_product_servings/br_1790905840872_PROD_CARAMEL', {
    branchId: { stringValue: 'br_1790905840872' },
    productId: { stringValue: 'PROD_CARAMEL' },
    manualMaxServings: { integerValue: '50' },
    remainingServings: { integerValue: '15' },
    isEnabled: { booleanValue: true }
  }, ownerToken);

  await patchDoc('branch_product_servings/br_1790905840872_PROD_MATCHA', {
    branchId: { stringValue: 'br_1790905840872' },
    productId: { stringValue: 'PROD_MATCHA' },
    manualMaxServings: { integerValue: '50' },
    remainingServings: { integerValue: '8' },
    isEnabled: { booleanValue: true }
  }, ownerToken);

  await patchDoc('branch_product_servings/br_1790905840872_PROD_MOCHA', {
    branchId: { stringValue: 'br_1790905840872' },
    productId: { stringValue: 'PROD_MOCHA' },
    manualMaxServings: { integerValue: '50' },
    remainingServings: { integerValue: '12' },
    isEnabled: { booleanValue: true }
  }, ownerToken);

  // Zero-balance product quota
  await patchDoc('branch_product_servings/br_1790905840872_PROD_ZERO', {
    branchId: { stringValue: 'br_1790905840872' },
    productId: { stringValue: 'PROD_ZERO' },
    manualMaxServings: { integerValue: '50' },
    remainingServings: { integerValue: '0' },
    isEnabled: { booleanValue: true }
  }, ownerToken);

  // LSPU Quota Document
  await patchDoc('branch_product_servings/br_1790923872261_PROD_SPANISH', {
    branchId: { stringValue: 'br_1790923872261' },
    productId: { stringValue: 'PROD_SPANISH' },
    manualMaxServings: { integerValue: '50' },
    remainingServings: { integerValue: '10' },
    isEnabled: { booleanValue: true }
  }, ownerToken);

  // Attendance doc for regression test
  await patchDoc('attendance/att_test_1', {
    branchId: { stringValue: 'br_1790905840872' },
    status: { stringValue: 'present' }
  }, ownerToken);

  console.log('\n--- PART A: BASIC BRANCH SCOPING & CRUD RESTRICTIONS ---\n');

  // TEST 1: Authorized Santa Cruz POS can read its own quota
  const r1 = await getDoc('branch_product_servings/br_1790905840872_PROD_SPANISH', santaCruzToken);
  assert(r1.status === 200, '1. Authorized Santa Cruz POS can read its own quota', r1.text);

  // TEST 2: Authorized LSPU POS can read its own quota
  const r2 = await getDoc('branch_product_servings/br_1790923872261_PROD_SPANISH', lspuToken);
  assert(r2.status === 200, '2. Authorized LSPU POS can read its own quota', r2.text);

  // TEST 3: Santa Cruz cannot read LSPU quota
  const r3 = await getDoc('branch_product_servings/br_1790923872261_PROD_SPANISH', santaCruzToken);
  assert(r3.status === 403, '3. Santa Cruz cannot read LSPU quota (403 Forbidden)', `Got status ${r3.status}`);

  // TEST 4: LSPU cannot read Santa Cruz quota
  const r4 = await getDoc('branch_product_servings/br_1790905840872_PROD_SPANISH', lspuToken);
  assert(r4.status === 403, '4. LSPU cannot read Santa Cruz quota (403 Forbidden)', `Got status ${r4.status}`);

  // TEST 5: Unauthenticated access is denied
  const r5 = await getDoc('branch_product_servings/br_1790905840872_PROD_SPANISH', null);
  assert(r5.status === 403 || r5.status === 401, '5. Unauthenticated access is denied', `Got status ${r5.status}`);

  // TEST 6: Branch POS cannot create quota documents
  const r6 = await patchDoc('branch_product_servings/br_1790905840872_PROD_NEW', {
    branchId: { stringValue: 'br_1790905840872' },
    productId: { stringValue: 'PROD_NEW' },
    remainingServings: { integerValue: '20' }
  }, santaCruzToken);
  assert(r6.status === 403, '6. Branch POS cannot create quota documents', `Got status ${r6.status}`);

  // TEST 7: Branch POS cannot delete quota documents
  const r7 = await deleteDoc('branch_product_servings/br_1790905840872_PROD_SPANISH', santaCruzToken);
  assert(r7.status === 403, '7. Branch POS cannot delete quota documents', `Got status ${r7.status}`);

  // TEST 8: Branch POS cannot increase remainingServings
  const r8 = await patchDoc('branch_product_servings/br_1790905840872_PROD_SPANISH', {
    remainingServings: { integerValue: '15' },
    lastSaleId: { stringValue: 'FAKE_SALE' }
  }, santaCruzToken, ['remainingServings', 'lastSaleId']);
  assert(r8.status === 403, '8. Branch POS cannot increase remainingServings', `Got status ${r8.status}`);

  // TEST 9: Branch POS cannot modify manualMaxServings
  const r9 = await patchDoc('branch_product_servings/br_1790905840872_PROD_SPANISH', {
    manualMaxServings: { integerValue: '100' }
  }, santaCruzToken, ['manualMaxServings']);
  assert(r9.status === 403, '9. Branch POS cannot modify manualMaxServings', `Got status ${r9.status}`);

  // TEST 10: Branch POS cannot change isEnabled
  const r10 = await patchDoc('branch_product_servings/br_1790905840872_PROD_SPANISH', {
    isEnabled: { booleanValue: false }
  }, santaCruzToken, ['isEnabled']);
  assert(r10.status === 403, '10. Branch POS cannot change isEnabled', `Got status ${r10.status}`);

  console.log('\n--- PART B: ATOMIC SALE-LINKED QUOTA DEDUCTION & LEDGER INTEGRITY ---\n');

  // TEST 11: Valid sale-linked quota deduction (1-product online sale)
  const saleId1 = 'SALE_ONLINE_1PROD';
  const r11 = await commitWrites([
    {
      update: {
        name: docName(`sales/${saleId1}`),
        fields: {
          saleId: { stringValue: saleId1 },
          clientSaleId: { stringValue: saleId1 },
          branchId: { stringValue: 'br_1790905840872' },
          productQuantities: {
            mapValue: { fields: { PROD_SPANISH: { integerValue: '3' } } }
          },
          total: { doubleValue: 360.0 },
          hasManualQuotaOverdraft: { booleanValue: false },
          manualQuotaOverdrafts: { mapValue: { fields: {} } }
        }
      },
      currentDocument: { exists: false }
    },
    {
      update: {
        name: docName('branch_product_servings/br_1790905840872_PROD_SPANISH'),
        fields: {
          remainingServings: { integerValue: '7' }, // 10 -> 7
          lastSaleId: { stringValue: saleId1 }
        }
      },
      updateMask: { fieldPaths: ['remainingServings', 'lastSaleId'] },
      currentDocument: { exists: true }
    },
    {
      update: {
        name: docName(`quota_transactions/${saleId1}_PROD_SPANISH`),
        fields: {
          transactionId: { stringValue: `${saleId1}_PROD_SPANISH` },
          saleId: { stringValue: saleId1 },
          clientSaleId: { stringValue: saleId1 },
          branchId: { stringValue: 'br_1790905840872' },
          productId: { stringValue: 'PROD_SPANISH' },
          requestedQuantity: { integerValue: '3' },
          deductedQuantity: { integerValue: '3' },
          overdraftQuantity: { integerValue: '0' },
          previousRemaining: { integerValue: '10' },
          newRemaining: { integerValue: '7' },
          isOfflineSync: { booleanValue: false }
        }
      },
      currentDocument: { exists: false }
    }
  ], santaCruzToken);
  assert(r11.status === 200, '11. Valid 1-product sale-linked quota deduction succeeds', r11.text);

  // TEST 12: Quota deduction without a corresponding sale is denied
  const r12 = await commitWrites([
    {
      update: {
        name: docName('branch_product_servings/br_1790905840872_PROD_SPANISH'),
        fields: {
          remainingServings: { integerValue: '4' },
          lastSaleId: { stringValue: 'SALE_GHOST_1' }
        }
      },
      updateMask: { fieldPaths: ['remainingServings', 'lastSaleId'] },
      currentDocument: { exists: true }
    },
    {
      update: {
        name: docName('quota_transactions/SALE_GHOST_1_PROD_SPANISH'),
        fields: {
          transactionId: { stringValue: 'SALE_GHOST_1_PROD_SPANISH' },
          saleId: { stringValue: 'SALE_GHOST_1' },
          clientSaleId: { stringValue: 'SALE_GHOST_1' },
          branchId: { stringValue: 'br_1790905840872' },
          productId: { stringValue: 'PROD_SPANISH' },
          requestedQuantity: { integerValue: '3' },
          deductedQuantity: { integerValue: '3' },
          overdraftQuantity: { integerValue: '0' },
          previousRemaining: { integerValue: '7' },
          newRemaining: { integerValue: '4' },
          isOfflineSync: { booleanValue: false }
        }
      },
      currentDocument: { exists: false }
    }
  ], santaCruzToken);
  assert(r12.status === 403, '12. Quota deduction without a corresponding sale is denied', `Got status ${r12.status}`);

  // TEST 13: Quota deduction with a mismatched sale branch is denied
  const r13 = await commitWrites([
    {
      update: {
        name: docName('sales/SALE_WRONG_BRANCH'),
        fields: {
          saleId: { stringValue: 'SALE_WRONG_BRANCH' },
          clientSaleId: { stringValue: 'SALE_WRONG_BRANCH' },
          branchId: { stringValue: 'br_1790923872261' }, // LSPU branch
          productQuantities: {
            mapValue: { fields: { PROD_SPANISH: { integerValue: '2' } } }
          }
        }
      },
      currentDocument: { exists: false }
    },
    {
      update: {
        name: docName('branch_product_servings/br_1790905840872_PROD_SPANISH'),
        fields: {
          remainingServings: { integerValue: '5' },
          lastSaleId: { stringValue: 'SALE_WRONG_BRANCH' }
        }
      },
      updateMask: { fieldPaths: ['remainingServings', 'lastSaleId'] },
      currentDocument: { exists: true }
    },
    {
      update: {
        name: docName('quota_transactions/SALE_WRONG_BRANCH_PROD_SPANISH'),
        fields: {
          transactionId: { stringValue: 'SALE_WRONG_BRANCH_PROD_SPANISH' },
          saleId: { stringValue: 'SALE_WRONG_BRANCH' },
          clientSaleId: { stringValue: 'SALE_WRONG_BRANCH' },
          branchId: { stringValue: 'br_1790905840872' },
          productId: { stringValue: 'PROD_SPANISH' },
          requestedQuantity: { integerValue: '2' },
          deductedQuantity: { integerValue: '2' },
          overdraftQuantity: { integerValue: '0' },
          previousRemaining: { integerValue: '7' },
          newRemaining: { integerValue: '5' },
          isOfflineSync: { booleanValue: false }
        }
      },
      currentDocument: { exists: false }
    }
  ], santaCruzToken);
  assert(r13.status === 403, '13. Quota deduction with mismatched sale branch is denied', `Got status ${r13.status}`);

  // TEST 14: Quota deduction with a mismatched product is denied
  const r14 = await commitWrites([
    {
      update: {
        name: docName('sales/SALE_WRONG_PROD'),
        fields: {
          saleId: { stringValue: 'SALE_WRONG_PROD' },
          clientSaleId: { stringValue: 'SALE_WRONG_PROD' },
          branchId: { stringValue: 'br_1790905840872' },
          productQuantities: {
            mapValue: { fields: { PROD_AMERICANO: { integerValue: '2' } } }
          }
        }
      },
      currentDocument: { exists: false }
    },
    {
      update: {
        name: docName('branch_product_servings/br_1790905840872_PROD_SPANISH'),
        fields: {
          remainingServings: { integerValue: '5' },
          lastSaleId: { stringValue: 'SALE_WRONG_PROD' }
        }
      },
      updateMask: { fieldPaths: ['remainingServings', 'lastSaleId'] },
      currentDocument: { exists: true }
    },
    {
      update: {
        name: docName('quota_transactions/SALE_WRONG_PROD_PROD_SPANISH'),
        fields: {
          transactionId: { stringValue: 'SALE_WRONG_PROD_PROD_SPANISH' },
          saleId: { stringValue: 'SALE_WRONG_PROD' },
          clientSaleId: { stringValue: 'SALE_WRONG_PROD' },
          branchId: { stringValue: 'br_1790905840872' },
          productId: { stringValue: 'PROD_SPANISH' },
          requestedQuantity: { integerValue: '2' },
          deductedQuantity: { integerValue: '2' },
          overdraftQuantity: { integerValue: '0' },
          previousRemaining: { integerValue: '7' },
          newRemaining: { integerValue: '5' },
          isOfflineSync: { booleanValue: false }
        }
      },
      currentDocument: { exists: false }
    }
  ], santaCruzToken);
  assert(r14.status === 403, '14. Quota deduction with mismatched product is denied', `Got status ${r14.status}`);

  // TEST 15: Forged previousRemaining in ledger is rejected
  const r15 = await commitWrites([
    {
      update: {
        name: docName('sales/SALE_FORGED_PREV'),
        fields: {
          saleId: { stringValue: 'SALE_FORGED_PREV' },
          clientSaleId: { stringValue: 'SALE_FORGED_PREV' },
          branchId: { stringValue: 'br_1790905840872' },
          productQuantities: {
            mapValue: { fields: { PROD_SPANISH: { integerValue: '2' } } }
          }
        }
      },
      currentDocument: { exists: false }
    },
    {
      update: {
        name: docName('branch_product_servings/br_1790905840872_PROD_SPANISH'),
        fields: {
          remainingServings: { integerValue: '5' },
          lastSaleId: { stringValue: 'SALE_FORGED_PREV' }
        }
      },
      updateMask: { fieldPaths: ['remainingServings', 'lastSaleId'] },
      currentDocument: { exists: true }
    },
    {
      update: {
        name: docName('quota_transactions/SALE_FORGED_PREV_PROD_SPANISH'),
        fields: {
          transactionId: { stringValue: 'SALE_FORGED_PREV_PROD_SPANISH' },
          saleId: { stringValue: 'SALE_FORGED_PREV' },
          clientSaleId: { stringValue: 'SALE_FORGED_PREV' },
          branchId: { stringValue: 'br_1790905840872' },
          productId: { stringValue: 'PROD_SPANISH' },
          requestedQuantity: { integerValue: '2' },
          deductedQuantity: { integerValue: '2' },
          overdraftQuantity: { integerValue: '0' },
          previousRemaining: { integerValue: '50' }, // FORGED! Actual remaining is 7
          newRemaining: { integerValue: '5' },
          isOfflineSync: { booleanValue: false }
        }
      },
      currentDocument: { exists: false }
    }
  ], santaCruzToken);
  assert(r15.status === 403, '15. Forged previousRemaining in ledger is rejected', `Got status ${r15.status}`);

  // TEST 16: Forged deductedQuantity in ledger is rejected
  const r16 = await commitWrites([
    {
      update: {
        name: docName('sales/SALE_FORGED_DEDUCT'),
        fields: {
          saleId: { stringValue: 'SALE_FORGED_DEDUCT' },
          clientSaleId: { stringValue: 'SALE_FORGED_DEDUCT' },
          branchId: { stringValue: 'br_1790905840872' },
          productQuantities: {
            mapValue: { fields: { PROD_SPANISH: { integerValue: '2' } } }
          }
        }
      },
      currentDocument: { exists: false }
    },
    {
      update: {
        name: docName('branch_product_servings/br_1790905840872_PROD_SPANISH'),
        fields: {
          remainingServings: { integerValue: '5' }, // Real delta is 2 (7 - 5)
          lastSaleId: { stringValue: 'SALE_FORGED_DEDUCT' }
        }
      },
      updateMask: { fieldPaths: ['remainingServings', 'lastSaleId'] },
      currentDocument: { exists: true }
    },
    {
      update: {
        name: docName('quota_transactions/SALE_FORGED_DEDUCT_PROD_SPANISH'),
        fields: {
          transactionId: { stringValue: 'SALE_FORGED_DEDUCT_PROD_SPANISH' },
          saleId: { stringValue: 'SALE_FORGED_DEDUCT' },
          clientSaleId: { stringValue: 'SALE_FORGED_DEDUCT' },
          branchId: { stringValue: 'br_1790905840872' },
          productId: { stringValue: 'PROD_SPANISH' },
          requestedQuantity: { integerValue: '2' },
          deductedQuantity: { integerValue: '1' }, // FORGED! Claims 1 instead of 2
          overdraftQuantity: { integerValue: '1' },
          previousRemaining: { integerValue: '7' },
          newRemaining: { integerValue: '5' },
          isOfflineSync: { booleanValue: true }
        }
      },
      currentDocument: { exists: false }
    }
  ], santaCruzToken);
  assert(r16.status === 403, '16. Forged deductedQuantity in ledger is rejected', `Got status ${r16.status}`);

  // TEST 17: Duplicate ledger creation is denied
  const r17 = await patchDoc(`quota_transactions/${saleId1}_PROD_SPANISH`, {
    transactionId: { stringValue: `${saleId1}_PROD_SPANISH` },
    saleId: { stringValue: saleId1 },
    clientSaleId: { stringValue: saleId1 },
    branchId: { stringValue: 'br_1790905840872' },
    productId: { stringValue: 'PROD_SPANISH' },
    requestedQuantity: { integerValue: '3' },
    deductedQuantity: { integerValue: '3' },
    overdraftQuantity: { integerValue: '0' },
    previousRemaining: { integerValue: '10' },
    newRemaining: { integerValue: '7' },
    isOfflineSync: { booleanValue: false }
  }, santaCruzToken);
  assert(r17.status === 403, '17. Duplicate ledger creation is denied', `Got status ${r17.status}`);

  // TEST 18: Ledger update and deletion are denied for branch POS
  const r18a = await patchDoc(`quota_transactions/${saleId1}_PROD_SPANISH`, {
    deductedQuantity: { integerValue: '1' }
  }, santaCruzToken, ['deductedQuantity']);
  assert(r18a.status === 403, '18a. Ledger update is denied for branch POS', `Got status ${r18a.status}`);

  const r18b = await deleteDoc(`quota_transactions/${saleId1}_PROD_SPANISH`, santaCruzToken);
  assert(r18b.status === 403, '18b. Ledger deletion is denied for branch POS', `Got status ${r18b.status}`);

  // TEST 19: Negative quota values are denied
  const r19 = await commitWrites([
    {
      update: {
        name: docName('sales/SALE_NEGATIVE_TEST'),
        fields: {
          saleId: { stringValue: 'SALE_NEGATIVE_TEST' },
          clientSaleId: { stringValue: 'SALE_NEGATIVE_TEST' },
          branchId: { stringValue: 'br_1790905840872' },
          productQuantities: {
            mapValue: { fields: { PROD_SPANISH: { integerValue: '20' } } }
          }
        }
      },
      currentDocument: { exists: false }
    },
    {
      update: {
        name: docName('branch_product_servings/br_1790905840872_PROD_SPANISH'),
        fields: {
          remainingServings: { integerValue: '-13' },
          lastSaleId: { stringValue: 'SALE_NEGATIVE_TEST' }
        }
      },
      updateMask: { fieldPaths: ['remainingServings', 'lastSaleId'] },
      currentDocument: { exists: true }
    },
    {
      update: {
        name: docName('quota_transactions/SALE_NEGATIVE_TEST_PROD_SPANISH'),
        fields: {
          transactionId: { stringValue: 'SALE_NEGATIVE_TEST_PROD_SPANISH' },
          saleId: { stringValue: 'SALE_NEGATIVE_TEST' },
          clientSaleId: { stringValue: 'SALE_NEGATIVE_TEST' },
          branchId: { stringValue: 'br_1790905840872' },
          productId: { stringValue: 'PROD_SPANISH' },
          requestedQuantity: { integerValue: '20' },
          deductedQuantity: { integerValue: '20' },
          overdraftQuantity: { integerValue: '0' },
          previousRemaining: { integerValue: '7' },
          newRemaining: { integerValue: '-13' },
          isOfflineSync: { booleanValue: false }
        }
      },
      currentDocument: { exists: false }
    }
  ], santaCruzToken);
  assert(r19.status === 403, '19. Negative quota values are denied', `Got status ${r19.status}`);

  console.log('\n--- PART C: ZERO-QUOTA OFFLINE OVERDRAFT & EDGE CASES ---\n');

  // TEST 20: Zero-quota full offline overdraft succeeds atomically
  // Pre: PROD_ZERO has remainingServings = 0
  // Order: requested = 3, deducted = 0, overdraft = 3, newRemaining = 0
  const zeroSaleId = 'SALE_ZERO_QUOTA_OVERDRAFT';
  const r20 = await commitWrites([
    {
      update: {
        name: docName(`sales/${zeroSaleId}`),
        fields: {
          saleId: { stringValue: zeroSaleId },
          clientSaleId: { stringValue: zeroSaleId },
          branchId: { stringValue: 'br_1790905840872' },
          productQuantities: {
            mapValue: { fields: { PROD_ZERO: { integerValue: '3' } } }
          },
          hasManualQuotaOverdraft: { booleanValue: true },
          manualQuotaOverdrafts: {
            mapValue: { fields: { PROD_ZERO: { integerValue: '3' } } }
          }
        }
      },
      currentDocument: { exists: false }
    },
    {
      update: {
        name: docName('branch_product_servings/br_1790905840872_PROD_ZERO'),
        fields: {
          remainingServings: { integerValue: '0' }, // Stays 0!
          lastSaleId: { stringValue: zeroSaleId }
        }
      },
      updateMask: { fieldPaths: ['remainingServings', 'lastSaleId'] },
      currentDocument: { exists: true }
    },
    {
      update: {
        name: docName(`quota_transactions/${zeroSaleId}_PROD_ZERO`),
        fields: {
          transactionId: { stringValue: `${zeroSaleId}_PROD_ZERO` },
          saleId: { stringValue: zeroSaleId },
          clientSaleId: { stringValue: zeroSaleId },
          branchId: { stringValue: 'br_1790905840872' },
          productId: { stringValue: 'PROD_ZERO' },
          requestedQuantity: { integerValue: '3' },
          deductedQuantity: { integerValue: '0' },
          overdraftQuantity: { integerValue: '3' },
          previousRemaining: { integerValue: '0' },
          newRemaining: { integerValue: '0' },
          isOfflineSync: { booleanValue: true }
        }
      },
      currentDocument: { exists: false }
    }
  ], santaCruzToken);
  assert(r20.status === 200, '20. Zero-quota full offline overdraft succeeds atomically', r20.text);

  // TEST 21: Zero-quota online sale without overdraft flag is rejected
  const zeroOnlineSaleId = 'SALE_ZERO_QUOTA_ONLINE_FAIL';
  const r21 = await commitWrites([
    {
      update: {
        name: docName(`sales/${zeroOnlineSaleId}`),
        fields: {
          saleId: { stringValue: zeroOnlineSaleId },
          clientSaleId: { stringValue: zeroOnlineSaleId },
          branchId: { stringValue: 'br_1790905840872' },
          productQuantities: {
            mapValue: { fields: { PROD_ZERO: { integerValue: '2' } } }
          },
          hasManualQuotaOverdraft: { booleanValue: false },
          manualQuotaOverdrafts: { mapValue: { fields: {} } }
        }
      },
      currentDocument: { exists: false }
    },
    {
      update: {
        name: docName('branch_product_servings/br_1790905840872_PROD_ZERO'),
        fields: {
          remainingServings: { integerValue: '0' },
          lastSaleId: { stringValue: zeroOnlineSaleId }
        }
      },
      updateMask: { fieldPaths: ['remainingServings', 'lastSaleId'] },
      currentDocument: { exists: true }
    },
    {
      update: {
        name: docName(`quota_transactions/${zeroOnlineSaleId}_PROD_ZERO`),
        fields: {
          transactionId: { stringValue: `${zeroOnlineSaleId}_PROD_ZERO` },
          saleId: { stringValue: zeroOnlineSaleId },
          clientSaleId: { stringValue: zeroOnlineSaleId },
          branchId: { stringValue: 'br_1790905840872' },
          productId: { stringValue: 'PROD_ZERO' },
          requestedQuantity: { integerValue: '2' },
          deductedQuantity: { integerValue: '2' }, // Claims deducted when quota was 0!
          overdraftQuantity: { integerValue: '0' },
          previousRemaining: { integerValue: '0' },
          newRemaining: { integerValue: '0' },
          isOfflineSync: { booleanValue: false }
        }
      },
      currentDocument: { exists: false }
    }
  ], santaCruzToken);
  assert(r21.status === 403, '21. Zero-quota online sale without overdraft is rejected', `Got status ${r21.status}`);

  console.log('\n--- PART D: MULTI-PRODUCT TRANSACTIONS & ACCESS-CALL LIMIT VERIFICATION ---\n');

  // TEST 22: Two-product online sale (PROD_AMERICANO + PROD_CARAMEL)
  // PROD_AMERICANO: 20 -> 18 (needs 2)
  // PROD_CARAMEL:   15 -> 12 (needs 3)
  const multi2SaleId = 'SALE_MULTI_2PROD';
  const r22 = await commitWrites([
    {
      update: {
        name: docName(`sales/${multi2SaleId}`),
        fields: {
          saleId: { stringValue: multi2SaleId },
          clientSaleId: { stringValue: multi2SaleId },
          branchId: { stringValue: 'br_1790905840872' },
          productQuantities: {
            mapValue: {
              fields: {
                PROD_AMERICANO: { integerValue: '2' },
                PROD_CARAMEL: { integerValue: '3' }
              }
            }
          },
          hasManualQuotaOverdraft: { booleanValue: false },
          manualQuotaOverdrafts: { mapValue: { fields: {} } }
        }
      },
      currentDocument: { exists: false }
    },
    // Quota 1
    {
      update: {
        name: docName('branch_product_servings/br_1790905840872_PROD_AMERICANO'),
        fields: {
          remainingServings: { integerValue: '18' },
          lastSaleId: { stringValue: multi2SaleId }
        }
      },
      updateMask: { fieldPaths: ['remainingServings', 'lastSaleId'] },
      currentDocument: { exists: true }
    },
    // Ledger 1
    {
      update: {
        name: docName(`quota_transactions/${multi2SaleId}_PROD_AMERICANO`),
        fields: {
          transactionId: { stringValue: `${multi2SaleId}_PROD_AMERICANO` },
          saleId: { stringValue: multi2SaleId },
          clientSaleId: { stringValue: multi2SaleId },
          branchId: { stringValue: 'br_1790905840872' },
          productId: { stringValue: 'PROD_AMERICANO' },
          requestedQuantity: { integerValue: '2' },
          deductedQuantity: { integerValue: '2' },
          overdraftQuantity: { integerValue: '0' },
          previousRemaining: { integerValue: '20' },
          newRemaining: { integerValue: '18' },
          isOfflineSync: { booleanValue: false }
        }
      },
      currentDocument: { exists: false }
    },
    // Quota 2
    {
      update: {
        name: docName('branch_product_servings/br_1790905840872_PROD_CARAMEL'),
        fields: {
          remainingServings: { integerValue: '12' },
          lastSaleId: { stringValue: multi2SaleId }
        }
      },
      updateMask: { fieldPaths: ['remainingServings', 'lastSaleId'] },
      currentDocument: { exists: true }
    },
    // Ledger 2
    {
      update: {
        name: docName(`quota_transactions/${multi2SaleId}_PROD_CARAMEL`),
        fields: {
          transactionId: { stringValue: `${multi2SaleId}_PROD_CARAMEL` },
          saleId: { stringValue: multi2SaleId },
          clientSaleId: { stringValue: multi2SaleId },
          branchId: { stringValue: 'br_1790905840872' },
          productId: { stringValue: 'PROD_CARAMEL' },
          requestedQuantity: { integerValue: '3' },
          deductedQuantity: { integerValue: '3' },
          overdraftQuantity: { integerValue: '0' },
          previousRemaining: { integerValue: '15' },
          newRemaining: { integerValue: '12' },
          isOfflineSync: { booleanValue: false }
        }
      },
      currentDocument: { exists: false }
    }
  ], santaCruzToken);
  assert(r22.status === 200, '22. Two-product online sale transaction succeeds', r22.text);

  // TEST 23: Five-product online sale transaction (PROD_SPANISH, PROD_AMERICANO, PROD_CARAMEL, PROD_MATCHA, PROD_MOCHA)
  // SPANISH:   7 -> 6 (needs 1)
  // AMERICANO: 18 -> 16 (needs 2)
  // CARAMEL:   12 -> 11 (needs 1)
  // MATCHA:    8 -> 6 (needs 2)
  // MOCHA:     12 -> 10 (needs 2)
  const multi5SaleId = 'SALE_MULTI_5PROD';
  const r23 = await commitWrites([
    {
      update: {
        name: docName(`sales/${multi5SaleId}`),
        fields: {
          saleId: { stringValue: multi5SaleId },
          clientSaleId: { stringValue: multi5SaleId },
          branchId: { stringValue: 'br_1790905840872' },
          productQuantities: {
            mapValue: {
              fields: {
                PROD_SPANISH: { integerValue: '1' },
                PROD_AMERICANO: { integerValue: '2' },
                PROD_CARAMEL: { integerValue: '1' },
                PROD_MATCHA: { integerValue: '2' },
                PROD_MOCHA: { integerValue: '2' }
              }
            }
          },
          hasManualQuotaOverdraft: { booleanValue: false },
          manualQuotaOverdrafts: { mapValue: { fields: {} } }
        }
      },
      currentDocument: { exists: false }
    },
    // Product 1
    {
      update: {
        name: docName('branch_product_servings/br_1790905840872_PROD_SPANISH'),
        fields: { remainingServings: { integerValue: '6' }, lastSaleId: { stringValue: multi5SaleId } }
      },
      updateMask: { fieldPaths: ['remainingServings', 'lastSaleId'] },
      currentDocument: { exists: true }
    },
    {
      update: {
        name: docName(`quota_transactions/${multi5SaleId}_PROD_SPANISH`),
        fields: {
          transactionId: { stringValue: `${multi5SaleId}_PROD_SPANISH` },
          saleId: { stringValue: multi5SaleId },
          clientSaleId: { stringValue: multi5SaleId },
          branchId: { stringValue: 'br_1790905840872' },
          productId: { stringValue: 'PROD_SPANISH' },
          requestedQuantity: { integerValue: '1' },
          deductedQuantity: { integerValue: '1' },
          overdraftQuantity: { integerValue: '0' },
          previousRemaining: { integerValue: '7' },
          newRemaining: { integerValue: '6' },
          isOfflineSync: { booleanValue: false }
        }
      },
      currentDocument: { exists: false }
    },
    // Product 2
    {
      update: {
        name: docName('branch_product_servings/br_1790905840872_PROD_AMERICANO'),
        fields: { remainingServings: { integerValue: '16' }, lastSaleId: { stringValue: multi5SaleId } }
      },
      updateMask: { fieldPaths: ['remainingServings', 'lastSaleId'] },
      currentDocument: { exists: true }
    },
    {
      update: {
        name: docName(`quota_transactions/${multi5SaleId}_PROD_AMERICANO`),
        fields: {
          transactionId: { stringValue: `${multi5SaleId}_PROD_AMERICANO` },
          saleId: { stringValue: multi5SaleId },
          clientSaleId: { stringValue: multi5SaleId },
          branchId: { stringValue: 'br_1790905840872' },
          productId: { stringValue: 'PROD_AMERICANO' },
          requestedQuantity: { integerValue: '2' },
          deductedQuantity: { integerValue: '2' },
          overdraftQuantity: { integerValue: '0' },
          previousRemaining: { integerValue: '18' },
          newRemaining: { integerValue: '16' },
          isOfflineSync: { booleanValue: false }
        }
      },
      currentDocument: { exists: false }
    },
    // Product 3
    {
      update: {
        name: docName('branch_product_servings/br_1790905840872_PROD_CARAMEL'),
        fields: { remainingServings: { integerValue: '11' }, lastSaleId: { stringValue: multi5SaleId } }
      },
      updateMask: { fieldPaths: ['remainingServings', 'lastSaleId'] },
      currentDocument: { exists: true }
    },
    {
      update: {
        name: docName(`quota_transactions/${multi5SaleId}_PROD_CARAMEL`),
        fields: {
          transactionId: { stringValue: `${multi5SaleId}_PROD_CARAMEL` },
          saleId: { stringValue: multi5SaleId },
          clientSaleId: { stringValue: multi5SaleId },
          branchId: { stringValue: 'br_1790905840872' },
          productId: { stringValue: 'PROD_CARAMEL' },
          requestedQuantity: { integerValue: '1' },
          deductedQuantity: { integerValue: '1' },
          overdraftQuantity: { integerValue: '0' },
          previousRemaining: { integerValue: '12' },
          newRemaining: { integerValue: '11' },
          isOfflineSync: { booleanValue: false }
        }
      },
      currentDocument: { exists: false }
    },
    // Product 4
    {
      update: {
        name: docName('branch_product_servings/br_1790905840872_PROD_MATCHA'),
        fields: { remainingServings: { integerValue: '6' }, lastSaleId: { stringValue: multi5SaleId } }
      },
      updateMask: { fieldPaths: ['remainingServings', 'lastSaleId'] },
      currentDocument: { exists: true }
    },
    {
      update: {
        name: docName(`quota_transactions/${multi5SaleId}_PROD_MATCHA`),
        fields: {
          transactionId: { stringValue: `${multi5SaleId}_PROD_MATCHA` },
          saleId: { stringValue: multi5SaleId },
          clientSaleId: { stringValue: multi5SaleId },
          branchId: { stringValue: 'br_1790905840872' },
          productId: { stringValue: 'PROD_MATCHA' },
          requestedQuantity: { integerValue: '2' },
          deductedQuantity: { integerValue: '2' },
          overdraftQuantity: { integerValue: '0' },
          previousRemaining: { integerValue: '8' },
          newRemaining: { integerValue: '6' },
          isOfflineSync: { booleanValue: false }
        }
      },
      currentDocument: { exists: false }
    },
    // Product 5
    {
      update: {
        name: docName('branch_product_servings/br_1790905840872_PROD_MOCHA'),
        fields: { remainingServings: { integerValue: '10' }, lastSaleId: { stringValue: multi5SaleId } }
      },
      updateMask: { fieldPaths: ['remainingServings', 'lastSaleId'] },
      currentDocument: { exists: true }
    },
    {
      update: {
        name: docName(`quota_transactions/${multi5SaleId}_PROD_MOCHA`),
        fields: {
          transactionId: { stringValue: `${multi5SaleId}_PROD_MOCHA` },
          saleId: { stringValue: multi5SaleId },
          clientSaleId: { stringValue: multi5SaleId },
          branchId: { stringValue: 'br_1790905840872' },
          productId: { stringValue: 'PROD_MOCHA' },
          requestedQuantity: { integerValue: '2' },
          deductedQuantity: { integerValue: '2' },
          overdraftQuantity: { integerValue: '0' },
          previousRemaining: { integerValue: '12' },
          newRemaining: { integerValue: '10' },
          isOfflineSync: { booleanValue: false }
        }
      },
      currentDocument: { exists: false }
    }
  ], santaCruzToken);
  assert(r23.status === 200, '23. Five-product online sale transaction succeeds (Rules access calls verified)', r23.text);

  // TEST 24: Multi-product offline sale with mixed overdrafts and sufficient stock
  // PROD_SPANISH: remaining 6, requested 10 -> deducted 6, overdraft 4, new 0
  // PROD_MATCHA:  remaining 6, requested 2  -> deducted 2, overdraft 0, new 4
  const multiOverSaleId = 'SALE_MULTI_OVERDRAFT_MIXED';
  const r24 = await commitWrites([
    {
      update: {
        name: docName(`sales/${multiOverSaleId}`),
        fields: {
          saleId: { stringValue: multiOverSaleId },
          clientSaleId: { stringValue: multiOverSaleId },
          branchId: { stringValue: 'br_1790905840872' },
          productQuantities: {
            mapValue: {
              fields: {
                PROD_SPANISH: { integerValue: '10' },
                PROD_MATCHA: { integerValue: '2' }
              }
            }
          },
          hasManualQuotaOverdraft: { booleanValue: true },
          manualQuotaOverdrafts: {
            mapValue: {
              fields: {
                PROD_SPANISH: { integerValue: '4' }
              }
            }
          }
        }
      },
      currentDocument: { exists: false }
    },
    // Spanish Quota (Overdrafted to 0)
    {
      update: {
        name: docName('branch_product_servings/br_1790905840872_PROD_SPANISH'),
        fields: { remainingServings: { integerValue: '0' }, lastSaleId: { stringValue: multiOverSaleId } }
      },
      updateMask: { fieldPaths: ['remainingServings', 'lastSaleId'] },
      currentDocument: { exists: true }
    },
    // Spanish Ledger
    {
      update: {
        name: docName(`quota_transactions/${multiOverSaleId}_PROD_SPANISH`),
        fields: {
          transactionId: { stringValue: `${multiOverSaleId}_PROD_SPANISH` },
          saleId: { stringValue: multiOverSaleId },
          clientSaleId: { stringValue: multiOverSaleId },
          branchId: { stringValue: 'br_1790905840872' },
          productId: { stringValue: 'PROD_SPANISH' },
          requestedQuantity: { integerValue: '10' },
          deductedQuantity: { integerValue: '6' },
          overdraftQuantity: { integerValue: '4' },
          previousRemaining: { integerValue: '6' },
          newRemaining: { integerValue: '0' },
          isOfflineSync: { booleanValue: true }
        }
      },
      currentDocument: { exists: false }
    },
    // Matcha Quota (Sufficient, decremented normally)
    {
      update: {
        name: docName('branch_product_servings/br_1790905840872_PROD_MATCHA'),
        fields: { remainingServings: { integerValue: '4' }, lastSaleId: { stringValue: multiOverSaleId } }
      },
      updateMask: { fieldPaths: ['remainingServings', 'lastSaleId'] },
      currentDocument: { exists: true }
    },
    // Matcha Ledger
    {
      update: {
        name: docName(`quota_transactions/${multiOverSaleId}_PROD_MATCHA`),
        fields: {
          transactionId: { stringValue: `${multiOverSaleId}_PROD_MATCHA` },
          saleId: { stringValue: multiOverSaleId },
          clientSaleId: { stringValue: multiOverSaleId },
          branchId: { stringValue: 'br_1790905840872' },
          productId: { stringValue: 'PROD_MATCHA' },
          requestedQuantity: { integerValue: '2' },
          deductedQuantity: { integerValue: '2' },
          overdraftQuantity: { integerValue: '0' },
          previousRemaining: { integerValue: '6' },
          newRemaining: { integerValue: '4' },
          isOfflineSync: { booleanValue: true }
        }
      },
      currentDocument: { exists: false }
    }
  ], santaCruzToken);
  assert(r24.status === 200, '24. Multi-product offline sale with mixed overdraft succeeds', r24.text);

  // TEST 25: Multi-product offline sale where one product is ALREADY at zero
  // PROD_ZERO:    remaining 0, requested 2 -> deducted 0, overdraft 2, new 0
  // PROD_AMERICANO: remaining 16, requested 3 -> deducted 3, overdraft 0, new 13
  const multiZeroSaleId = 'SALE_MULTI_ONE_AT_ZERO';
  const r25 = await commitWrites([
    {
      update: {
        name: docName(`sales/${multiZeroSaleId}`),
        fields: {
          saleId: { stringValue: multiZeroSaleId },
          clientSaleId: { stringValue: multiZeroSaleId },
          branchId: { stringValue: 'br_1790905840872' },
          productQuantities: {
            mapValue: {
              fields: {
                PROD_ZERO: { integerValue: '2' },
                PROD_AMERICANO: { integerValue: '3' }
              }
            }
          },
          hasManualQuotaOverdraft: { booleanValue: true },
          manualQuotaOverdrafts: {
            mapValue: {
              fields: {
                PROD_ZERO: { integerValue: '2' }
              }
            }
          }
        }
      },
      currentDocument: { exists: false }
    },
    // PROD_ZERO (already 0, stays 0)
    {
      update: {
        name: docName('branch_product_servings/br_1790905840872_PROD_ZERO'),
        fields: { remainingServings: { integerValue: '0' }, lastSaleId: { stringValue: multiZeroSaleId } }
      },
      updateMask: { fieldPaths: ['remainingServings', 'lastSaleId'] },
      currentDocument: { exists: true }
    },
    {
      update: {
        name: docName(`quota_transactions/${multiZeroSaleId}_PROD_ZERO`),
        fields: {
          transactionId: { stringValue: `${multiZeroSaleId}_PROD_ZERO` },
          saleId: { stringValue: multiZeroSaleId },
          clientSaleId: { stringValue: multiZeroSaleId },
          branchId: { stringValue: 'br_1790905840872' },
          productId: { stringValue: 'PROD_ZERO' },
          requestedQuantity: { integerValue: '2' },
          deductedQuantity: { integerValue: '0' },
          overdraftQuantity: { integerValue: '2' },
          previousRemaining: { integerValue: '0' },
          newRemaining: { integerValue: '0' },
          isOfflineSync: { booleanValue: true }
        }
      },
      currentDocument: { exists: false }
    },
    // PROD_AMERICANO (16 -> 13)
    {
      update: {
        name: docName('branch_product_servings/br_1790905840872_PROD_AMERICANO'),
        fields: { remainingServings: { integerValue: '13' }, lastSaleId: { stringValue: multiZeroSaleId } }
      },
      updateMask: { fieldPaths: ['remainingServings', 'lastSaleId'] },
      currentDocument: { exists: true }
    },
    {
      update: {
        name: docName(`quota_transactions/${multiZeroSaleId}_PROD_AMERICANO`),
        fields: {
          transactionId: { stringValue: `${multiZeroSaleId}_PROD_AMERICANO` },
          saleId: { stringValue: multiZeroSaleId },
          clientSaleId: { stringValue: multiZeroSaleId },
          branchId: { stringValue: 'br_1790905840872' },
          productId: { stringValue: 'PROD_AMERICANO' },
          requestedQuantity: { integerValue: '3' },
          deductedQuantity: { integerValue: '3' },
          overdraftQuantity: { integerValue: '0' },
          previousRemaining: { integerValue: '16' },
          newRemaining: { integerValue: '13' },
          isOfflineSync: { booleanValue: true }
        }
      },
      currentDocument: { exists: false }
    }
  ], santaCruzToken);
  assert(r25.status === 200, '25. Multi-product offline sale with one product already at zero succeeds', r25.text);

  console.log('\n--- PART E: OWNER PRIVILEGES & EXISTING REGRESSION HEALTH ---\n');

  // TEST 26: Existing owner quota-management permissions still work
  const r26 = await patchDoc('branch_product_servings/br_1790905840872_PROD_SPANISH', {
    remainingServings: { integerValue: '50' },
    manualMaxServings: { integerValue: '50' },
    isEnabled: { booleanValue: true }
  }, ownerToken);
  assert(r26.status === 200, '26. Existing owner quota-management permissions still work', r26.text);

  // TEST 27: Existing Web Admin sales and attendance permissions remain unaffected
  const r27SaleOwner = await patchDoc(`sales/${saleId1}`, {
    status: { stringValue: 'Completed' }
  }, ownerToken, ['status']);
  assert(r27SaleOwner.status === 200, '27a. Owner can update sales record', r27SaleOwner.text);

  const r27AttendanceOwner = await getDoc('attendance/att_test_1', ownerToken);
  assert(r27AttendanceOwner.status === 200, '27b. Owner can access attendance records', r27AttendanceOwner.text);

  const r27AttendanceBranch = await getDoc('attendance/att_test_1', santaCruzToken);
  assert(r27AttendanceBranch.status === 403, '27c. Branch POS cannot access attendance records', `Got status ${r27AttendanceBranch.status}`);

  // TEST 28: Catch-all owner rule does not accidentally grant branch POS access
  const r28 = await getDoc('internal_admin_secrets/secret_1', santaCruzToken);
  assert(r28.status === 403, '28. Catch-all owner rule does not grant branch POS access to other collections', `Got status ${r28.status}`);

  console.log(`\n=============================================================`);
  console.log(`CHECKPOINT 6.3.1 EMULATOR TEST SUMMARY: ${passed} PASSED, ${failed} FAILED`);
  console.log(`=============================================================\n`);

  if (failed > 0) {
    process.exit(1);
  } else {
    process.exit(0);
  }
}

run().catch(err => {
  console.error('Test runner fatal error:', err);
  process.exit(1);
});
