import { Request, Response } from 'express';
import { UserService } from '../services/user-service';
import { badRequest } from '../utils/errors';

export class UserController {
  constructor(private readonly userService: UserService) {}

  deleteAccount = async (req: Request, res: Response): Promise<void> => {
    const firebaseUid = req.auth!.uid;
    await this.userService.deleteAccount(firebaseUid);
    res.status(200).json({ success: true });
  };

  updateFcmToken = async (req: Request, res: Response): Promise<void> => {
    const firebaseUid = req.auth!.uid;
    const { fcmToken } = req.body ?? {};

    if (typeof fcmToken !== 'string' || fcmToken.trim().length === 0) {
      badRequest('fcmToken is required and must be a non-empty string', 'INVALID_FCM_TOKEN');
    }

    await this.userService.updateFcmToken(firebaseUid, fcmToken.trim());
    res.status(200).json({ success: true });
  };
}
