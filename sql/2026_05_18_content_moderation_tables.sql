-- ============================================================================
-- Migration: Content Moderation Tables (Apple Guideline 1.2 – UGC)
-- Run once via the Supabase SQL Editor.
-- ============================================================================

-- 1. reported_content – stores video/user reports from users
CREATE TABLE IF NOT EXISTS reported_content (
  id            uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  reporter_user_id text NOT NULL,
  content_id    text NOT NULL,
  content_type  text NOT NULL CHECK (content_type IN ('video', 'user', 'comment')),
  content_owner_id text,
  reason        text NOT NULL,
  status        text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'resolved', 'dismissed')),
  admin_notes   text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  reviewed_at   timestamptz,
  UNIQUE (reporter_user_id, content_id, content_type)
);

-- Index for admin dashboard to quickly see pending reports
CREATE INDEX IF NOT EXISTS idx_reported_content_status ON reported_content (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reported_content_owner  ON reported_content (content_owner_id);

-- RLS: users can only insert/read their own reports
ALTER TABLE reported_content ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can insert their own reports" ON reported_content;
CREATE POLICY "Users can insert their own reports"
  ON reported_content FOR INSERT
  WITH CHECK (reporter_user_id = auth.uid()::text);

DROP POLICY IF EXISTS "Users can read their own reports" ON reported_content;
CREATE POLICY "Users can read their own reports"
  ON reported_content FOR SELECT
  USING (reporter_user_id = auth.uid()::text);

-- Admin can read and update all
DROP POLICY IF EXISTS "Admins can manage all reports" ON reported_content;
CREATE POLICY "Admins can manage all reports"
  ON reported_content FOR ALL
  USING (
    EXISTS (SELECT 1 FROM users WHERE user_id::text = auth.uid()::text AND "userType" = 'admin')
  );


-- 2. blocked_users – user-to-user blocking for feed filtering
CREATE TABLE IF NOT EXISTS blocked_users (
  id              uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id         text NOT NULL,
  blocked_user_id text NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, blocked_user_id)
);

CREATE INDEX IF NOT EXISTS idx_blocked_users_user ON blocked_users (user_id);

-- RLS: users can only manage their own blocks
ALTER TABLE blocked_users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own blocks" ON blocked_users;
CREATE POLICY "Users can manage their own blocks"
  ON blocked_users FOR ALL
  USING (user_id = auth.uid()::text)
  WITH CHECK (user_id = auth.uid()::text);

-- Admin can see all blocks for moderation
DROP POLICY IF EXISTS "Admins can read all blocks" ON blocked_users;
CREATE POLICY "Admins can read all blocks"
  ON blocked_users FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM users WHERE user_id::text = auth.uid()::text AND "userType" = 'admin')
  );

-- ============================================================================
-- Done. Both tables now have proper RLS and indexes.
-- ============================================================================
