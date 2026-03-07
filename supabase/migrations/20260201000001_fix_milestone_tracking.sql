-- Fix Milestone Tracking: Add Per-User Milestone Fields
-- This migration adds user-specific milestone tracking to prevent desynchronization

-- Add per-user milestone tracking columns
ALTER TABLE conversations 
ADD COLUMN IF NOT EXISTS user_a_seen_milestones integer[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS user_b_seen_milestones integer[] DEFAULT '{}';

-- Migrate existing unlocked_milestones to both users
-- This ensures backward compatibility for existing conversations
-- Cast JSONB array to integer array
UPDATE conversations
SET user_a_seen_milestones = CASE 
    WHEN unlocked_milestones IS NOT NULL AND jsonb_array_length(unlocked_milestones) > 0 
    THEN ARRAY(SELECT jsonb_array_elements_text(unlocked_milestones)::integer)
    ELSE '{}'::integer[]
  END,
  user_b_seen_milestones = CASE 
    WHEN unlocked_milestones IS NOT NULL AND jsonb_array_length(unlocked_milestones) > 0 
    THEN ARRAY(SELECT jsonb_array_elements_text(unlocked_milestones)::integer)
    ELSE '{}'::integer[]
  END
WHERE unlocked_milestones IS NOT NULL;

-- Add comment for documentation
COMMENT ON COLUMN conversations.user_a_seen_milestones IS 'Milestones that user A has personally seen (25, 50, 75, 100)';
COMMENT ON COLUMN conversations.user_b_seen_milestones IS 'Milestones that user B has personally seen (25, 50, 75, 100)';

-- Note: unlocked_milestones is kept for backward compatibility but is now deprecated
-- New code should use user_a_seen_milestones and user_b_seen_milestones instead
