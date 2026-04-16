-- AlterTable: add FCM device token for push notifications (nullable, cleared on 404 from FCM)
ALTER TABLE "users" ADD COLUMN "fcm_token" VARCHAR(500);

-- AlterTable: store Apple refresh token to support Sign-in-with-Apple revocation on account deletion
-- Required by App Store Review Guideline 5.1.1. Set on first Apple Sign-In, cleared after revocation.
ALTER TABLE "users" ADD COLUMN "apple_refresh_token" VARCHAR(2000);
