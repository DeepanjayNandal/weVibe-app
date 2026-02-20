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
}
