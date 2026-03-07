import { Router, Request, Response, NextFunction } from 'express';
import { authenticate } from '../middleware/authenticate';
import { createAuthVerifier } from '../services/auth/auth-verifier';
import { UserRepository } from '../repositories/user-repository';
import { MatchingQueueRepository } from '../repositories/matching-queue-repository';
import { MatchService } from '../services/match-service';
import { MatchmakingService } from '../services/matchmaking-service';
import { MatchmakingController } from '../controllers/matchmaking-controller';

const authVerifier = createAuthVerifier();
const userRepository = new UserRepository();
const queueRepository = new MatchingQueueRepository();
const matchService = new MatchService();
const matchmakingService = new MatchmakingService(queueRepository, matchService);
const matchmakingController = new MatchmakingController(matchmakingService, userRepository);

function asyncHandler(
  handler: (req: Request, res: Response, next: NextFunction) => Promise<void>,
) {
  return (req: Request, res: Response, next: NextFunction): void => {
    handler(req, res, next).catch(next);
  };
}

export const matchmakingRouter = Router();

matchmakingRouter.post(
  '/queue/join',
  authenticate(authVerifier),
  asyncHandler(matchmakingController.joinQueue),
);

matchmakingRouter.post(
  '/queue/leave',
  authenticate(authVerifier),
  asyncHandler(matchmakingController.leaveQueue),
);

matchmakingRouter.get(
  '/queue/status',
  authenticate(authVerifier),
  asyncHandler(matchmakingController.getQueueStatus),
);
