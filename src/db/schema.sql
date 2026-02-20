-- ==========================================================
-- WeVibe Complete Database Schema
-- Location: schema.sql
-- ==========================================================

-- 1. Clean up existing tables and types (For a fresh start)
-- Order matters due to Foreign Key constraints
DROP TABLE IF EXISTS speed_dating_sessions, messages, matches, swipes, profiles, users CASCADE;
DROP TYPE IF EXISTS enum_auth_provider, enum_user_status, enum_swipe_action, enum_match_status, enum_msg_type CASCADE;

-- 2. Enable PostGIS Extension (Critical for distance-based matching)
CREATE EXTENSION IF NOT EXISTS postgis;

-- 3. Define Custom Enumerated Types
CREATE TYPE enum_user_status AS ENUM ('active', 'offline', 'in_speed_date', 'banned');
CREATE TYPE enum_auth_provider AS ENUM ('google', 'apple', 'password');
CREATE TYPE enum_swipe_action AS ENUM ('like', 'pass', 'super_like');
CREATE TYPE enum_match_status AS ENUM ('active', 'unmatched', 'reported');
CREATE TYPE enum_msg_type AS ENUM ('text', 'image', 'audio', 'system');

-- 4. Users Table (Core Account Data)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(50) UNIQUE,
    password_hash VARCHAR(255),
    firebase_uid VARCHAR(128) UNIQUE,
    auth_provider enum_auth_provider,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_active_at TIMESTAMP,
    
    -- Status Management
    is_banned BOOLEAN DEFAULT FALSE,
    current_status enum_user_status DEFAULT 'offline',

    -- Match Preferences (Figma: "Do you want a partner that...?")
    -- Stores: { "accepts_smoker": bool, "accepts_pets": bool, "age_min": int, "age_max": int }
    search_radius_km INT DEFAULT 50,
    search_age_min INT DEFAULT 18,
    search_age_max INT DEFAULT 35,
    preferences JSONB
);

-- 5. Profiles Table (Figma: User Bio, Personality, and Habits)
CREATE TABLE profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    display_name VARCHAR(100),
    birth_date DATE,
    gender VARCHAR(50),
    
    -- Geospatial location for matching
    location_point GEOGRAPHY(Point, 4326),
    
    -- Soul Archetypes (Figma: Personality Test Results)
    personality_primary VARCHAR(100),   -- e.g., 'Serene Soul'
    personality_secondary VARCHAR(100), -- e.g., 'Empathetic Companion'

    -- Flexible Metadata
    -- details: { "zodiac": "Leo", "love_language": "Physical Touch", "communication": "Big Texter" }
    details JSONB,
    
    -- Tags: ["Hiking", "Coffee"]
    tags JSONB,
    
    -- Dealbreakers (Figma: "Activities you would NOT do")
    negative_tags JSONB,
    
    -- Media and Links
    photos JSONB, -- Array of image URLs
    social_integrations JSONB, -- Spotify/Instagram links
    
    -- Denormalized stats for algorithm weighting
    likes_received_count INT DEFAULT 0
);

-- 6. Swipes Table (Interaction History)
CREATE TABLE swipes (
    id BIGSERIAL PRIMARY KEY,
    actor_id UUID REFERENCES users(id) ON DELETE CASCADE,
    target_id UUID REFERENCES users(id) ON DELETE CASCADE,
    action enum_swipe_action NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Prevent swiping the same person twice
    UNIQUE(actor_id, target_id)
);

-- 7. Matches Table (Active Connections)
CREATE TABLE matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_a_id UUID REFERENCES users(id) ON DELETE CASCADE,
    user_b_id UUID REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status enum_match_status DEFAULT 'active',
    
    -- Chat List Cache (Optimizes performance for the inbox screen)
    last_message_content VARCHAR(255),
    last_message_at TIMESTAMP
);

-- 8. Messages Table (Chat Data)
CREATE TABLE messages (
    id BIGSERIAL PRIMARY KEY,
    match_id UUID REFERENCES matches(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    type enum_msg_type DEFAULT 'text',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    read_at TIMESTAMP
);

-- 9. Speed Dating Table (Real-time Live Sessions)
CREATE TABLE speed_dating_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_a_id UUID REFERENCES users(id) ON DELETE CASCADE,
    user_b_id UUID REFERENCES users(id) ON DELETE CASCADE,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP, -- Ends after 3 minutes
    status VARCHAR(50) -- 'active', 'matched', 'expired'
);

-- 10. Performance Indexes
-- Essential for keeping the app fast as user count grows
CREATE INDEX idx_profiles_location ON profiles USING GIST (location_point);
CREATE INDEX idx_profiles_personality ON profiles (gender, personality_primary);
CREATE INDEX idx_matches_user_a ON matches (user_a_id, last_message_at);
CREATE INDEX idx_matches_user_b ON matches (user_b_id, last_message_at);
CREATE INDEX idx_messages_match_id ON messages (match_id, created_at);