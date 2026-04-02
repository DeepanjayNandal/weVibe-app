-- CreateExtension
CREATE EXTENSION IF NOT EXISTS "postgis";

-- CreateEnum
CREATE TYPE "enum_match_status" AS ENUM ('active', 'unmatched', 'reported', 'trial', 'waiting_decision', 'expired');

-- CreateEnum
CREATE TYPE "enum_msg_type" AS ENUM ('text', 'image', 'audio', 'system');

-- CreateEnum
CREATE TYPE "enum_auth_provider" AS ENUM ('google', 'apple', 'facebook', 'twitter', 'email');

-- CreateEnum
CREATE TYPE "enum_user_status" AS ENUM ('active', 'offline', 'in_speed_date', 'banned');

-- CreateEnum
CREATE TYPE "enum_decision" AS ENUM ('pending', 'yes', 'no');

-- CreateEnum
CREATE TYPE "enum_sex" AS ENUM ('male', 'female');

-- CreateEnum
CREATE TYPE "enum_meet_gender" AS ENUM ('men', 'women', 'both');

-- CreateEnum
CREATE TYPE "enum_intent" AS ENUM ('short_term', 'long_term', 'marriage', 'figuring_out');

-- CreateEnum
CREATE TYPE "enum_education" AS ENUM ('high_school', 'in_college', 'bachelors', 'masters', 'phd', 'other');

-- CreateEnum
CREATE TYPE "enum_frequency" AS ENUM ('never', 'sometimes', 'often');

-- CreateEnum
CREATE TYPE "enum_preference_level" AS ENUM ('dont_want', 'unsure', 'want', 'have');

-- CreateEnum
CREATE TYPE "enum_sleep_schedule" AS ENUM ('night_owl', 'early_bird', 'flexible');

-- CreateTable
CREATE TABLE "matches" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_a_id" UUID,
    "user_b_id" UUID,
    "created_at" TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,
    "status" "enum_match_status" DEFAULT 'active',
    "last_message_content" VARCHAR(255),
    "last_message_at" TIMESTAMP(6),
    "expires_at" TIMESTAMP(6),
    "message_count" INTEGER DEFAULT 0,
    "user_a_decision" "enum_decision" DEFAULT 'pending',
    "user_b_decision" "enum_decision" DEFAULT 'pending',

    CONSTRAINT "matches_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "messages" (
    "id" BIGSERIAL NOT NULL,
    "match_id" UUID,
    "sender_id" UUID,
    "content" TEXT NOT NULL,
    "type" "enum_msg_type" DEFAULT 'text',
    "created_at" TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,
    "read_at" TIMESTAMP(6),

    CONSTRAINT "messages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "profiles" (
    "user_id" UUID NOT NULL,
    "first_name" VARCHAR(100),
    "last_name" VARCHAR(100),
    "display_name" VARCHAR(100),
    "birth_date" DATE,
    "gender" VARCHAR(50),
    "sex" "enum_sex",
    "pronouns" VARCHAR(50),
    "orientation" VARCHAR(50),
    "gender_identity" VARCHAR(50),
    "show_sex" BOOLEAN DEFAULT true,
    "show_orientation" BOOLEAN DEFAULT true,
    "show_identity" BOOLEAN DEFAULT true,
    "ethnicity" JSONB,
    "birth_country" VARCHAR(100),
    "height_unit" VARCHAR(10),
    "height_ft" INTEGER,
    "height_in" INTEGER,
    "height_cm" INTEGER,
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "location_point" geography(Point,4326),
    "location_city" VARCHAR(100),
    "state" VARCHAR(100),
    "zip_code" VARCHAR(20),
    "education" VARCHAR(100),
    "career_field" VARCHAR(100),
    "job_title" VARCHAR(100),
    "school" VARCHAR(100),
    "languages" JSONB,
    "relationship_goals" JSONB,
    "relationship_intent" "enum_intent",
    "personality_primary" VARCHAR(100),
    "personality_secondary" VARCHAR(100),
    "lifestyle_drinks" VARCHAR(20),
    "lifestyle_smoking" VARCHAR(20),
    "lifestyle_workout" VARCHAR(20),
    "lifestyle_pets" VARCHAR(20),
    "lifestyle_children" VARCHAR(20),
    "lifestyle_sleep" VARCHAR(20),
    "lifestyle_cannabis" VARCHAR(20),
    "pet_types" VARCHAR(100),
    "pets_name" VARCHAR(100),
    "is_drinks_flexible" BOOLEAN DEFAULT false,
    "is_smoking_flexible" BOOLEAN DEFAULT false,
    "is_workout_flexible" BOOLEAN DEFAULT false,
    "is_sleep_flexible" BOOLEAN DEFAULT false,
    "is_cannabis_flexible" BOOLEAN DEFAULT false,
    "is_kids_flexible" BOOLEAN DEFAULT false,
    "bio" VARCHAR(500),
    "instagram_handle" VARCHAR(100),
    "tiktok_handle" VARCHAR(100),
    "spotify_playlist_url" VARCHAR(500),
    "love_language" VARCHAR(50),
    "zodiac_sign" VARCHAR(20),
    "communication_style" VARCHAR(50),
    "conflict_style" VARCHAR(50),
    "personality_type" VARCHAR(100),
    "interests" JSONB,
    "preferred_date_activities" JSONB,
    "would_not_do_activities" JSONB,
    "prompts" JSONB,
    "photos" JSONB,
    "social_integrations" JSONB,
    "likes_received_count" INTEGER DEFAULT 0,
    "meet_preference" VARCHAR(20),
    "min_age_preference" INTEGER,
    "max_age_preference" INTEGER,
    "distance_preference_miles" INTEGER,

    CONSTRAINT "profiles_pkey" PRIMARY KEY ("user_id")
);

-- CreateTable
CREATE TABLE "speed_dating_sessions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_a_id" UUID,
    "user_b_id" UUID,
    "started_at" TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,
    "expires_at" TIMESTAMP(6),
    "status" VARCHAR(50),
    "user_a_decision" "enum_decision" DEFAULT 'pending',
    "user_b_decision" "enum_decision" DEFAULT 'pending',

    CONSTRAINT "speed_dating_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "speed_dating_messages" (
    "id" BIGSERIAL NOT NULL,
    "session_id" UUID,
    "sender_id" UUID,
    "content" TEXT NOT NULL,
    "type" "enum_msg_type" DEFAULT 'text',
    "created_at" TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,
    "read_at" TIMESTAMP(6),

    CONSTRAINT "speed_dating_messages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "matching_queue" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "joined_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "matching_queue_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_blocks" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "blocker_user_id" UUID NOT NULL,
    "blocked_user_id" UUID NOT NULL,
    "reason" VARCHAR(255),
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_blocks_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "email" VARCHAR(255) NOT NULL,
    "firebase_uid" VARCHAR(255) NOT NULL,
    "auth_provider" "enum_auth_provider" DEFAULT 'email',
    "phone" VARCHAR(50),
    "password_hash" VARCHAR(255),
    "created_at" TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,
    "last_active_at" TIMESTAMP(6),
    "is_banned" BOOLEAN DEFAULT false,
    "deleted_at" TIMESTAMP(6),
    "onboarding_complete" BOOLEAN DEFAULT false,
    "is_registration_complete" BOOLEAN DEFAULT false,
    "is_personality_test_complete" BOOLEAN DEFAULT false,
    "current_status" "enum_user_status" DEFAULT 'offline',
    "search_radius_km" INTEGER DEFAULT 50,
    "search_age_min" INTEGER DEFAULT 18,
    "search_age_max" INTEGER DEFAULT 35,
    "search_gender" "enum_meet_gender" DEFAULT 'both',
    "preferences" JSONB,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_reports" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "reporter_user_id" UUID NOT NULL,
    "reported_user_id" UUID NOT NULL,
    "match_id" UUID,
    "reason" VARCHAR(255) NOT NULL,
    "details" VARCHAR(1000),
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_reports_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "idx_matches_user_a" ON "matches"("user_a_id", "last_message_at");

-- CreateIndex
CREATE INDEX "idx_matches_user_b" ON "matches"("user_b_id", "last_message_at");

-- CreateIndex
CREATE INDEX "idx_messages_match_id" ON "messages"("match_id", "created_at");

-- CreateIndex
CREATE INDEX "idx_profiles_location" ON "profiles" USING GIST ("location_point");

-- CreateIndex
CREATE INDEX "idx_profiles_personality" ON "profiles"("gender", "personality_primary");

-- CreateIndex
CREATE INDEX "idx_sd_messages_session_id" ON "speed_dating_messages"("session_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "matching_queue_user_id_key" ON "matching_queue"("user_id");

-- CreateIndex
CREATE INDEX "idx_matching_queue_joined_at" ON "matching_queue"("joined_at");

-- CreateIndex
CREATE INDEX "idx_user_blocks_blocker" ON "user_blocks"("blocker_user_id");

-- CreateIndex
CREATE INDEX "idx_user_blocks_blocked" ON "user_blocks"("blocked_user_id");

-- CreateIndex
CREATE UNIQUE INDEX "uq_user_blocks_pair" ON "user_blocks"("blocker_user_id", "blocked_user_id");

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "users_firebase_uid_key" ON "users"("firebase_uid");

-- CreateIndex
CREATE UNIQUE INDEX "users_phone_key" ON "users"("phone");

-- CreateIndex
CREATE INDEX "idx_user_reports_reporter" ON "user_reports"("reporter_user_id");

-- CreateIndex
CREATE INDEX "idx_user_reports_reported" ON "user_reports"("reported_user_id");

-- CreateIndex
CREATE INDEX "idx_user_reports_match" ON "user_reports"("match_id");

-- AddForeignKey
ALTER TABLE "matches" ADD CONSTRAINT "matches_user_a_id_fkey" FOREIGN KEY ("user_a_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "matches" ADD CONSTRAINT "matches_user_b_id_fkey" FOREIGN KEY ("user_b_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "messages" ADD CONSTRAINT "messages_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "matches"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "messages" ADD CONSTRAINT "messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "profiles" ADD CONSTRAINT "profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "speed_dating_sessions" ADD CONSTRAINT "speed_dating_sessions_user_a_id_fkey" FOREIGN KEY ("user_a_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "speed_dating_sessions" ADD CONSTRAINT "speed_dating_sessions_user_b_id_fkey" FOREIGN KEY ("user_b_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "speed_dating_messages" ADD CONSTRAINT "speed_dating_messages_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "speed_dating_sessions"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "speed_dating_messages" ADD CONSTRAINT "speed_dating_messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "matching_queue" ADD CONSTRAINT "matching_queue_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "user_blocks" ADD CONSTRAINT "user_blocks_blocked_user_id_fkey" FOREIGN KEY ("blocked_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "user_blocks" ADD CONSTRAINT "user_blocks_blocker_user_id_fkey" FOREIGN KEY ("blocker_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "user_reports" ADD CONSTRAINT "user_reports_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "matches"("id") ON DELETE SET NULL ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "user_reports" ADD CONSTRAINT "user_reports_reported_user_id_fkey" FOREIGN KEY ("reported_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "user_reports" ADD CONSTRAINT "user_reports_reporter_user_id_fkey" FOREIGN KEY ("reporter_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;
