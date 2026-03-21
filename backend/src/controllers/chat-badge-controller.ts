import { Request, Response } from 'express';
import { UserRepository } from '../repositories/user-repository';
import { PermanentChatService } from '../services/permanent-chat-service';
import { SpeedDatingService } from '../services/speed-dating-service';
import { unauthorized } from '../utils/errors';

export class ChatBadgeController {
  constructor(
    private readonly speedDatingService: SpeedDatingService,
    private readonly permanentChatService: PermanentChatService,
    private readonly userRepository: UserRepository,
  ) {}

  getBadgeSummary = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);

    const [speedDatingUnread, matchesUnread] = await Promise.all([
      this.speedDatingService.getUnreadCount(userId),
      this.permanentChatService.getUnreadCount(userId),
    ]);

    res.status(200).json({
      success: true,
      data: {
        speedDatingUnread,
        matchesUnread,
        totalUnread: speedDatingUnread + matchesUnread,
      },
    });
  };

  private async resolveUserId(req: Request): Promise<string> {
    const firebaseUid = req.auth?.uid;
    if (!firebaseUid) {
      unauthorized('User identity not found in request', 'MISSING_USER_IDENTITY');
    }

    const user = await this.userRepository.findByFirebaseUid(firebaseUid);
    if (!user) {
      unauthorized('User not found in database', 'USER_NOT_FOUND');
    }

    return user.id;
  }
}
