import { Router, Request, Response, NextFunction } from 'express';
import { authenticate } from '../middleware/authenticate';
import { createAuthVerifier } from '../services/auth/auth-verifier';
import { UserRepository } from '../repositories/user-repository';
import { PermanentChatService } from '../services/permanent-chat-service';
import { PermanentChatController } from '../controllers/permanent-chat-controller';

const authVerifier = createAuthVerifier();
const userRepository = new UserRepository();
const permanentChatService = new PermanentChatService();
const permanentChatController = new PermanentChatController(permanentChatService, userRepository);

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

permanentChatRouter.post(
  '/matches/:matchId/messages',
  authenticate(authVerifier),
  asyncHandler(permanentChatController.sendMessage),
);
