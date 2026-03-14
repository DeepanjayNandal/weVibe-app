import { Router } from 'express';
import { authRouter } from './auth-routes';
import { userRouter } from './user-routes';
import { matchmakingRouter } from './matchmaking-routes';
import { permanentChatRouter } from './permanent-chat-routes';

export const apiRouter = Router();

apiRouter.use('/auth', authRouter);
apiRouter.use('/users', userRouter);
apiRouter.use('/matching', matchmakingRouter);
apiRouter.use('/matching', permanentChatRouter);
