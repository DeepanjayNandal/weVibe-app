import { Router } from 'express';
import { authRouter } from './auth-routes';
import { userRouter } from './user-routes';

export const apiRouter = Router();

apiRouter.use('/auth', authRouter);
apiRouter.use('/users', userRouter);
