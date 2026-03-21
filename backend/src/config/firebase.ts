import * as admin from 'firebase-admin';

// Do NOT call admin.storage().bucket() at module load time.
// admin.initializeApp() is called lazily by RealFirebaseVerifier in auth-verifier.ts.
// Use getStorageBucket() — it defers resolution until first call, after init has run.

let _bucket: ReturnType<ReturnType<typeof admin.storage>['bucket']> | undefined;

export function getStorageBucket() {
  if (!_bucket) {
    _bucket = admin.storage().bucket();
  }
  return _bucket;
}

export default admin;
