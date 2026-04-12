import { Router } from 'express';
import { generateUserBio } from '../controllers/bio-controller';

const bioRouter = Router();

// POST /api/v1/users/:id/generate-bio
// TODO: Consider adding authentication middleware (e.g., verifyToken) to this route in the future, ensuring users can only generate their own Bio
bioRouter.post('/:id/generate-bio', generateUserBio);

export { bioRouter };