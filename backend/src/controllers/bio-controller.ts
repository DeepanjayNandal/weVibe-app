import { Request, Response, NextFunction } from 'express';
import { BioGeneratorService } from '../services/bio-generator-service';

const bioGeneratorService = new BioGeneratorService();

export const generateUserBio = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const userId = req.params.id;
    
    // Call Service to execute generation and storage
    const bio = await bioGeneratorService.generateAndSaveBio(userId);

    res.status(200).json({
      success: true,
      data: { bio },
      message: 'Bio generated and saved successfully.',
    });
  } catch (error) {
    next(error); // Pass to the existing errorHandler middleware for unified handling
  }
};