import { Router, Request, Response, NextFunction } from 'express';
import { ProfileController } from '../controllers/profile-controller';
import { ProfileService } from '../services/profile-service';
import { ProfileRepository } from '../repositories/profile-repository';
import { UserRepository } from '../repositories/user-repository';
import { authenticate } from '../middleware/authenticate';
import { createAuthVerifier } from '../services/auth/auth-verifier';

const authVerifier = createAuthVerifier();
const profileRepository = new ProfileRepository();
const userRepository = new UserRepository();
const profileService = new ProfileService(profileRepository);
const profileController = new ProfileController(profileService, userRepository);

function asyncHandler(
  handler: (req: Request, res: Response, next: NextFunction) => Promise<void>,
) {
  return (req: Request, res: Response, next: NextFunction): void => {
    handler(req, res, next).catch(next);
  };
}

export const userRouter = Router();

userRouter.post(
  '/profile',
  authenticate(authVerifier),
  asyncHandler(profileController.createProfile),
);
