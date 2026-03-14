import { Router, Request, Response, NextFunction } from 'express';
import { authenticate } from '../middleware/authenticate';
import { createAuthVerifier } from '../services/auth/auth-verifier';
import { UserRepository } from '../repositories/user-repository';
import { SpeedDatingService } from '../services/speed-dating-service';
import { SpeedDatingController } from '../controllers/speed-dating-controller';

const authVerifier = createAuthVerifier();
const userRepository = new UserRepository();
const speedDatingService = new SpeedDatingService();
const speedDatingController = new SpeedDatingController(speedDatingService, userRepository);

function asyncHandler(
  handler: (req: Request, res: Response, next: NextFunction) => Promise<void>,
) {
  return (req: Request, res: Response, next: NextFunction): void => {
    handler(req, res, next).catch(next);
  };
}

export const speedDatingRouter = Router();

speedDatingRouter.get(
  '/sessions',
  authenticate(authVerifier),
  asyncHandler(speedDatingController.listSessions),
);

speedDatingRouter.get(
  '/sessions/:sessionId',
  authenticate(authVerifier),
  asyncHandler(speedDatingController.getSessionDetail),
);

speedDatingRouter.get(
  '/sessions/:sessionId/messages',
  authenticate(authVerifier),
  asyncHandler(speedDatingController.getSessionMessages),
);

speedDatingRouter.post(
  '/sessions/:sessionId/messages',
  authenticate(authVerifier),
  asyncHandler(speedDatingController.sendMessage),
);
