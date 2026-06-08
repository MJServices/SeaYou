-- Migration to inspect function bodies for net.http or http_post
CREATE TABLE IF NOT EXISTS public.diagnostics_functions_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamp with time zone DEFAULT now(),
  info jsonb
);

ALTER TABLE public.diagnostics_functions_log DISABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.gather_function_diagnostics()
RETURNS jsonb AS $func$
DECLARE
  res jsonb := '{}'::jsonb;
  func_list jsonb;
BEGIN
  SELECT jsonb_agg(jsonb_build_object(
    'schema_name', n.nspname,
    'function_name', p.proname,
    'definition', pg_get_functiondef(p.oid)
  )) INTO func_list
  FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE p.prokind = 'f' -- standard functions
    AND n.nspname NOT IN ('pg_catalog', 'information_schema')
    AND (
      pg_get_functiondef(p.oid) ILIKE '%http_post%'
      OR pg_get_functiondef(p.oid) ILIKE '%net.http%'
      OR pg_get_functiondef(p.oid) ILIKE '%net_post%'
    );

  res := jsonb_set(res, '{functions}', COALESCE(func_list, '[]'::jsonb));
  RETURN res;
END;
$func$ LANGUAGE plpgsql SECURITY DEFINER;

-- Insert diagnostic info
INSERT INTO public.diagnostics_functions_log (info) VALUES (public.gather_function_diagnostics());
