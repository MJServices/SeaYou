
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'mood') THEN 
        ALTER TABLE "public"."messages" ADD COLUMN "mood" text; 
    END IF; 
END $$;
