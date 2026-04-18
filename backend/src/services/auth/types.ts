export type AuthProvider = 'google' | 'apple' | 'facebook' | 'twitter' | 'email';

export interface AuthIdentity {
  uid: string;
  email: string;
  provider: AuthProvider;
}

export interface RegisterInput {
  provider: AuthProvider;
  idToken: string;
}

export interface LoginInput {
  provider: AuthProvider;
  idToken: string;
  // Apple Sign-In only — one-time code for server-side token exchange.
  // Provided on first sign-in; absent on subsequent sign-ins.
  appleAuthCode?: string;
  // The app bundle ID that generated the appleAuthCode (com.wevibe1.app or com.wevibe1.appdev).
  // Required when appleAuthCode is present.
  appleBundleId?: string;
}
