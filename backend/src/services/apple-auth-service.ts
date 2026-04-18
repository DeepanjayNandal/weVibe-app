import { createSign } from 'crypto';
import { env } from '../config/env';

// Apple token endpoint responses
interface AppleTokenResponse {
  access_token: string;
  token_type: string;
  expires_in: number;
  refresh_token: string;
  id_token: string;
}

interface AppleErrorResponse {
  error: string;
}

/**
 * Encodes a Buffer or string to base64url (no padding, URL-safe).
 */
function base64url(input: Buffer | string): string {
  const buf = typeof input === 'string' ? Buffer.from(input, 'utf8') : input;
  return buf.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
}

/**
 * Generates a short-lived JWT client_secret for use with Apple's token/revoke endpoints.
 * Uses ES256 (ECDSA P-256 SHA-256) with the Apple Sign-In private key.
 * Valid for 5 minutes — sufficient for a single token exchange or revocation.
 *
 * @param clientId - The app's bundle ID (e.g. com.wevibe1.app).
 */
function generateClientSecret(clientId: string): string {
  const now = Math.floor(Date.now() / 1000);

  const header = base64url(JSON.stringify({ alg: 'ES256', kid: env.appleKeyId }));
  const claims = base64url(JSON.stringify({
    iss: env.appleTeamId,
    iat: now,
    exp: now + 300,
    aud: 'https://appleid.apple.com',
    sub: clientId,
  }));

  const signingInput = `${header}.${claims}`;

  // dsaEncoding: 'ieee-p1363' produces the raw R||S format required by JWT ES256
  // (Node.js default is DER — wrong for JWT). Available since Node.js 15.
  const sign = createSign('SHA256');
  sign.update(signingInput);
  const signature = sign.sign({
    key: env.applePrivateKey,
    dsaEncoding: 'ieee-p1363',
  });

  return `${signingInput}.${base64url(signature)}`;
}

/**
 * Exchanges a one-time Apple authorization code for an access + refresh token.
 * The refresh token should be stored and used for revocation on account deletion.
 *
 * @param authorizationCode - The one-time code from ASAuthorizationAppleIDCredential.authorizationCode.
 * @param bundleId - The app bundle ID used during sign-in (com.wevibe1.app or com.wevibe1.appdev).
 * @returns The Apple refresh token, or null if the exchange fails or credentials are not configured.
 */
export async function exchangeAppleCode(
  authorizationCode: string,
  bundleId: string,
): Promise<string | null> {
  if (!env.appleTeamId || !env.appleKeyId || !env.applePrivateKey) {
    return null;
  }

  const clientSecret = generateClientSecret(bundleId);

  const body = new URLSearchParams({
    client_id: bundleId,
    client_secret: clientSecret,
    code: authorizationCode,
    grant_type: 'authorization_code',
  });

  try {
    const response = await fetch('https://appleid.apple.com/auth/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString(),
    });

    const json = await response.json() as AppleTokenResponse | AppleErrorResponse;

    if ('error' in json) {
      console.error('[apple_auth] Token exchange failed:', json.error);
      return null;
    }

    return json.refresh_token ?? null;
  } catch (error) {
    console.error('[apple_auth] Token exchange request failed:', error);
    return null;
  }
}

/**
 * Revokes an Apple refresh token.
 * Call this before deleting an account to satisfy App Store Review Guideline 5.1.1.
 * Failures are logged but never thrown — the account deletion proceeds regardless.
 *
 * @param refreshToken - The stored Apple refresh token.
 * @param bundleId - The app bundle ID (must match the one used during sign-in).
 */
export async function revokeAppleToken(
  refreshToken: string,
  bundleId: string,
): Promise<void> {
  if (!env.appleTeamId || !env.appleKeyId || !env.applePrivateKey) {
    console.warn('[apple_auth] Apple credentials not configured — skipping token revocation');
    return;
  }

  const clientSecret = generateClientSecret(bundleId);

  const body = new URLSearchParams({
    client_id: bundleId,
    client_secret: clientSecret,
    token: refreshToken,
    token_type_hint: 'refresh_token',
  });

  try {
    const response = await fetch('https://appleid.apple.com/auth/revoke', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString(),
    });

    if (!response.ok) {
      const text = await response.text();
      console.error('[apple_auth] Token revocation failed:', response.status, text);
    }
  } catch (error) {
    console.error('[apple_auth] Token revocation request failed:', error);
  }
}
