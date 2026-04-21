-- Bio generation rate limiting fields on profiles
-- bio_last_generated_at: timestamp of most recent generation — enforces 60s cooldown
-- bio_daily_count: number of generations today — enforced against DAILY_LIMIT (5)
-- bio_daily_reset_date: YYYY-MM-DD of the day the count was last reset
ALTER TABLE "profiles" ADD COLUMN "bio_last_generated_at" TIMESTAMP(6);
ALTER TABLE "profiles" ADD COLUMN "bio_daily_count" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "profiles" ADD COLUMN "bio_daily_reset_date" VARCHAR(10);
