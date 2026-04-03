import * as admin from 'firebase-admin';
import { env } from '../../config/env';
import { badRequest, unauthorized } from '../../utils/errors';
import { AuthIdentity, AuthProvider } from './types';

// ---------------------------------------------------------------------------
// Interface — both mock and real verifiers implement this same contract
// ---------------------------------------------------------------------------
export interface AuthVerifier {
  verifyIdToken(idToken: string, expectedProvider?: AuthProvider): Promise<AuthIdentity>;
}

// ---------------------------------------------------------------------------
// MockFirebaseVerifier — used in local dev (AUTH_PROVIDER_MODE=mock)
// Token format: "mock:<provider>:<uid>:<email>"
// Example:      "mock:google:uid123:user@example.com"
// ---------------------------------------------------------------------------
class MockFirebaseVerifier implements AuthVerifier {
  async verifyIdToken(idToken: string, expectedProvider?: AuthProvider): Promise<AuthIdentity> {
    const segments = idToken.split(':');

    if (segments.length !== 4 || segments[0] !== 'mock') {
      unauthorized('Invalid idToken format', 'INVALID_ID_TOKEN');
    }

    const provider = segments[1] as AuthProvider;
    const uid = segments[2];
    const email = segments[3];

    if (!isAuthProvider(provider)) {
      badRequest('Unsupported provider in idToken', 'UNSUPPORTED_PROVIDER');
    }

    if (expectedProvider && provider !== expectedProvider) {
      badRequest('Provider mismatch', 'PROVIDER_MISMATCH');
    }

    if (!uid || !email || !email.includes('@')) {
      unauthorized('Invalid identity payload', 'INVALID_IDENTITY_PAYLOAD');
    }

    return { uid, email, provider };
  }
}

// ---------------------------------------------------------------------------
// RealFirebaseVerifier — used in production (AUTH_PROVIDER_MODE=firebase)
// Calls Firebase Admin SDK to cryptographically verify the idToken issued
// by Firebase on the frontend (after Google/Apple/email sign-in).
// Requires FIREBASE_PROJECT_ID and a valid service account in the environment.
// ---------------------------------------------------------------------------
class RealFirebaseVerifier implements AuthVerifier {
  constructor() {
    // Initialize Firebase Admin SDK only once.
    // `admin.apps.length` check prevents re-initialization on hot reloads.
    if (admin.apps.length === 0) {
      if (!env.firebaseProjectId) {
        throw new Error(
          'FIREBASE_PROJECT_ID is not set. Required when AUTH_PROVIDER_MODE=firebase.',
        );
      }

      const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT;
      const credentialsPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
      
      if (serviceAccountJson) {
        // Cloud Run: parse env JSON
        const serviceAccount = JSON.parse(serviceAccountJson);
        admin.initializeApp({
          credential: admin.credential.cert(serviceAccount),
          projectId: env.firebaseProjectId,
          storageBucket: env.firebaseStorageBucket,
        });
      } else if (credentialsPath) {
        // Local Dev
        const serviceAccount = require(require('path').resolve(credentialsPath));
        admin.initializeApp({
          credential: admin.credential.cert(serviceAccount),
          projectId: env.firebaseProjectId,
          storageBucket: env.firebaseStorageBucket,
        });
      } else {
        // Fallback:  GCP ADC
        admin.initializeApp({
          credential: admin.credential.applicationDefault(),
          projectId: env.firebaseProjectId,
          storageBucket: env.firebaseStorageBucket,
        });
      }
    }
  }

  async verifyIdToken(idToken: string, expectedProvider?: AuthProvider): Promise<AuthIdentity> {
    let decoded: admin.auth.DecodedIdToken;

    try {
      // Firebase Admin SDK verifies the token signature, expiry, and project ID.
      // This is the only call needed — no manual JWT parsing required.
      decoded = await admin.auth().verifyIdToken(idToken);
    } catch {
      unauthorized('Firebase token verification failed', 'INVALID_FIREBASE_TOKEN');
    }

    // Extract the sign-in provider from Firebase's token claims.
    // Firebase stores it as e.g. "google.com", "apple.com", "password" (email).
    const rawProvider = decoded.firebase?.sign_in_provider ?? '';
    const provider = normalizeFirebaseProvider(rawProvider);

    if (!provider) {
      unauthorized('Unrecognized Firebase sign-in provider', 'UNSUPPORTED_PROVIDER');
    }

    if (expectedProvider && provider !== expectedProvider) {
      badRequest('Provider mismatch', 'PROVIDER_MISMATCH');
    }

    const uid = decoded.uid;
    const email = decoded.email ?? '';

    if (!uid || !email) {
      unauthorized('Firebase token missing uid or email', 'INVALID_IDENTITY_PAYLOAD');
    }

    return { uid, email, provider };
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function isAuthProvider(input: string): input is AuthProvider {
  return (
    input === 'google' ||
    input === 'apple' ||
    input === 'facebook' ||
    input === 'twitter' ||
    input === 'email'
  );
}

// Firebase uses "google.com", "apple.com", "password" etc.
// We normalize these to our internal AuthProvider type.
function normalizeFirebaseProvider(raw: string): AuthProvider | null {
  const map: Record<string, AuthProvider> = {
    'google.com': 'google',
    'apple.com': 'apple',
    'facebook.com': 'facebook',
    'twitter.com': 'twitter',
    'password': 'email',   // Firebase calls email/password login "password"
    'email': 'email',
  };
  return map[raw] ?? null;
}

// ---------------------------------------------------------------------------
// Factory — picks the right verifier based on AUTH_PROVIDER_MODE env var
// ---------------------------------------------------------------------------
export function createAuthVerifier(): AuthVerifier {
  if (env.authProviderMode === 'mock') {
    // Local dev: no Firebase credentials needed
    return new MockFirebaseVerifier();
  }

  // Production: requires FIREBASE_PROJECT_ID + GOOGLE_APPLICATION_CREDENTIALS
  return new RealFirebaseVerifier();
}
