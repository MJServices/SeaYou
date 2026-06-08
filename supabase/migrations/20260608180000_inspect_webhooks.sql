-- Inspect Supabase Dashboard-configured Database Webhooks
-- These live in supabase_functions schema and are NOT in migration files
-- They internally call net.http_post() on every table event

CREATE TABLE IF NOT EXISTS public.diagnostics_webhooks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamp with time zone DEFAULT now(),
  info jsonb
);

ALTER TABLE public.diagnostics_webhooks DISABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.gather_webhook_diagnostics()
RETURNS jsonb AS $func$
DECLARE
  res jsonb := '{}'::jsonb;
  webhook_list jsonb;
  hook_triggers jsonb;
BEGIN
  -- 1. Check supabase_functions.hooks table (Supabase Dashboard webhooks)
  IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'supabase_functions') THEN
    BEGIN
      EXECUTE $q$
        SELECT jsonb_agg(to_jsonb(h)) FROM supabase_functions.hooks h
      $q$ INTO webhook_list;
      res := jsonb_set(res, '{supabase_hooks}', COALESCE(webhook_list, '[]'::jsonb));
    EXCEPTION WHEN OTHERS THEN
      res := jsonb_set(res, '{supabase_hooks_error}', to_jsonb(SQLERRM));
    END;
  END IF;

  -- 2. Check for any triggers that call supabase_functions.http_request
  SELECT jsonb_agg(jsonb_build_object(
    'trigger_schema', t.trigger_schema,
    'trigger_name', t.trigger_name,
    'event', t.event_manipulation,
    'table', t.event_object_table,
    'action', t.action_statement
  )) INTO hook_triggers
  FROM information_schema.triggers t
  WHERE t.action_statement ILIKE '%http_request%'
     OR t.action_statement ILIKE '%http_post%'
     OR t.action_statement ILIKE '%supabase_functions%';

  res := jsonb_set(res, '{http_triggers}', COALESCE(hook_triggers, '[]'::jsonb));

  -- 3. Count total entries in net._http_response to understand scale
  BEGIN
    EXECUTE $q$
      SELECT jsonb_build_object(
        'total_http_response_rows', COUNT(*),
        'oldest', MIN(created),
        'newest', MAX(created),
        'last_1000_ids_range', jsonb_build_object(
          'min_id', MIN(id), 'max_id', MAX(id)
        )
      ) FROM net._http_response
    $q$ INTO webhook_list;
    res := jsonb_set(res, '{net_response_stats}', COALESCE(webhook_list, '{}'::jsonb));
  EXCEPTION WHEN OTHERS THEN
    res := jsonb_set(res, '{net_response_stats_error}', to_jsonb(SQLERRM));
  END;

  RETURN res;
END;
$func$ LANGUAGE plpgsql SECURITY DEFINER;

INSERT INTO public.diagnostics_webhooks (info) VALUES (public.gather_webhook_diagnostics());
