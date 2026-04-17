import { Router, Request, Response, NextFunction } from 'express';
import { ReportController } from '../controllers/report-controller';
import { ReportService } from '../services/report-service';
import { ReportRepository } from '../repositories/report-repository';
import { UserRepository } from '../repositories/user-repository';
import { authenticate } from '../middleware/authenticate';
import { createAuthVerifier } from '../services/auth/auth-verifier';

const authVerifier = createAuthVerifier();
const reportRepository = new ReportRepository();
const userRepository = new UserRepository();
const reportService = new ReportService(reportRepository, userRepository);
const reportController = new ReportController(reportService);

function asyncHandler(
  handler: (req: Request, res: Response, next: NextFunction) => Promise<void>,
) {
  return (req: Request, res: Response, next: NextFunction): void => {
    handler(req, res, next).catch(next);
  };
}

export const reportRouter = Router();

// POST /reports — Submit a report
reportRouter.post(
  '/',
  authenticate(authVerifier),
  asyncHandler(reportController.reportUser),
);

// GET /reports — Get reports submitted by the authenticated user
reportRouter.get(
  '/',
  authenticate(authVerifier),
  asyncHandler(reportController.getUserReports),
);

// GET /reports/user/:userId — Get reports for a specific user (admin endpoint)
reportRouter.get(
  '/user/:userId',
  authenticate(authVerifier),
  asyncHandler(reportController.getReportsForUser),
);

// GET /reports/count/:userId — Get report count for a specific user
reportRouter.get(
  '/count/:userId',
  authenticate(authVerifier),
  asyncHandler(reportController.getReportCountForUser),
);

// GET /reports/all — Get all reports (admin endpoint)
reportRouter.get(
  '/all',
  authenticate(authVerifier),
  asyncHandler(reportController.getAllReports),
);