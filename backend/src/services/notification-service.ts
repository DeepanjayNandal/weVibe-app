import * as admin from 'firebase-admin';
import { prisma } from '../db/prisma-client';

export type PushData = Record<string, string>;

export class NotificationService {
  /**
   * Sends a Firebase Cloud Messaging push notification to a user.
   * Looks up the user's FCM token from the database.
   *
   * - No-op if Firebase Admin is not initialised (mock/test mode).
   * - No-op if the user has no FCM token stored.
   * - Clears stale tokens automatically on token-not-registered errors.
   * - Never throws — push failure must never fail the calling request.
   */
  async sendPushToUser(
    userId: string,
    title: string,
    body: string,
    data?: PushData,
    threadId?: string,
  ): Promise<void> {
    if (admin.apps.length === 0) return;

    const user = await prisma.users.findUnique({
      where: { id: userId },
      select: { fcm_token: true },
    });

    const token = user?.fcm_token;
    if (!token) return;

    try {
      await admin.messaging().send({
        token,
        notification: { title, body },
        ...(data ? { data } : {}),
        apns: {
          ...(threadId ? { headers: { 'apns-collapse-id': threadId } } : {}),
          payload: {
            aps: {
              alert: { title, body },
              sound: 'default',
              ...(threadId ? { threadId } : {}),
            },
          },
        },
      });
    } catch (error: unknown) {
      const isStaleToken =
        error instanceof Error &&
        'code' in error &&
        (error as { code: string }).code === 'messaging/registration-token-not-registered';

      if (isStaleToken) {
        await prisma.users.update({
          where: { id: userId },
          data: { fcm_token: null },
        }).catch(() => {
          // Best-effort token cleanup — ignore secondary failures
        });
      }

      console.error('[notification] FCM send failed for user', userId, error);
    }
  }
}

export const notificationService = new NotificationService();
