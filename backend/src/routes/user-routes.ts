import { Router, Request, Response, NextFunction } from 'express';
import { ProfileController } from '../controllers/profile-controller';
import { UserController } from '../controllers/user-controller';
import { ProfileService } from '../services/profile-service';
import { UserService } from '../services/user-service';
import { ProfileRepository } from '../repositories/profile-repository';
import { UserRepository } from '../repositories/user-repository';
import { authenticate } from '../middleware/authenticate';
import { createAuthVerifier } from '../services/auth/auth-verifier';

const authVerifier = createAuthVerifier();
const profileRepository = new ProfileRepository();
const userRepository = new UserRepository();
const profileService = new ProfileService(profileRepository);
const profileController = new ProfileController(profileService, userRepository);
const userService = new UserService(userRepository);
const userController = new UserController(userService);

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

userRouter.get(
  '/profile',
  authenticate(authVerifier),
  asyncHandler(profileController.getProfile),
);

// PATCH /profile — partial update, only fields present in the request body are updated
userRouter.patch(
  '/profile',
  authenticate(authVerifier),
  asyncHandler(profileController.updateProfile),
);

// DELETE /me — soft-deletes the authenticated user's account (30-day grace period)
userRouter.delete(
  '/me',
  authenticate(authVerifier),
  asyncHandler(userController.deleteAccount),
);
