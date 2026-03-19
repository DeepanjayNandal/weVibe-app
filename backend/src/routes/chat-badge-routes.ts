import { Router, Request, Response, NextFunction } from 'express';
import { authenticate } from '../middleware/authenticate';
import { createAuthVerifier } from '../services/auth/auth-verifier';
import { UserRepository } from '../repositories/user-repository';
import { SpeedDatingService } from '../services/speed-dating-service';
import { PermanentChatService } from '../services/permanent-chat-service';
import { ChatBadgeController } from '../controllers/chat-badge-controller';

const authVerifier = createAuthVerifier();
const userRepository = new UserRepository();
const speedDatingService = new SpeedDatingService();
const permanentChatService = new PermanentChatService();
const chatBadgeController = new ChatBadgeController(
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

export const chatBadgeRouter = Router();

chatBadgeRouter.get(
  '/chats/badges',
  authenticate(authVerifier),
  asyncHandler(chatBadgeController.getBadgeSummary),
);
