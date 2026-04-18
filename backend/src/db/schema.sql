-- ==========================================================
-- WeVibe Complete Database Schema
-- Features: Strict Enums, No Swipes, 24h Icebreaker Challenge, Double Opt-in
-- Location: schema.sql
-- ==========================================================

-- 1. Clean up existing tables and types (For a fresh start)
-- Order matters due to Foreign Key constraints
DROP TABLE IF EXISTS photo_upload_pending, user_reports, user_blocks, matching_queue, speed_dating_messages, speed_dating_sessions, messages, matches, profiles, users CASCADE;
DROP TYPE IF EXISTS enum_decision, enum_match_status, enum_sex, enum_meet_gender, enum_intent, enum_user_status, enum_auth_provider, enum_msg_type CASCADE;

-- 2. Enable Required Extensions (UUID + spatial queries/distance matching)
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS postgis;

-- 3. Define Custom Enumerated Types (Strict Enums)
CREATE TYPE enum_decision AS ENUM ('pending', 'yes', 'no');
CREATE TYPE enum_match_status AS ENUM ('trial', 'waiting_decision', 'active', 'expired', 'unmatched', 'reported');
CREATE TYPE enum_sex AS ENUM ('male', 'female');
CREATE TYPE enum_meet_gender AS ENUM ('men', 'women', 'both');
CREATE TYPE enum_intent AS ENUM ('short_term', 'long_term', 'marriage', 'figuring_out');
CREATE TYPE enum_user_status AS ENUM ('active', 'offline', 'in_speed_date', 'banned');
CREATE TYPE enum_auth_provider AS ENUM ('email', 'google', 'apple', 'facebook', 'twitter');
CREATE TYPE enum_msg_type AS ENUM ('text', 'image', 'audio', 'system');

-- ==========================================================
-- Core Account & Profile Modules
-- ==========================================================

-- 4. Users Table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid VARCHAR(255) UNIQUE NOT NULL, -- Populated after Firebase Auth linking
    auth_provider enum_auth_provider NOT NULL DEFAULT 'email',
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(50) UNIQUE,
    password_hash VARCHAR(255),
    created_at TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,
    last_active_at TIMESTAMP(6),
    
    -- Status Management
    is_banned BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP(6),
    onboarding_complete BOOLEAN DEFAULT FALSE,
    is_registration_complete BOOLEAN DEFAULT FALSE,
    is_personality_test_complete BOOLEAN DEFAULT FALSE,
    current_status enum_user_status DEFAULT 'offline',

    -- Search Preferences
    search_radius_km INT DEFAULT 50,
    search_age_min INT DEFAULT 18,
    search_age_max INT DEFAULT 35,
    search_gender enum_meet_gender DEFAULT 'both',
    
    -- Flexible storage for other specific preferences
    preferences JSONB 
);

-- 5. Profiles Table
CREATE TABLE profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    
    -- Basic identity
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    display_name VARCHAR(100),
    nickname VARCHAR(50),
    birth_date DATE,
    gender VARCHAR(50),
    sex enum_sex,
    pronouns VARCHAR(50),
    orientation VARCHAR(50),
    gender_identity VARCHAR(50),

    -- Visibility toggles
    show_sex BOOLEAN DEFAULT TRUE,
    show_orientation BOOLEAN DEFAULT TRUE,
    show_identity BOOLEAN DEFAULT TRUE,
    show_personality_trait BOOLEAN DEFAULT TRUE,

    -- Demographics and location
    ethnicity JSONB,
    birth_country VARCHAR(100),
    height_unit VARCHAR(10),
    height_ft INT,
    height_in INT,
    height_cm INT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    location_point GEOGRAPHY(Point, 4326), -- PostGIS Latitude/Longitude
    location_city VARCHAR(100),
    state VARCHAR(100),
    zip_code VARCHAR(20),

    -- Background
    education VARCHAR(100),
    career_field VARCHAR(100),
    job_title VARCHAR(100),
    school VARCHAR(100),
    languages JSONB,

    -- Intent & Personality
    relationship_goals JSONB,
    relationship_intent enum_intent,
    personality_primary VARCHAR(100),
    personality_secondary VARCHAR(100),

    -- Lifestyle & Habits
    lifestyle_drinks VARCHAR(20),
    lifestyle_smoking VARCHAR(20),
    lifestyle_workout VARCHAR(20),
    lifestyle_pets VARCHAR(20),
    lifestyle_children VARCHAR(20),
    lifestyle_sleep VARCHAR(20),
    lifestyle_cannabis VARCHAR(20),
    pet_types VARCHAR(100),
    pets_name VARCHAR(100),
    is_drinks_flexible BOOLEAN DEFAULT FALSE,
    is_smoking_flexible BOOLEAN DEFAULT FALSE,
    is_workout_flexible BOOLEAN DEFAULT FALSE,
    is_sleep_flexible BOOLEAN DEFAULT FALSE,
    is_cannabis_flexible BOOLEAN DEFAULT FALSE,
    is_kids_flexible BOOLEAN DEFAULT FALSE,

    -- Profile content
    bio VARCHAR(500),
    instagram_handle VARCHAR(100),
    tiktok_handle VARCHAR(100),
    spotify_playlist_url VARCHAR(500),
    love_language VARCHAR(50),
    zodiac_sign VARCHAR(20),
    communication_style VARCHAR(50),
    conflict_style VARCHAR(50),
    personality_type VARCHAR(100),
    interests JSONB,
    preferred_date_activities JSONB,
    would_not_do_activities JSONB,
    prompts JSONB,
    photos JSONB,
    social_integrations JSONB,
    likes_received_count INT DEFAULT 0,

    -- User preferences
    meet_preference VARCHAR(20),
    min_age_preference INT,
    max_age_preference INT,
    distance_preference_miles INT
);

-- ==========================================================
-- Icebreaker & Match Module (24h / 20 Messages)
-- ==========================================================

-- 6. Matches Table
CREATE TABLE matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_a_id UUID REFERENCES users(id) ON DELETE CASCADE,
    user_b_id UUID REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,
    
    -- 24h Icebreaker Challenge
    expires_at TIMESTAMP(6), -- Set to created_at + 24 hours in application logic
    message_count INT DEFAULT 0, -- Increments on each message. Target: 20
    
    -- Double Opt-in Decision
    user_a_decision enum_decision DEFAULT 'pending',
    user_b_decision enum_decision DEFAULT 'pending',
    
    status enum_match_status DEFAULT 'active',
    
    -- Chat List Optimization
    last_message_content VARCHAR(255),
    last_message_at TIMESTAMP(6)
);

-- 7. Messages Table
CREATE TABLE messages (
    id BIGSERIAL PRIMARY KEY,
    match_id UUID REFERENCES matches(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    type enum_msg_type DEFAULT 'text',
    created_at TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,
    read_at TIMESTAMP(6)
);

-- ==========================================================
-- 3-Minute Speed Dating Module
-- ==========================================================

-- 8. Speed Dating Sessions Table
CREATE TABLE speed_dating_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_a_id UUID REFERENCES users(id) ON DELETE CASCADE,
    user_b_id UUID REFERENCES users(id) ON DELETE CASCADE,
    started_at TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP(6), -- Set to started_at + 3 minutes in application logic

    -- Double Opt-in Decision
    user_a_decision enum_decision DEFAULT 'pending',
    user_b_decision enum_decision DEFAULT 'pending',

    status VARCHAR(50), -- 'active', 'awaiting_decision', 'graduated', 'archived', 'archived_mismatch', 'ended_early', 'expired', plus counter/locked variants

    -- Audit: which participant manually ended the session (only set for ended_early)
    ended_by_user_id UUID
);

-- 9. Speed Dating Messages Table
CREATE TABLE speed_dating_messages (
    id BIGSERIAL PRIMARY KEY,
    session_id UUID REFERENCES speed_dating_sessions(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    type enum_msg_type DEFAULT 'text',
    created_at TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,
    read_at TIMESTAMP(6)
    -- Temporary messages during the 3-minute blind date
);

-- 10. Matching Queue Table
CREATE TABLE matching_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    joined_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 11. User Pair Block Table
CREATE TABLE user_blocks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blocker_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    blocked_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reason VARCHAR(255),
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_user_blocks_pair UNIQUE (blocker_user_id, blocked_user_id)
);

-- 12. Photo Upload Pending Table
CREATE TABLE photo_upload_pending (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    photo_id VARCHAR(100) UNIQUE NOT NULL,
    storage_path VARCHAR(500) NOT NULL,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 13. User Report Table
CREATE TABLE user_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reported_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    match_id UUID REFERENCES matches(id) ON DELETE SET NULL,
    reason VARCHAR(255) NOT NULL,
    details VARCHAR(1000),
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ==========================================================
-- Performance Indexes
-- ==========================================================

CREATE INDEX idx_profiles_location ON profiles USING GIST (location_point);
CREATE INDEX idx_profiles_personality ON profiles (gender, personality_primary);
CREATE INDEX idx_users_deleted_at ON users (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX idx_matches_user_a ON matches (user_a_id, last_message_at);
CREATE INDEX idx_matches_user_b ON matches (user_b_id, last_message_at);
CREATE INDEX idx_messages_match_id ON messages (match_id, created_at);
CREATE INDEX idx_sd_messages_session_id ON speed_dating_messages (session_id, created_at);
CREATE INDEX idx_matching_queue_joined_at ON matching_queue (joined_at);
CREATE INDEX idx_user_blocks_blocker ON user_blocks (blocker_user_id);
CREATE INDEX idx_user_blocks_blocked ON user_blocks (blocked_user_id);
CREATE INDEX idx_photo_upload_pending_created_at ON photo_upload_pending (created_at);
CREATE INDEX idx_user_reports_reporter ON user_reports (reporter_user_id);
CREATE INDEX idx_user_reports_reported ON user_reports (reported_user_id);
CREATE INDEX idx_user_reports_match ON user_reports (match_id);