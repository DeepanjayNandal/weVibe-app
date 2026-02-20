import { AuthIdentity } from '../services/auth/types';

declare global {
  namespace Express {
    interface Request {
      auth?: AuthIdentity;
      idToken?: string;
    }
  }
}

export {};
