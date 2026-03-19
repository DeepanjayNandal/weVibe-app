import * as admin from 'firebase-admin';

let _bucket: ReturnType<typeof admin.storage>['bucket'] extends (...args: any[]) => infer R ? R : never;

export function getStorageBucket() {
  if (!_bucket) {
    _bucket = admin.storage().bucket();
  }
  return _bucket;
}

export default admin;