-- Add lobby constitution and availability system
-- Migration: 20251216203000

-- 1. Add availability fields to users table
ALTER TABLE users
ADD COLUMN IF NOT EXISTS available_status TEXT,
ADD COLUMN IF NOT EXISTS available_tags TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN IF NOT EXISTS available_since TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS rule_badges JSONB DEFAULT '{}'::JSONB;

-- Index for finding available users
CREATE INDEX IF NOT EXISTS idx_users_available_status ON users(available_status) WHERE available_status IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_available_tags ON users USING GIN(available_tags) WHERE available_tags IS NOT NULL;

-- 2. Create constitution_templates table
CREATE TABLE IF NOT EXISTS constitution_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    icon TEXT,
    rules JSONB NOT NULL DEFAULT '{}'::JSONB,
    is_system_template BOOLEAN DEFAULT FALSE,
    created_by TEXT REFERENCES users(uid),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    usage_count INTEGER DEFAULT 0
);

-- Index for template lookups
CREATE INDEX IF NOT EXISTS idx_constitution_templates_system ON constitution_templates(is_system_template) WHERE is_system_template = TRUE;

-- Insert default templates
INSERT INTO constitution_templates (name, description, icon, rules, is_system_template) VALUES
('Chill Vibes', 'Casual gaming with flexible rules', '😎', '{
    "spot_timer": "10m",
    "afk_penalty": "warning",
    "mic_required": false,
    "skill_level": "any",
    "enforcement_level": "loose_social",
    "max_violations": 5,
    "violation_decay_days": 7
}'::JSONB, TRUE),
('Elite Squad', 'Competitive gaming with strict rules', '🏆', '{
    "spot_timer": "3m",
    "afk_penalty": "kick",
    "mic_required": true,
    "skill_level": "advanced",
    "enforcement_level": "strict_auto",
    "check_in_required": true,
    "check_in_interval": "5m",
    "max_violations": 2,
    "violation_decay_days": 30
}'::JSONB, TRUE),
('Beginner Friendly', 'Welcoming space for new players', '🌱', '{
    "spot_timer": "15m",
    "afk_penalty": "reminder",
    "mic_required": false,
    "skill_level": "beginner",
    "enforcement_level": "loose_social",
    "helper_badge": true,
    "max_violations": 10,
    "violation_decay_days": 3
}'::JSONB, TRUE),
('Speedrun Session', 'Fast-paced runs with tight timing', '⚡', '{
    "spot_timer": "2m",
    "afk_penalty": "auto_kick",
    "mic_required": true,
    "skill_level": "advanced",
    "enforcement_level": "strict_auto",
    "check_in_required": true,
    "check_in_interval": "3m",
    "max_violations": 1,
    "violation_decay_days": 14
}'::JSONB, TRUE),
('Ranked Grind', 'Serious ranked matches', '🎯', '{
    "spot_timer": "5m",
    "afk_penalty": "kick",
    "mic_required": true,
    "skill_level": "intermediate",
    "enforcement_level": "strict_auto",
    "check_in_required": true,
    "max_violations": 3,
    "violation_decay_days": 21
}'::JSONB, TRUE)
ON CONFLICT (id) DO NOTHING;

-- 3. Create chat_constitutions table
CREATE TABLE IF NOT EXISTS chat_constitutions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chat_group_id TEXT NOT NULL REFERENCES chat_groups(id) ON DELETE CASCADE,
    template_id UUID REFERENCES constitution_templates(id),
    rules JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_by TEXT NOT NULL REFERENCES users(uid),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE,
    vote_history JSONB DEFAULT '[]'::JSONB,
    UNIQUE(chat_group_id, is_active)
);

-- Index for active constitutions
CREATE INDEX IF NOT EXISTS idx_chat_constitutions_active ON chat_constitutions(chat_group_id, is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_chat_constitutions_template ON chat_constitutions(template_id);

-- 4. Add lobby tags and visibility to lobbies table
ALTER TABLE lobbies
ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN IF NOT EXISTS visibility TEXT DEFAULT 'group_private' CHECK (visibility IN ('group_private', 'friends_only', 'public')),
ADD COLUMN IF NOT EXISTS constitution_rules JSONB DEFAULT '{}'::JSONB,
ADD COLUMN IF NOT EXISTS embedded_message_id TEXT;

-- Index for lobby discovery
CREATE INDEX IF NOT EXISTS idx_lobbies_visibility ON lobbies(visibility);
CREATE INDEX IF NOT EXISTS idx_lobbies_tags ON lobbies USING GIN(tags) WHERE tags IS NOT NULL;

-- 5. Create constitution_votes table for rule change voting
CREATE TABLE IF NOT EXISTS constitution_votes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    constitution_id UUID NOT NULL REFERENCES chat_constitutions(id) ON DELETE CASCADE,
    chat_group_id TEXT NOT NULL REFERENCES chat_groups(id) ON DELETE CASCADE,
    proposed_rules JSONB NOT NULL,
    proposed_by TEXT NOT NULL REFERENCES users(uid),
    votes JSONB DEFAULT '{}'::JSONB,
    vote_count_yes INTEGER DEFAULT 0,
    vote_count_no INTEGER DEFAULT 0,
    vote_threshold NUMERIC DEFAULT 0.5 CHECK (vote_threshold BETWEEN 0 AND 1),
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'passed', 'rejected', 'expired')),
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    resolved_at TIMESTAMPTZ
);

-- Index for active votes
CREATE INDEX IF NOT EXISTS idx_constitution_votes_status ON constitution_votes(constitution_id, status) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_constitution_votes_expires ON constitution_votes(expires_at) WHERE status = 'pending';

-- 6. Create rule_violations table for tracking enforcement
CREATE TABLE IF NOT EXISTS rule_violations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lobby_id TEXT NOT NULL REFERENCES lobbies(id) ON DELETE CASCADE,
    chat_group_id TEXT REFERENCES chat_groups(id),
    user_uid TEXT NOT NULL REFERENCES users(uid),
    rule_type TEXT NOT NULL,
    severity TEXT DEFAULT 'minor' CHECK (severity IN ('minor', 'moderate', 'major', 'critical')),
    violation_data JSONB DEFAULT '{}'::JSONB,
    enforcement_action TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ
);

-- Index for user violation history
CREATE INDEX IF NOT EXISTS idx_rule_violations_user ON rule_violations(user_uid, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_rule_violations_lobby ON rule_violations(lobby_id);
CREATE INDEX IF NOT EXISTS idx_rule_violations_active ON rule_violations(user_uid, expires_at) WHERE resolved_at IS NULL;

-- 7. Create tag_analytics table for tracking popular tags
CREATE TABLE IF NOT EXISTS tag_analytics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tag TEXT NOT NULL UNIQUE,
    usage_count INTEGER DEFAULT 1,
    lobby_count INTEGER DEFAULT 0,
    user_count INTEGER DEFAULT 0,
    last_used TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    trending_score NUMERIC DEFAULT 0,
    category TEXT
);

-- Index for tag lookups and trending
CREATE INDEX IF NOT EXISTS idx_tag_analytics_tag ON tag_analytics(tag);
CREATE INDEX IF NOT EXISTS idx_tag_analytics_trending ON tag_analytics(trending_score DESC, usage_count DESC);
CREATE INDEX IF NOT EXISTS idx_tag_analytics_category ON tag_analytics(category) WHERE category IS NOT NULL;

-- 8. Function to auto-expire constitution votes
CREATE OR REPLACE FUNCTION expire_constitution_votes()
RETURNS void AS $$
DECLARE
    expired_vote RECORD;
BEGIN
    -- Get all pending votes that have expired
    FOR expired_vote IN
        SELECT id, vote_count_yes, vote_count_no, vote_threshold,
               (SELECT COUNT(DISTINCT uid) FROM unnest((SELECT member_uids FROM chat_groups WHERE id = chat_group_id))) as member_count
        FROM constitution_votes
        WHERE status = 'pending'
          AND expires_at <= NOW()
    LOOP
        -- Calculate if vote passed
        IF expired_vote.vote_count_yes::NUMERIC / NULLIF(expired_vote.member_count, 0) >= expired_vote.vote_threshold THEN
            UPDATE constitution_votes
            SET status = 'passed', resolved_at = NOW()
            WHERE id = expired_vote.id;
        ELSE
            UPDATE constitution_votes
            SET status = 'expired', resolved_at = NOW()
            WHERE id = expired_vote.id;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 9. Function to apply constitution rules to new lobby
CREATE OR REPLACE FUNCTION apply_constitution_to_lobby()
RETURNS TRIGGER AS $$
DECLARE
    constitution_record RECORD;
BEGIN
    -- Get active constitution for the lobby's chat group
    IF NEW.chat_group_id IS NOT NULL THEN
        SELECT rules INTO constitution_record
        FROM chat_constitutions
        WHERE chat_group_id = NEW.chat_group_id
          AND is_active = TRUE
        LIMIT 1;
        
        -- Apply rules if constitution exists
        IF FOUND THEN
            NEW.constitution_rules := constitution_record.rules;
            
            -- Apply spot timer from constitution if specified
            IF constitution_record.rules ? 'spot_timer' THEN
                NEW.settings := jsonb_set(
                    COALESCE(NEW.settings, '{}'::JSONB),
                    '{constitution_timer}',
                    constitution_record.rules->'spot_timer'
                );
            END IF;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for auto-applying constitution
DROP TRIGGER IF EXISTS trigger_apply_constitution ON lobbies;
CREATE TRIGGER trigger_apply_constitution
    BEFORE INSERT ON lobbies
    FOR EACH ROW
    WHEN (NEW.chat_group_id IS NOT NULL)
    EXECUTE FUNCTION apply_constitution_to_lobby();

-- 10. Function to update tag analytics
CREATE OR REPLACE FUNCTION update_tag_analytics()
RETURNS TRIGGER AS $$
DECLARE
    tag_item TEXT;
    decay_factor NUMERIC;
BEGIN
    -- Calculate trending score with time decay (7-day half-life)
    decay_factor := EXP(-LN(2) * EXTRACT(EPOCH FROM (NOW() - COALESCE(OLD.last_used, NOW()))) / (7 * 86400));
    
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        -- Update analytics for each tag
        FOREACH tag_item IN ARRAY NEW.tags
        LOOP
            INSERT INTO tag_analytics (tag, usage_count, lobby_count, last_used, trending_score)
            VALUES (tag_item, 1, 1, NOW(), 1.0)
            ON CONFLICT (tag) 
            DO UPDATE SET
                usage_count = tag_analytics.usage_count + 1,
                lobby_count = tag_analytics.lobby_count + 1,
                last_used = NOW(),
                trending_score = (tag_analytics.trending_score * decay_factor + 1.0);
        END LOOP;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for tag analytics
DROP TRIGGER IF EXISTS trigger_update_tag_analytics ON lobbies;
CREATE TRIGGER trigger_update_tag_analytics
    AFTER INSERT OR UPDATE OF tags ON lobbies
    FOR EACH ROW
    WHEN (NEW.tags IS NOT NULL AND array_length(NEW.tags, 1) > 0)
    EXECUTE FUNCTION update_tag_analytics();

-- 11. Function to check violation escalation
CREATE OR REPLACE FUNCTION get_violation_severity(
    p_user_uid TEXT,
    p_chat_group_id TEXT,
    p_rule_type TEXT,
    p_max_violations INTEGER DEFAULT 3
) RETURNS TEXT AS $$
DECLARE
    violation_count INTEGER;
    recent_violations INTEGER;
BEGIN
    -- Count active violations (not expired)
    SELECT COUNT(*) INTO violation_count
    FROM rule_violations
    WHERE user_uid = p_user_uid
      AND chat_group_id = p_chat_group_id
      AND rule_type = p_rule_type
      AND (expires_at IS NULL OR expires_at > NOW());
    
    -- Count recent violations (last 24 hours)
    SELECT COUNT(*) INTO recent_violations
    FROM rule_violations
    WHERE user_uid = p_user_uid
      AND chat_group_id = p_chat_group_id
      AND created_at > NOW() - INTERVAL '24 hours';
    
    -- Escalation logic
    IF recent_violations >= 3 THEN
        RETURN 'critical';
    ELSIF violation_count >= p_max_violations THEN
        RETURN 'major';
    ELSIF violation_count >= p_max_violations / 2 THEN
        RETURN 'moderate';
    ELSE
        RETURN 'minor';
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 12. Function to expire old violations
CREATE OR REPLACE FUNCTION expire_old_violations()
RETURNS void AS $$
BEGIN
    UPDATE rule_violations
    SET resolved_at = NOW()
    WHERE expires_at IS NOT NULL
      AND expires_at <= NOW()
      AND resolved_at IS NULL;
END;
$$ LANGUAGE plpgsql;

-- 13. RLS Policies for new tables

-- constitution_templates policies
ALTER TABLE constitution_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view templates"
    ON constitution_templates FOR SELECT
    TO public
    USING (true);

CREATE POLICY "Authenticated users can create custom templates"
    ON constitution_templates FOR INSERT
    TO authenticated
    WITH CHECK (created_by = auth.uid() AND is_system_template = FALSE);

CREATE POLICY "Users can update own templates"
    ON constitution_templates FOR UPDATE
    TO authenticated
    USING (created_by = auth.uid() AND is_system_template = FALSE);

-- chat_constitutions policies
ALTER TABLE chat_constitutions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Group members can view constitution"
    ON chat_constitutions FOR SELECT
    TO public
    USING (
        chat_group_id IN (
            SELECT id FROM chat_groups
            WHERE auth.uid() = ANY(member_uids)
        )
    );

CREATE POLICY "Group members can create constitution"
    ON chat_constitutions FOR INSERT
    TO authenticated
    WITH CHECK (
        chat_group_id IN (
            SELECT id FROM chat_groups
            WHERE auth.uid() = ANY(member_uids)
        )
    );

CREATE POLICY "Group members can update constitution"
    ON chat_constitutions FOR UPDATE
    TO authenticated
    USING (
        chat_group_id IN (
            SELECT id FROM chat_groups
            WHERE auth.uid() = ANY(member_uids)
        )
    );

-- constitution_votes policies
ALTER TABLE constitution_votes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Group members can view votes"
    ON constitution_votes FOR SELECT
    TO public
    USING (
        chat_group_id IN (
            SELECT id FROM chat_groups
            WHERE auth.uid() = ANY(member_uids)
        )
    );

CREATE POLICY "Group members can create votes"
    ON constitution_votes FOR INSERT
    TO authenticated
    WITH CHECK (
        chat_group_id IN (
            SELECT id FROM chat_groups
            WHERE auth.uid() = ANY(member_uids)
        )
    );

CREATE POLICY "Group members can update votes"
    ON constitution_votes FOR UPDATE
    TO authenticated
    USING (
        chat_group_id IN (
            SELECT id FROM chat_groups
            WHERE auth.uid() = ANY(member_uids)
        )
    );

-- rule_violations policies
ALTER TABLE rule_violations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own violations"
    ON rule_violations FOR SELECT
    TO authenticated
    USING (user_uid = auth.uid());

CREATE POLICY "Lobby members can view violations"
    ON rule_violations FOR SELECT
    TO authenticated
    USING (
        lobby_id IN (
            SELECT id FROM lobbies
            WHERE auth.uid() = ANY(member_uids)
        )
    );

CREATE POLICY "System can create violations"
    ON rule_violations FOR INSERT
    TO public
    WITH CHECK (true);

-- tag_analytics policies
ALTER TABLE tag_analytics ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view tag analytics"
    ON tag_analytics FOR SELECT
    TO public
    USING (true);

CREATE POLICY "System can update tag analytics"
    ON tag_analytics FOR INSERT
    TO public
    WITH CHECK (true);

CREATE POLICY "System can update tag stats"
    ON tag_analytics FOR UPDATE
    TO public
    USING (true);

-- 14. Schedule vote expiration check (runs every 5 minutes)
SELECT cron.schedule(
    'expire-constitution-votes',
    '*/5 * * * *',
    $$SELECT expire_constitution_votes()$$
);

-- 15. Schedule violation expiration (runs daily at midnight)
SELECT cron.schedule(
    'expire-old-violations',
    '0 0 * * *',
    $$SELECT expire_old_violations()$$
);

-- 16. Comments for documentation
COMMENT ON TABLE constitution_templates IS 'Pre-defined rule templates for chat group constitutions (e.g., "Chill Vibes", "Elite Squad")';
COMMENT ON TABLE chat_constitutions IS 'Active constitutions for chat groups, defining lobby rules and enforcement';
COMMENT ON TABLE constitution_votes IS 'Voting records for proposed constitution changes with 24-hour voting period';
COMMENT ON TABLE rule_violations IS 'Tracking enforcement actions and violations with escalating severity';
COMMENT ON TABLE tag_analytics IS 'Analytics for lobby tags with trending scores and usage statistics';
COMMENT ON COLUMN users.available_status IS 'User availability status message (e.g., "Looking for ranked games")';
COMMENT ON COLUMN users.available_tags IS 'Tags for availability (e.g., ["ranked", "mic-on", "casual"])';
COMMENT ON COLUMN users.rule_badges IS 'Social badges from rule enforcement (e.g., {"Rule Breaker": 3, "Helper": 5})';
COMMENT ON COLUMN lobbies.tags IS 'Lobby tags for filtering (max 3, 20 chars each)';
COMMENT ON COLUMN lobbies.visibility IS 'Lobby visibility: group_private, friends_only, or public';
COMMENT ON COLUMN lobbies.constitution_rules IS 'Applied constitution rules for this lobby';
COMMENT ON COLUMN constitution_votes.vote_threshold IS 'Percentage threshold for vote to pass (0.5 = 50%, 0.66 = 66%, 1.0 = unanimous)';
