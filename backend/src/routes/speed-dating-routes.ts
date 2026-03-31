import { Router, Request, Response, NextFunction } from 'express';
import { authenticate } from '../middleware/authenticate';
import { createAuthVerifier } from '../services/auth/auth-verifier';
import { UserRepository } from '../repositories/user-repository';
import { SpeedDatingService } from '../services/speed-dating-service';
import { PermanentChatService } from '../services/permanent-chat-service';
import { SpeedDatingController } from '../controllers/speed-dating-controller';

const authVerifier = createAuthVerifier();
const userRepository = new UserRepository();
const speedDatingService = new SpeedDatingService();
const permanentChatService = new PermanentChatService();
const speedDatingController = new SpeedDatingController(
  speedDatingService,
  permanentChatService,
  userRepository,
);

function asyncHandler(
  handler: (req: Request, res: Response, next: NextFunction) => Promise<void>,
) {
  return (req: Request, res: Response, next: NextFunction): void => {
    handler(req, res, next).catch(next);
  };
}

export const speedDatingRouter = Router();

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

speedDatingRouter.patch(
  '/sessions/:sessionId/read',
  authenticate(authVerifier),
  asyncHandler(speedDatingController.markSessionMessagesRead),
);

speedDatingRouter.post(
  '/sessions/:sessionId/messages',
  authenticate(authVerifier),
  asyncHandler(speedDatingController.sendMessage),
);

speedDatingRouter.post(
  '/sessions/:sessionId/move-to-permanent/request',
  authenticate(authVerifier),
  asyncHandler(speedDatingController.requestMoveToPermanent),
);

speedDatingRouter.post(
  '/sessions/:sessionId/move-to-permanent/respond',
  authenticate(authVerifier),
  asyncHandler(speedDatingController.respondToMoveToPermanent),
);

speedDatingRouter.post(
  '/sessions/:sessionId/final-decision',
  authenticate(authVerifier),
  asyncHandler(speedDatingController.submitFinalDecision),
);

speedDatingRouter.post(
  '/sessions/:sessionId/end',
  authenticate(authVerifier),
  asyncHandler(speedDatingController.endSession),
);
