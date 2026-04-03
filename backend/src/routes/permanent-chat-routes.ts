import { Router, Request, Response, NextFunction } from 'express';
import { authenticate } from '../middleware/authenticate';
import { createAuthVerifier } from '../services/auth/auth-verifier';
import { UserRepository } from '../repositories/user-repository';
import { PermanentChatService } from '../services/permanent-chat-service';
import { SpeedDatingService } from '../services/speed-dating-service';
import { PermanentChatController } from '../controllers/permanent-chat-controller';

const authVerifier = createAuthVerifier();
const userRepository = new UserRepository();
const permanentChatService = new PermanentChatService();
const speedDatingService = new SpeedDatingService();
const permanentChatController = new PermanentChatController(
  permanentChatService,
  speedDatingService,
  userRepository,
);

function asyncHandler(
  handler: (req: Request, res: Response, next: NextFunction) => Promise<void>,
) {
  return (req: Request, res: Response, next: NextFunction): void => {
    handler(req, res, next).catch(next);
  };
}

export const permanentChatRouter = Router();

permanentChatRouter.get(
  '/matches',
  authenticate(authVerifier),
  asyncHandler(permanentChatController.listMatches),
);

permanentChatRouter.get(
  '/matches/:matchId',
  authenticate(authVerifier),
  asyncHandler(permanentChatController.getMatchDetail),
);

permanentChatRouter.get(
  '/matches/:matchId/messages',
  authenticate(authVerifier),
  asyncHandler(permanentChatController.getMatchMessages),
);

permanentChatRouter.get(
  '/matches/:matchId/profile',
  authenticate(authVerifier),
  asyncHandler(permanentChatController.getMatchProfile),
);

permanentChatRouter.patch(
  '/matches/:matchId/read',
  authenticate(authVerifier),
  asyncHandler(permanentChatController.markMatchMessagesRead),
);

permanentChatRouter.post(
  '/matches/:matchId/messages',
  authenticate(authVerifier),
  asyncHandler(permanentChatController.sendMessage),
);

permanentChatRouter.post(
  '/matches/:matchId/remove',
  authenticate(authVerifier),
  asyncHandler(permanentChatController.removeMatch),
);

permanentChatRouter.post(
  '/matches/:matchId/block',
  authenticate(authVerifier),
  asyncHandler(permanentChatController.blockCounterpart),
);

permanentChatRouter.post(
  '/matches/:matchId/report',
  authenticate(authVerifier),
  asyncHandler(permanentChatController.reportCounterpart),
);
