import { Request, Response } from 'express';
import { UserRepository } from '../repositories/user-repository';
import { SpeedDatingService } from '../services/speed-dating-service';
import { badRequest, unauthorized } from '../utils/errors';

export class SpeedDatingController {
  constructor(
    private readonly speedDatingService: SpeedDatingService,
    private readonly userRepository: UserRepository,
  ) {}

  listSessions = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const sessions = await this.speedDatingService.listSessions(userId);

    res.status(200).json({
      success: true,
      data: {
        sessions,
      },
    });
  };

  getSessionDetail = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const sessionId = this.readSessionId(req.params.sessionId);

    const session = await this.speedDatingService.getSessionDetail(userId, sessionId);

    res.status(200).json({
      success: true,
      data: {
        session,
      },
    });
  };

  getSessionMessages = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const sessionId = this.readSessionId(req.params.sessionId);

    const result = await this.speedDatingService.getSessionMessages(userId, sessionId);

    res.status(200).json({
      success: true,
      data: result,
    });
  };

  sendMessage = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const sessionId = this.readSessionId(req.params.sessionId);

    if (typeof req.body?.content !== 'string') {
      badRequest('Message content is required', 'MISSING_MESSAGE_CONTENT');
    }

    const result = await this.speedDatingService.sendMessage(userId, sessionId, req.body.content);

    res.status(201).json({
      success: true,
      data: result,
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

  private readSessionId(value: unknown): string {
    if (typeof value !== 'string' || value.trim().length === 0) {
      badRequest('sessionId is required', 'MISSING_SESSION_ID');
    }

    return value.trim();
  }
}
