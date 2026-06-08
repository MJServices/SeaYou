-- Migration to inspect net responses
CREATE TABLE IF NOT EXISTS public.diagnostics_net_responses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamp with time zone DEFAULT now(),
  info jsonb
);

ALTER TABLE public.diagnostics_net_responses DISABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.gather_net_responses()
RETURNS jsonb AS $func$
DECLARE
  res jsonb := '{}'::jsonb;
  net_resp jsonb;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'net') THEN
    BEGIN
      EXECUTE $query$
        SELECT jsonb_agg(to_jsonb(r)) FROM (
          SELECT * FROM net._http_response
          ORDER BY id DESC LIMIT 50
        ) r
      $query$ INTO net_resp;
      res := jsonb_set(res, '{responses}', COALESCE(net_resp, '[]'::jsonb));
    EXCEPTION WHEN OTHERS THEN
      res := jsonb_set(res, '{responses_error}', jsonb_build_object('message', SQLERRM));
    END;
  END IF;

  RETURN res;
END;
$func$ LANGUAGE plpgsql SECURITY DEFINER;

-- Insert diagnostic info
INSERT INTO public.diagnostics_net_responses (info) VALUES (public.gather_net_responses());
