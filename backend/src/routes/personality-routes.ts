import { Router } from 'express';
import { authenticate } from '../middleware/authenticate';
import { createAuthVerifier } from '../services/auth/auth-verifier';
import { submitPersonalityTest, getPersonalityResult } from '../controllers/personality-controller';

const authVerifier = createAuthVerifier();
const auth = authenticate(authVerifier);

export const personalityRouter = Router();

personalityRouter.post('/', auth, submitPersonalityTest);
personalityRouter.get('/', auth, getPersonalityResult);
