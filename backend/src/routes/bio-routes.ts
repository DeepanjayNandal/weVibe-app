import { Router } from 'express';
import { generateUserBio } from '../controllers/bio-controller';
import { authenticate } from '../middleware/authenticate';
import { createAuthVerifier } from '../services/auth/auth-verifier';

const bioRouter = Router();
const authVerifier = createAuthVerifier();

// POST /api/v1/users/:id/generate-bio
bioRouter.post('/:id/generate-bio', authenticate(authVerifier), generateUserBio);

export { bioRouter };