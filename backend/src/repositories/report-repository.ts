import { user_reports } from '@prisma/client';
import { prisma } from '../db/prisma-client';

export interface CreateReportData {
  reporterUserId: string;
  reportedUserId: string;
  matchId?: string;
  reason: string;
  details?: string;
}

export class ReportRepository {
  async create(data: CreateReportData): Promise<user_reports> {
    return prisma.user_reports.create({
      data: {
        reporter_user_id: data.reporterUserId,
        reported_user_id: data.reportedUserId,
        match_id: data.matchId || null,
        reason: data.reason,
        details: data.details || null,
      },
    });
  }

  async findById(id: string): Promise<user_reports | null> {
    return prisma.user_reports.findUnique({
      where: { id },
      include: {
        users_user_reports_reporter: {
          select: {
            id: true,
            email: true,
          },
        },
        users_user_reports_reported: {
          select: {
            id: true,
            email: true,
          },
        },
        matches: true,
      },
    });
  }

  async findByReporterUserId(reporterUserId: string): Promise<user_reports[]> {
    return prisma.user_reports.findMany({
      where: { reporter_user_id: reporterUserId },
      include: {
        users_user_reports_reported: {
          select: {
            id: true,
            email: true,
          },
        },
        matches: true,
      },
      orderBy: { created_at: 'desc' },
    });
  }

  async findByReportedUserId(reportedUserId: string): Promise<user_reports[]> {
    return prisma.user_reports.findMany({
      where: { reported_user_id: reportedUserId },
      include: {
        users_user_reports_reporter: {
          select: {
            id: true,
            email: true,
          },
        },
        matches: true,
      },
      orderBy: { created_at: 'desc' },
    });
  }

  async findAll(): Promise<user_reports[]> {
    return prisma.user_reports.findMany({
      include: {
        users_user_reports_reporter: {
          select: {
            id: true,
            email: true,
          },
        },
        users_user_reports_reported: {
          select: {
            id: true,
            email: true,
          },
        },
        matches: true,
      },
      orderBy: { created_at: 'desc' },
    });
  }

  async countByReportedUserId(reportedUserId: string): Promise<number> {
    return prisma.user_reports.count({
      where: { reported_user_id: reportedUserId },
    });
  }

  async hasUserReportedMatch(reporterUserId: string, matchId: string): Promise<boolean> {
    const count = await prisma.user_reports.count({
      where: {
        reporter_user_id: reporterUserId,
        match_id: matchId,
      },
    });
    return count > 0;
  }
}