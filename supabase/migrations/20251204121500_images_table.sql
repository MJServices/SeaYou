CREATE TABLE IF NOT EXISTS public.images (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  bucket text NOT NULL,
  path text NOT NULL,
  url text NOT NULL,
  content_type text,
  size int,
  width int,
  height int,
  entity_type text,
  entity_id uuid,
  visibility text DEFAULT 'public',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_images_owner ON public.images(owner_id);
CREATE INDEX IF NOT EXISTS idx_images_entity ON public.images(entity_type, entity_id);

ALTER TABLE public.images
  ADD CONSTRAINT fk_images_entity_profile_photo
    FOREIGN KEY (entity_id) REFERENCES public.profile_photos(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

COMMENT ON TABLE public.images IS 'Generic image metadata and references';
