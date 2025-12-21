-- Create Secret Souls Content Table
CREATE TABLE IF NOT EXISTS secret_souls_content (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content_type TEXT NOT NULL CHECK (content_type IN ('photo', 'audio', 'quote')),
  photo_url TEXT,
  audio_url TEXT,
  quote_text TEXT,
  is_visible BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX idx_secret_souls_visible ON secret_souls_content(is_visible, content_type);
CREATE INDEX idx_secret_souls_user ON secret_souls_content(user_id);
CREATE INDEX idx_secret_souls_created ON secret_souls_content(created_at DESC);

-- Enable RLS
ALTER TABLE secret_souls_content ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can view all visible content (anonymous)
CREATE POLICY "Anyone can view visible content"
  ON secret_souls_content
  FOR SELECT
  USING (is_visible = true);

-- Users can manage their own content
CREATE POLICY "Users can manage own content"
  ON secret_souls_content
  FOR ALL
  USING (auth.uid() = user_id);

-- Migrate existing photos
INSERT INTO secret_souls_content (user_id, content_type, photo_url, is_visible)
SELECT user_id, 'photo', url, show_in_secret_souls
FROM profile_photos
WHERE show_in_secret_souls = true
ON CONFLICT DO NOTHING;

-- Add audio from profiles
INSERT INTO secret_souls_content (user_id, content_type, audio_url, is_visible)
SELECT id, 'audio', secret_audio_url, true
FROM profiles
WHERE secret_audio_url IS NOT NULL AND secret_audio_url != ''
ON CONFLICT DO NOTHING;

-- Add quotes from profiles
INSERT INTO secret_souls_content (user_id, content_type, quote_text, is_visible)
SELECT id, 'quote', about, true
FROM profiles
WHERE about IS NOT NULL AND about != '' AND LENGTH(about) > 10
ON CONFLICT DO NOTHING;

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_secret_souls_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER secret_souls_updated_at
  BEFORE UPDATE ON secret_souls_content
  FOR EACH ROW
  EXECUTE FUNCTION update_secret_souls_updated_at();
