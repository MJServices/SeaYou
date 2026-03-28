-- Update delete_account RPC to include proper security path
-- This ensures the function can delete from auth.users securely

CREATE OR REPLACE FUNCTION public.delete_account()
RETURNS void AS $$
BEGIN
  -- Verify the user is authenticated
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Delete the user from auth.users
  -- SECURITY DEFINER and SET search_path allow this to work even for the user themselves
  DELETE FROM auth.users WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;
