import { AuthIdentity } from '../services/auth/types';
import { Request } from 'express';

// Extend Express's Request interface so TypeScript knows about auth fields
// set by the authenticate middleware. This gives type safety and autocomplete
// in every route handler — no need for (req as any) casts anywhere.
declare global {
  namespace Express {
    interface Request {
      // Verified identity from Firebase (uid, email, provider) — set after token verification
      auth?: AuthIdentity;
      // The raw Firebase idToken from the Authorization header — used by logout/me
      idToken?: string;
    }
  }
}

export {};
