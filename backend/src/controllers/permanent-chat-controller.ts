import { Request, Response } from 'express';
import { UserRepository } from '../repositories/user-repository';
import { PermanentChatService } from '../services/permanent-chat-service';
import { badRequest, unauthorized } from '../utils/errors';

export class PermanentChatController {
  constructor(
    private readonly permanentChatService: PermanentChatService,
    private readonly userRepository: UserRepository,
  ) {}

  listMatches = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const matches = await this.permanentChatService.listMatches(userId);

    res.status(200).json({
      success: true,
      data: {
        matches,
      },
    });
  };

  getMatchDetail = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const matchId = this.readMatchId(req.params.matchId);
    const match = await this.permanentChatService.getMatchDetail(userId, matchId);

    res.status(200).json({
      success: true,
      data: {
        match,
      },
    });
  };

  getMatchMessages = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const matchId = this.readMatchId(req.params.matchId);
    const result = await this.permanentChatService.getMatchMessages(userId, matchId);

    res.status(200).json({
      success: true,
      data: result,
    });
  };

  markMatchMessagesRead = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const matchId = this.readMatchId(req.params.matchId);
    const match = await this.permanentChatService.markMatchMessagesRead(userId, matchId);

    res.status(200).json({
      success: true,
      data: {
        match,
      },
    });
  };

  sendMessage = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const matchId = this.readMatchId(req.params.matchId);

    if (typeof req.body?.content !== 'string') {
      badRequest('Message content is required', 'MISSING_MESSAGE_CONTENT');
    }

    const result = await this.permanentChatService.sendMessage(userId, matchId, req.body.content);

    res.status(201).json({
      success: true,
      data: result,
    });
  };

  removeMatch = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const matchId = this.readMatchId(req.params.matchId);
    const result = await this.permanentChatService.removeMatch(userId, matchId);

    res.status(200).json({
      success: true,
      data: result,
    });
  };

  blockCounterpart = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const matchId = this.readMatchId(req.params.matchId);
    const result = await this.permanentChatService.blockCounterpart(userId, matchId, req.body?.reason);

    res.status(200).json({
      success: true,
      data: result,
    });
  };

  reportCounterpart = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const matchId = this.readMatchId(req.params.matchId);
    const result = await this.permanentChatService.reportCounterpart(
      userId,
      matchId,
      req.body?.reason,
      req.body?.details,
    );

    res.status(200).json({
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

  private readMatchId(value: unknown): string {
    if (typeof value !== 'string' || value.trim().length === 0) {
      badRequest('matchId is required', 'MISSING_MATCH_ID');
    }

    return value.trim();
  }
}
