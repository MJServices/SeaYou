-- Migration to add delete_account RPC
-- This allows users to delete their own account from auth.users (cascades to public tables)

CREATE OR REPLACE FUNCTION delete_account()
RETURNS void AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Delete the user from auth.users
  -- This requires SECURITY DEFINER as public users normally cannot delete from auth.users
  -- The ON DELETE CASCADE on foreign keys will clean up profiles, settings, etc.
  DELETE FROM auth.users WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
