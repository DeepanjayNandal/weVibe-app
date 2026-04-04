import { Request, Response } from 'express';
import { UserService } from '../services/user-service';

export class UserController {
  constructor(private readonly userService: UserService) {}

  deleteAccount = async (req: Request, res: Response): Promise<void> => {
    const firebaseUid = req.auth!.uid;
    await this.userService.deleteAccount(firebaseUid);
    res.status(200).json({ success: true });
  };
}
