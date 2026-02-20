import { NextFunction, Request, Response } from 'express';
import { AuthVerifier } from '../services/auth/auth-verifier';
import { unauthorized } from '../utils/errors';

export function authenticate(authVerifier: AuthVerifier) {
  return async (req: Request, _res: Response, next: NextFunction): Promise<void> => {
    try {
      const authHeader = req.headers.authorization;
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        unauthorized('Missing bearer token', 'MISSING_BEARER_TOKEN');
      }

      const idToken = authHeader.slice('Bearer '.length).trim();
      if (!idToken) {
        unauthorized('Missing bearer token', 'MISSING_BEARER_TOKEN');
      }

      const identity = await authVerifier.verifyIdToken(idToken);
      (req as any).auth = identity;
      (req as any).idToken = idToken;
      next();
    } catch (error) {
      next(error);
    }
  };
}
