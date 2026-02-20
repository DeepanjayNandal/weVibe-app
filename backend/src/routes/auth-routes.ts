import { Router, Request, Response, NextFunction } from 'express';
import { AuthController } from '../controllers/auth-controller';
import { authenticate } from '../middleware/authenticate';
import { createAuthVerifier } from '../services/auth/auth-verifier';
import { AuthService } from '../services/auth-service';
import { UserRepository } from '../repositories/user-repository';

const authVerifier = createAuthVerifier();
const userRepository = new UserRepository();
const authService = new AuthService(userRepository, authVerifier);
const authController = new AuthController(authService);

function asyncHandler(
  handler: (req: Request, res: Response, next: NextFunction) => Promise<void>,
) {
  return (req: Request, res: Response, next: NextFunction): void => {
    handler(req, res, next).catch(next);
  };
}

export const authRouter = Router();

authRouter.post('/register', asyncHandler(authController.register));
authRouter.post('/login', asyncHandler(authController.login));
authRouter.post('/logout', authenticate(authVerifier), asyncHandler(authController.logout));
authRouter.get('/me', authenticate(authVerifier), asyncHandler(authController.me));
