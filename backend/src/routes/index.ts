import { Router } from 'express';
import { authRouter } from './auth-routes';
import { userRouter } from './user-routes';
import { matchmakingRouter } from './matchmaking-routes';
import { speedDatingRouter } from './speed-dating-routes';
import { permanentChatRouter } from './permanent-chat-routes';
import { photoRouter } from './photo.routes';
import { chatBadgeRouter } from './chat-badge-routes';

export const apiRouter = Router();

apiRouter.use('/auth', authRouter);
apiRouter.use('/users', userRouter);
apiRouter.use('/matching', matchmakingRouter);
apiRouter.use('/matching', speedDatingRouter);
apiRouter.use('/matching', permanentChatRouter);
apiRouter.use('/users/profile/photos', photoRouter);
apiRouter.use('/matching', chatBadgeRouter);
