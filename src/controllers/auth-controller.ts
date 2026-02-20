import { Request, Response } from 'express';
import { users } from '@prisma/client';
import { AuthService } from '../services/auth-service';
import { badRequest } from '../utils/errors';
import { AuthProvider } from '../services/auth/types';

function isAuthProvider(input: string): input is AuthProvider {
  return input === 'google' || input === 'apple' || input === 'password';
}

function readProvider(value: unknown): AuthProvider {
  if (typeof value !== 'string' || !isAuthProvider(value)) {
    badRequest('provider must be one of google, apple, password', 'INVALID_PROVIDER');
  }

  return value;
}

function readIdToken(value: unknown): string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    badRequest('idToken is required', 'MISSING_ID_TOKEN');
  }

  return value.trim();
}

function serializeUser(user: users): Record<string, unknown> {
  return {
    id: user.id,
    email: user.email,
    phone: user.phone,
    firebaseUid: user.firebase_uid,
    authProvider: user.auth_provider,
    createdAt: user.created_at,
    lastActiveAt: user.last_active_at,
    isBanned: user.is_banned,
  };
}

export class AuthController {
  constructor(private readonly authService: AuthService) {}

  register = async (req: Request, res: Response): Promise<void> => {
    const provider = readProvider(req.body?.provider);
    const idToken = readIdToken(req.body?.idToken);
    const user = await this.authService.register({ provider, idToken });

    res.status(201).json({
      success: true,
      data: {
        user: serializeUser(user),
      },
    });
  };

  login = async (req: Request, res: Response): Promise<void> => {
    const provider = readProvider(req.body?.provider);
    const idToken = readIdToken(req.body?.idToken);
    const user = await this.authService.login({ provider, idToken });

    res.status(200).json({
      success: true,
      data: {
        user: serializeUser(user),
      },
    });
  };

  logout = async (req: Request, res: Response): Promise<void> => {
    const idToken = (req as any).idToken;
    if (!idToken) {
      badRequest('idToken not found in request context', 'MISSING_REQUEST_TOKEN');
    }

    await this.authService.logout(idToken);
    res.status(204).send();
  };

  me = async (req: Request, res: Response): Promise<void> => {
    const idToken = (req as any).idToken;
    if (!idToken) {
      badRequest('idToken not found in request context', 'MISSING_REQUEST_TOKEN');
    }

    const user = await this.authService.me(idToken);
    res.status(200).json({
      success: true,
      data: {
        user: serializeUser(user),
      },
    });
  };
}
