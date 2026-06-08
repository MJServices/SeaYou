-- Temporary migration to gather diagnostic information
CREATE TABLE IF NOT EXISTS public.diagnostics_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamp with time zone DEFAULT now(),
  info jsonb
);

ALTER TABLE public.diagnostics_log DISABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.gather_diagnostics()
RETURNS jsonb AS $func$
DECLARE
  res jsonb := '{}'::jsonb;
  trigger_list jsonb;
  cron_list jsonb;
  net_list jsonb;
BEGIN
  -- 1. Get triggers in public schema
  SELECT jsonb_agg(jsonb_build_object(
    'trigger_name', trigger_name,
    'event_manipulation', event_manipulation,
    'event_object_table', event_object_table,
    'action_statement', action_statement
  )) INTO trigger_list
  FROM information_schema.triggers
  WHERE trigger_schema = 'public';
  res := jsonb_set(res, '{triggers}', COALESCE(trigger_list, '[]'::jsonb));

  -- 2. Get cron jobs if cron schema exists
  IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'cron') THEN
    BEGIN
      EXECUTE 'SELECT jsonb_agg(to_jsonb(j)) FROM cron.job j' INTO cron_list;
      res := jsonb_set(res, '{cron_jobs}', COALESCE(cron_list, '[]'::jsonb));
    EXCEPTION WHEN OTHERS THEN
      res := jsonb_set(res, '{cron_jobs_error}', jsonb_build_object('message', SQLERRM));
    END;
  END IF;

  -- 3. Get recent net requests if net schema exists
  IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'net') THEN
    BEGIN
      EXECUTE $query$
        SELECT jsonb_agg(jsonb_build_object(
          'id', id,
          'method', method,
          'url', url,
          'headers', headers,
          'body', body,
          'created_at', created_at
        )) FROM net.http_request_queue
        ORDER BY id DESC LIMIT 50
      $query$ INTO net_list;
      res := jsonb_set(res, '{net_requests}', COALESCE(net_list, '[]'::jsonb));
    EXCEPTION WHEN OTHERS THEN
      res := jsonb_set(res, '{net_requests_error}', jsonb_build_object('message', SQLERRM));
    END;
  END IF;

  RETURN res;
END;
$func$ LANGUAGE plpgsql SECURITY DEFINER;

-- Insert diagnostic info
INSERT INTO public.diagnostics_log (info) VALUES (public.gather_diagnostics());
