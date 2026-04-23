import { Request, Response, NextFunction } from 'express';
import { BioGeneratorService } from '../services/bio-generator-service';
import { UserRepository } from '../repositories/user-repository';
import { unauthorized } from '../utils/errors';

const bioGeneratorService = new BioGeneratorService();
const userRepository = new UserRepository();

// POST /api/v1/users/profile/generate-bio
// Generates an AI bio for the authenticated user using their profile data.
// Rate-limited: 5 generations per day, 60s cooldown between requests.
export const generateUserBio = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const firebaseUid = req.auth?.uid;

    if (!firebaseUid) {
      unauthorized('User identity not found in request', 'MISSING_USER_IDENTITY');
    }

    const user = await userRepository.findByFirebaseUid(firebaseUid!);
    if (!user) {
      unauthorized('User not found in database', 'USER_NOT_FOUND');
    }

    const customPrompt = typeof req.body?.prompt === 'string' ? req.body.prompt : undefined;

    const { bio, remainingToday } = await bioGeneratorService.generateAndSaveBio(user!.id, customPrompt);

    res.status(200).json({
      success: true,
      data: { bio, remainingToday },
    });
  } catch (error) {
    next(error);
  }
};
