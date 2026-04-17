import { Request, Response } from 'express';
import { ReportService } from '../services/report-service';
import { badRequest } from '../utils/errors';

export class ReportController {
  constructor(private readonly reportService: ReportService) {}

  reportUser = async (req: Request, res: Response): Promise<void> => {
    const firebaseUid = req.auth!.uid;
    const { reportedUserId, reason, details, matchId } = req.body ?? {};

    // Validate required fields
    if (!reportedUserId || typeof reportedUserId !== 'string') {
      badRequest('reportedUserId is required and must be a string', 'INVALID_REPORTED_USER_ID');
    }

    if (!reason || typeof reason !== 'string') {
      badRequest('reason is required and must be a string', 'INVALID_REPORT_REASON');
    }

    // Validate optional fields
    if (details && typeof details !== 'string') {
      badRequest('details must be a string if provided', 'INVALID_REPORT_DETAILS');
    }

    if (matchId && typeof matchId !== 'string') {
      badRequest('matchId must be a string if provided', 'INVALID_MATCH_ID');
    }

    await this.reportService.reportUser(firebaseUid, reportedUserId, reason, details, matchId);

    res.status(201).json({
      success: true,
      message: 'Report submitted successfully',
    });
  };

  getUserReports = async (req: Request, res: Response): Promise<void> => {
    const firebaseUid = req.auth!.uid;

    const reports = await this.reportService.getUserReports(firebaseUid);

    res.status(200).json({
      success: true,
      data: reports,
    });
  };

  getReportsForUser = async (req: Request, res: Response): Promise<void> => {
    const { userId } = req.params;

    if (!userId || typeof userId !== 'string') {
      badRequest('userId parameter is required', 'INVALID_USER_ID');
    }

    const reports = await this.reportService.getReportsForUser(userId);

    res.status(200).json({
      success: true,
      data: reports,
    });
  };

  getAllReports = async (req: Request, res: Response): Promise<void> => {
    // TODO: Add admin authentication check here
    const reports = await this.reportService.getAllReports();

    res.status(200).json({
      success: true,
      data: reports,
    });
  };

  getReportCountForUser = async (req: Request, res: Response): Promise<void> => {
    const { userId } = req.params;

    if (!userId || typeof userId !== 'string') {
      badRequest('userId parameter is required', 'INVALID_USER_ID');
    }

    const count = await this.reportService.getReportCountForUser(userId);

    res.status(200).json({
      success: true,
      data: { count },
    });
  };
}