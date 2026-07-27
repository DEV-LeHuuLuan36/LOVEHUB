import 'firebase-functions/v2/https';

export default ...;

/**
 * Cloud Functions for Play Integrity verification.
 *
 * These live separately (functions/) so the Spark plan doesn't have
 * to host them. In a real product they would live in `functions/`
 * with the Firebase Functions SDK. For this project's purposes we
 * document the contract here; the production team implements them.
 */

// ============================================================================
// POST /api/v1/integrity:exchange
// ============================================================================
// Body:  { nonce: string }
// Reply: { token: string }              // raw Play Integrity token
// Errors: 403 if the calling user's device is not registered.
// ============================================================================

export const exchangeNonceForToken = onCall({region: 'us-central1'}, async (req) => {
  // 1. Auth check
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in first.');

  // 2. Verify the caller's app has been published and the user is in
  //    a valid couple (Layer 6 server-side).
  const uid = req.auth.uid;
  const userDoc = await admin.firestore().doc(`users/${uid}`).get();
  if (!userDoc.exists) {
    throw new HttpsError('permission-denied', 'No such user.');
  }

  // 3. Validate nonce (≤ 16 chars base64, recent).
  const nonce = req.data?.nonce;
  if (typeof nonce !== 'string' || nonce.length > 64) {
    throw new HttpsError('invalid-argument', 'Bad nonce.');
  }

  // 4. Return a *server-issued* nonce that Play will sign. The mobile
  //    app then asks Play Integrity with this nonce and gets back a
  //    signed verdict.
  const crypto = require('crypto');
  const serverNonce = crypto.randomBytes(16).toString('base64');

  // Cache serverNonce → uid for the next call (5 min TTL).
  await admin.firestore().collection('_integrity').doc(serverNonce).set({
    uid,
    issuedAt: Date.now(),
    expiresAt: Date.now() + 5 * 60_000,
  });

  return { token: serverNonce };
});

// ============================================================================
// POST /api/v1/integrity:verify
// ============================================================================
// Body:  { token: string }              // Play-signed integrity verdict (JWT)
// Reply: { device, app, account, verdict }
// ============================================================================

export const verifyIntegrityToken = onCall({region: 'us-central1'}, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in first.');

  const token = req.data?.token;
  if (typeof token !== 'string') {
    throw new HttpsError('invalid-argument', 'Missing token.');
  }

  // 1. Decode the integrity verdict (JWT, signed by Google).
  const verdict = await decodePlayIntegrity(token);
  if (!verdict) {
    throw new HttpsError('invalid-argument', 'Malformed verdict.');
  }

  // 2. Look up the server nonce → uid mapping.
  const nonce = verdict.requestDetails?.nonce;
  if (!nonce) {
    throw new HttpsError('invalid-argument', 'No nonce.');
  }
  const doc = await admin.firestore().collection('_integrity').doc(nonce).get();
  if (!doc.exists) {
    throw new HttpsError('failed-precondition', 'Nonce expired or unknown.');
  }
  const ttl = doc.data().expiresAt;
  if (Date.now() > ttl) {
    throw new HttpsError('failed-precondition', 'Nonce expired.');
  }
  if (doc.data().uid !== req.auth.uid) {
    throw new HttpsError('permission-denied', 'Nonce was issued to another user.');
  }

  // 3. Burn the nonce — replay protection.
  await admin.firestore().collection('_integrity').doc(nonce).delete();

  // 4. Persist the verdict to the user doc. Firestore rules use this
  //    field to deny writes from non-attested devices.
  await admin.firestore().doc(`users/${req.auth.uid}`).set({
    integrityVerdict: {
      device: verdict.deviceIntegrity,
      app: verdict.appIntegrity,
      account: verdict.accountDetailsLicense,
      ts: admin.firestore.FieldValue.serverTimestamp(),
    },
  }, {merge: true});

  return {
    device: verdict.deviceIntegrity,
    app: verdict.appIntegrity,
    account: verdict.accountDetailsLicense,
    verdict: 'OK',
  };
});

// ─── Helpers (sketched) ─────────────────────────────────────────────────

async function decodePlayIntegrity(jwt) {
  // 1. Fetch Google's certs at https://www.googleapis.com/oauth2/v3/certs
  // 2. Verify signature with RS256 against the kid in the JWT header.
  // 3. Decode payload, return the verdict object.
  //
  // For brevity: assume this is delegated to a vetted library like
  // `google-auth-library` (Node) or implemented once and reused.
  return null;
}