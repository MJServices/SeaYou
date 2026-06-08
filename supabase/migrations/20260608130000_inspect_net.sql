-- New migration to inspect the net schema and all triggers
CREATE TABLE IF NOT EXISTS public.diagnostics_net_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamp with time zone DEFAULT now(),
  info jsonb
);

ALTER TABLE public.diagnostics_net_log DISABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.gather_net_diagnostics()
RETURNS jsonb AS $func$
DECLARE
  res jsonb := '{}'::jsonb;
  net_tables jsonb;
  net_requests jsonb;
  all_triggers jsonb;
BEGIN
  -- 1. Get all tables in the 'net' schema
  SELECT jsonb_agg(table_name) INTO net_tables
  FROM information_schema.tables
  WHERE table_schema = 'net';
  res := jsonb_set(res, '{net_tables}', COALESCE(net_tables, '[]'::jsonb));

  -- 2. Get recent pg_net requests (selecting all columns dynamically using to_jsonb)
  IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'net') THEN
    BEGIN
      EXECUTE $query$
        SELECT jsonb_agg(to_jsonb(r)) FROM (
          SELECT * FROM net.http_request_queue
          ORDER BY id DESC LIMIT 50
        ) r
      $query$ INTO net_requests;
      res := jsonb_set(res, '{net_requests}', COALESCE(net_requests, '[]'::jsonb));
    EXCEPTION WHEN OTHERS THEN
      res := jsonb_set(res, '{net_requests_error}', jsonb_build_object('message', SQLERRM));
    END;
  END IF;

  -- 3. Get ALL triggers on ANY table, including their schema and action definition
  SELECT jsonb_agg(jsonb_build_object(
    'trigger_schema', trigger_schema,
    'trigger_name', trigger_name,
    'event_manipulation', event_manipulation,
    'event_object_schema', event_object_schema,
    'event_object_table', event_object_table,
    'action_statement', action_statement,
    'action_orientation', action_orientation,
    'action_timing', action_timing
  )) INTO all_triggers
  FROM information_schema.triggers;
  res := jsonb_set(res, '{all_triggers}', COALESCE(all_triggers, '[]'::jsonb));

  RETURN res;
END;
$func$ LANGUAGE plpgsql SECURITY DEFINER;

-- Insert diagnostic info
INSERT INTO public.diagnostics_net_log (info) VALUES (public.gather_net_diagnostics());
