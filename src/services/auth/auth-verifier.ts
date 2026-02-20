import { env } from '../../config/env';
import { badRequest, unauthorized } from '../../utils/errors';
import { AuthIdentity, AuthProvider } from './types';

export interface AuthVerifier {
  verifyIdToken(idToken: string, expectedProvider?: AuthProvider): Promise<AuthIdentity>;
}

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

class FirebaseVerifierStub implements AuthVerifier {
  async verifyIdToken(): Promise<AuthIdentity> {
    unauthorized('Firebase verifier is not configured yet', 'FIREBASE_NOT_READY');
  }
}

function isAuthProvider(input: string): input is AuthProvider {
  return input === 'google' || input === 'apple' || input === 'password';
}

export function createAuthVerifier(): AuthVerifier {
  if (env.authProviderMode === 'mock') {
    return new MockFirebaseVerifier();
  }

  return new FirebaseVerifierStub();
}
