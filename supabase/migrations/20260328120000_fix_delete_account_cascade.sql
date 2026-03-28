-- Fix ON DELETE CASCADE for ALL user-related tables to allow complete account deletion
-- This ensures that when a record is deleted from auth.users, everything cascades correctly

DO $$
BEGIN
    -- 1. profiles
    BEGIN
        ALTER TABLE public.profiles
        DROP CONSTRAINT IF EXISTS profiles_id_fkey,
        ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
    EXCEPTION WHEN others THEN RAISE NOTICE 'profiles: %', SQLERRM; END;

    -- 2. user_preferences
    BEGIN
        ALTER TABLE public.user_preferences
        DROP CONSTRAINT IF EXISTS user_preferences_user_id_fkey,
        ADD CONSTRAINT user_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
    EXCEPTION WHEN others THEN RAISE NOTICE 'user_preferences: %', SQLERRM; END;

    -- 3. blocked_users
    BEGIN
        ALTER TABLE public.blocked_users
        DROP CONSTRAINT IF EXISTS blocked_users_blocker_id_fkey,
        ADD CONSTRAINT blocked_users_blocker_id_fkey FOREIGN KEY (blocker_id) REFERENCES auth.users(id) ON DELETE CASCADE;
        
        ALTER TABLE public.blocked_users
        DROP CONSTRAINT IF EXISTS blocked_users_blocked_id_fkey,
        ADD CONSTRAINT blocked_users_blocked_id_fkey FOREIGN KEY (blocked_id) REFERENCES auth.users(id) ON DELETE CASCADE;
    EXCEPTION WHEN others THEN RAISE NOTICE 'blocked_users: %', SQLERRM; END;

    -- 4. notification_tokens
    BEGIN
        ALTER TABLE public.notification_tokens
        DROP CONSTRAINT IF EXISTS notification_tokens_user_id_fkey,
        ADD CONSTRAINT notification_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
    EXCEPTION WHEN others THEN RAISE NOTICE 'notification_tokens: %', SQLERRM; END;

    -- 5. entitlements
    BEGIN
        ALTER TABLE public.entitlements
        DROP CONSTRAINT IF EXISTS entitlements_user_id_fkey,
        ADD CONSTRAINT entitlements_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
    EXCEPTION WHEN others THEN RAISE NOTICE 'entitlements: %', SQLERRM; END;

    -- 6. fantasies
    BEGIN
        ALTER TABLE public.fantasies
        DROP CONSTRAINT IF EXISTS fantasies_user_id_fkey,
        ADD CONSTRAINT fantasies_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
    EXCEPTION WHEN others THEN RAISE NOTICE 'fantasies: %', SQLERRM; END;

    -- 7. profile_photos
    BEGIN
        ALTER TABLE public.profile_photos
        DROP CONSTRAINT IF EXISTS profile_photos_user_id_fkey,
        ADD CONSTRAINT profile_photos_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
    EXCEPTION WHEN others THEN RAISE NOTICE 'profile_photos: %', SQLERRM; END;

    -- 8. conversations
    BEGIN
        ALTER TABLE public.conversations
        DROP CONSTRAINT IF EXISTS conversations_user_a_id_fkey,
        ADD CONSTRAINT conversations_user_a_id_fkey FOREIGN KEY (user_a_id) REFERENCES auth.users(id) ON DELETE CASCADE;
        
        ALTER TABLE public.conversations
        DROP CONSTRAINT IF EXISTS conversations_user_b_id_fkey,
        ADD CONSTRAINT conversations_user_b_id_fkey FOREIGN KEY (user_b_id) REFERENCES auth.users(id) ON DELETE CASCADE;
    EXCEPTION WHEN others THEN RAISE NOTICE 'conversations: %', SQLERRM; END;

    -- 9. messages (sender_id)
    BEGIN
        ALTER TABLE public.messages
        DROP CONSTRAINT IF EXISTS messages_sender_id_fkey,
        ADD CONSTRAINT messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES auth.users(id) ON DELETE CASCADE;
    EXCEPTION WHEN others THEN RAISE NOTICE 'messages: %', SQLERRM; END;

    -- 10. messages_outbox
    BEGIN
        ALTER TABLE public.messages_outbox
        DROP CONSTRAINT IF EXISTS messages_outbox_sender_id_fkey,
        ADD CONSTRAINT messages_outbox_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES auth.users(id) ON DELETE CASCADE;
    EXCEPTION WHEN others THEN RAISE NOTICE 'messages_outbox: %', SQLERRM; END;

    -- 11. matches
    BEGIN
        ALTER TABLE public.matches
        DROP CONSTRAINT IF EXISTS matches_recipient_id_fkey,
        ADD CONSTRAINT matches_recipient_id_fkey FOREIGN KEY (recipient_id) REFERENCES auth.users(id) ON DELETE CASCADE;
    EXCEPTION WHEN others THEN RAISE NOTICE 'matches: %', SQLERRM; END;

    -- 12. secret_souls_content
    BEGIN
        ALTER TABLE public.secret_souls_content
        DROP CONSTRAINT IF EXISTS secret_souls_content_user_id_fkey,
        ADD CONSTRAINT secret_souls_content_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
    EXCEPTION WHEN others THEN RAISE NOTICE 'secret_souls_content: %', SQLERRM; END;

    -- 13. support_requests
    BEGIN
        ALTER TABLE public.support_requests
        DROP CONSTRAINT IF EXISTS support_requests_user_id_fkey,
        ADD CONSTRAINT support_requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
    EXCEPTION WHEN others THEN RAISE NOTICE 'support_requests: %', SQLERRM; END;

    -- 14. intimate_questions
    BEGIN
        ALTER TABLE public.intimate_questions
        DROP CONSTRAINT IF EXISTS intimate_questions_user_id_fkey,
        ADD CONSTRAINT intimate_questions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
    EXCEPTION WHEN others THEN RAISE NOTICE 'intimate_questions: %', SQLERRM; END;

    -- 15. images (owner_id refers to profiles, which refers to auth.users, but we set cascade on profile)
    -- But images owner_id is NOT a direct ref to auth.users. It references public.profiles(id).
    -- Since public.profiles has CASCADE to auth.users, images should be fine IF profiles(id) is deleted.
    BEGIN
        ALTER TABLE public.images
        DROP CONSTRAINT IF EXISTS images_owner_id_fkey,
        ADD CONSTRAINT images_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
    EXCEPTION WHEN others THEN RAISE NOTICE 'images: %', SQLERRM; END;

END $$;
