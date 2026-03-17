-- ==========================================================
-- WeVibe Complete Database Schema
-- Features: Strict Enums, No Swipes, 24h Icebreaker Challenge, Double Opt-in
-- Location: schema.sql
-- ==========================================================

-- 1. Clean up existing tables and types (For a fresh start)
-- Order matters due to Foreign Key constraints
DROP TABLE IF EXISTS user_blocks, matching_queue, speed_dating_messages, speed_dating_sessions, messages, matches, profiles, users CASCADE;
DROP TYPE IF EXISTS enum_decision, enum_match_status, enum_sex, enum_meet_gender, enum_intent, enum_education, enum_frequency, enum_preference_level, enum_sleep_schedule, enum_user_status, enum_auth_provider, enum_msg_type CASCADE;

-- 2. Enable PostGIS Extension (Critical for spatial queries/distance matching)
CREATE EXTENSION IF NOT EXISTS postgis;

-- 3. Define Custom Enumerated Types (Strict Enums)
CREATE TYPE enum_decision AS ENUM ('pending', 'yes', 'no');
CREATE TYPE enum_match_status AS ENUM ('trial', 'waiting_decision', 'active', 'expired', 'unmatched', 'reported');
CREATE TYPE enum_sex AS ENUM ('male', 'female');
CREATE TYPE enum_meet_gender AS ENUM ('men', 'women', 'both');
CREATE TYPE enum_intent AS ENUM ('short_term', 'long_term', 'marriage', 'figuring_out');
CREATE TYPE enum_education AS ENUM ('high_school', 'in_college', 'bachelors', 'masters', 'phd', 'other');
CREATE TYPE enum_frequency AS ENUM ('never', 'sometimes', 'often');
CREATE TYPE enum_preference_level AS ENUM ('dont_want', 'unsure', 'want', 'have');
CREATE TYPE enum_sleep_schedule AS ENUM ('night_owl', 'early_bird', 'flexible');
CREATE TYPE enum_user_status AS ENUM ('active', 'offline', 'in_speed_date', 'banned');
CREATE TYPE enum_auth_provider AS ENUM ('email', 'google', 'apple', 'facebook');
CREATE TYPE enum_msg_type AS ENUM ('text', 'image', 'audio', 'system');

-- ==========================================================
-- Core Account & Profile Modules
-- ==========================================================

-- 4. Users Table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid VARCHAR(255) UNIQUE, -- Populated after Firebase Auth linking
    auth_provider enum_auth_provider NOT NULL DEFAULT 'email',
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(50) UNIQUE,
    password_hash VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_active_at TIMESTAMP,
    
    -- Status Management
    is_banned BOOLEAN DEFAULT FALSE,
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
    
    -- Core Demographics
    display_name VARCHAR(100),
    birth_date DATE,
    gender VARCHAR(50), -- Gender identity
    sex enum_sex, -- Biological sex
    ethnicity VARCHAR(100), -- e.g., White, Asian, Hispanic, Black, Pacific Islander
    height_cm INT, -- Stored in cm to maintain a standard unit
    
    -- Location
    location_point GEOGRAPHY(Point, 4326), -- PostGIS Latitude/Longitude
    state VARCHAR(100),
    zip_code VARCHAR(20),

    -- Background
    education enum_education,
    career_field VARCHAR(100),
    languages JSONB, -- Array: ["English", "Mandarin", "Spanish"]

    -- Intent & Personality
    relationship_intent enum_intent,
    personality_primary VARCHAR(100), -- Primary Soul Archetype
    personality_secondary VARCHAR(100), -- Secondary Soul Archetype

    -- Lifestyle & Habits (Strict Enums)
    lifestyle_drinks enum_frequency,
    lifestyle_smoking enum_frequency,
    lifestyle_workout enum_frequency,
    lifestyle_pets enum_preference_level,
    lifestyle_children enum_preference_level,
    lifestyle_sleep enum_sleep_schedule,

    -- Prompts & Media
    prompts JSONB, -- Array of objects: [{"question": "...", "answer": "..."}]
    photos JSONB, -- Array of Image URLs
    social_integrations JSONB, -- Spotify, Instagram links etc.
    
    likes_received_count INT DEFAULT 0
);

-- ==========================================================
-- Icebreaker & Match Module (24h / 20 Messages)
-- ==========================================================

-- 6. Matches Table
CREATE TABLE matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_a_id UUID REFERENCES users(id) ON DELETE CASCADE,
    user_b_id UUID REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- 24h Icebreaker Challenge
    expires_at TIMESTAMP, -- Set to created_at + 24 hours in application logic
    message_count INT DEFAULT 0, -- Increments on each message. Target: 20
    
    -- Double Opt-in Decision
    user_a_decision enum_decision DEFAULT 'pending',
    user_b_decision enum_decision DEFAULT 'pending',
    
    status enum_match_status DEFAULT 'trial',
    
    -- Chat List Optimization
    last_message_content VARCHAR(255),
    last_message_at TIMESTAMP
);

-- 7. Messages Table
CREATE TABLE messages (
    id BIGSERIAL PRIMARY KEY,
    match_id UUID REFERENCES matches(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    type enum_msg_type DEFAULT 'text',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    read_at TIMESTAMP
);

-- ==========================================================
-- 3-Minute Speed Dating Module
-- ==========================================================

-- 8. Speed Dating Sessions Table
CREATE TABLE speed_dating_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_a_id UUID REFERENCES users(id) ON DELETE CASCADE,
    user_b_id UUID REFERENCES users(id) ON DELETE CASCADE,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP, -- Set to started_at + 3 minutes in application logic
    
    -- Double Opt-in Decision
    user_a_decision enum_decision DEFAULT 'pending',
    user_b_decision enum_decision DEFAULT 'pending',
    
    status VARCHAR(50) -- 'active', 'waiting_decision', 'matched', 'closed'
);

-- 9. Speed Dating Messages Table
CREATE TABLE speed_dating_messages (
    id BIGSERIAL PRIMARY KEY,
    session_id UUID REFERENCES speed_dating_sessions(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    type enum_msg_type DEFAULT 'text',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    read_at TIMESTAMP
    -- Temporary messages during the 3-minute blind date
);

-- 10. Matching Queue Table
CREATE TABLE matching_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 11. User Pair Block Table
CREATE TABLE user_blocks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blocker_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    blocked_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    reason VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_user_blocks_pair UNIQUE (blocker_user_id, blocked_user_id)
);

-- ==========================================================
-- Performance Indexes
-- ==========================================================

CREATE INDEX idx_profiles_location ON profiles USING GIST (location_point);
CREATE INDEX idx_profiles_personality ON profiles (gender, personality_primary);
CREATE INDEX idx_matches_user_a ON matches (user_a_id, last_message_at);
CREATE INDEX idx_matches_user_b ON matches (user_b_id, last_message_at);
CREATE INDEX idx_messages_match_id ON messages (match_id, created_at);
CREATE INDEX idx_sd_messages_session_id ON speed_dating_messages (session_id, created_at);
CREATE INDEX idx_matching_queue_joined_at ON matching_queue (joined_at);
CREATE INDEX idx_user_blocks_blocker ON user_blocks (blocker_user_id);
CREATE INDEX idx_user_blocks_blocked ON user_blocks (blocked_user_id);