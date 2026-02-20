export type AuthProvider = 'google' | 'apple' | 'password';

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
