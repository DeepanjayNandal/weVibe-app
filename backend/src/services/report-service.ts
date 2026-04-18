import { UserRepository } from '../repositories/user-repository';
import { ReportRepository, CreateReportData } from '../repositories/report-repository';
import { badRequest, notFound, forbidden } from '../utils/errors';

export class ReportService {
  constructor(
    private readonly reportRepository: ReportRepository,
    private readonly userRepository: UserRepository,
  ) {}

  async reportUser(
    reporterFirebaseUid: string,
    reportedUserId: string,
    reason: string,
    details?: string,
    matchId?: string,
  ): Promise<void> {
    // Validate reporter exists
    const reporter = await this.userRepository.findByFirebaseUid(reporterFirebaseUid);
    if (!reporter) {
      notFound('Reporter user not found', 'REPORTER_NOT_FOUND');
    }

    // Validate reported user exists
    const reportedUser = await this.userRepository.findById(reportedUserId);
    if (!reportedUser) {
      notFound('Reported user not found', 'REPORTED_USER_NOT_FOUND');
    }

    // Prevent self-reporting
    if (reporter.id === reportedUserId) {
      badRequest('Users cannot report themselves', 'SELF_REPORT_NOT_ALLOWED');
    }

    // If matchId is provided, validate it exists and involves both users
    if (matchId) {
      const hasReportedMatch = await this.reportRepository.hasUserReportedMatch(reporter.id, matchId);
      if (hasReportedMatch) {
        badRequest('You have already reported this match', 'DUPLICATE_REPORT');
      }
    }

    // Validate reason
    const validReasons = [
      'inappropriate_content',
      'harassment',
      'spam',
      'fake_profile',
      'underage',
      'scam',
      'hate_speech',
      'violence',
      'other',
    ];

    if (!validReasons.includes(reason)) {
      badRequest('Invalid report reason', 'INVALID_REPORT_REASON');
    }

    // Create the report
    const reportData: CreateReportData = {
      reporterUserId: reporter.id,
      reportedUserId,
      reason,
      details,
      matchId,
    };

    await this.reportRepository.create(reportData);
  }

  async getUserReports(reporterFirebaseUid: string) {
    const reporter = await this.userRepository.findByFirebaseUid(reporterFirebaseUid);
    if (!reporter) {
      notFound('User not found', 'USER_NOT_FOUND');
    }

    return this.reportRepository.findByReporterUserId(reporter.id);
  }

  async getReportsForUser(reportedUserId: string) {
    // This could be admin-only in the future
    return this.reportRepository.findByReportedUserId(reportedUserId);
  }

  async getAllReports() {
    // This should be admin-only
    return this.reportRepository.findAll();
  }

  async getReportCountForUser(reportedUserId: string): Promise<number> {
    return this.reportRepository.countByReportedUserId(reportedUserId);
  }
}