import { Request, Response, NextFunction } from 'express';
import { BioGeneratorService } from '../services/bio-generator-service';
import { UserRepository } from '../repositories/user-repository';
import { unauthorized, forbidden } from '../utils/errors';

const bioGeneratorService = new BioGeneratorService();
const userRepository = new UserRepository();

export const generateUserBio = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const userId = req.params.id;
    const firebaseUid = req.auth?.uid;

    if (!firebaseUid) {
      unauthorized('User identity not found in request', 'MISSING_USER_IDENTITY');
    }

    const user = await userRepository.findByFirebaseUid(firebaseUid!);
    if (!user) {
      unauthorized('User not found in database', 'USER_NOT_FOUND');
    }

    if (user.id !== userId) {
      forbidden('You can only generate your own bio', 'FORBIDDEN_ACTION');
    }

    // 從 request body 中取得使用者自訂的 prompt (如果有提供的話)
    const customPrompt = typeof req.body?.prompt === 'string' ? req.body.prompt : undefined;
    
    // Call Service to execute generation and storage, 傳入 customPrompt
    const bio = await bioGeneratorService.generateAndSaveBio(userId, customPrompt);

    res.status(200).json({
      success: true,
      data: { bio },
      message: 'Bio generated and saved successfully.',
    });
  } catch (error) {
    next(error); // Pass to the existing errorHandler middleware for unified handling
  }
};