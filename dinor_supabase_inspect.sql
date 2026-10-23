-- Dinor Supabase schema inspection
-- Exports schema definitions only; no user data or secrets.

SELECT
    'TABLE' AS object_type,
    table_schema AS schema_name,
    table_name AS object_name
FROM information_schema.tables
WHERE table_schema IN ('public', 'auth', 'storage')
  AND table_type = 'BASE TABLE'
ORDER BY table_schema, table_name;

SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE schemaname IN ('public', 'storage')
ORDER BY schemaname, tablename, policyname;

SELECT
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('public')
ORDER BY n.nspname, p.proname;

SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname IN ('public', 'storage')
ORDER BY schemaname, tablename, indexname;

SELECT
    trigger_schema,
    event_object_table AS table_name,
    trigger_name,
    action_timing,
    event_manipulation,
    action_statement
FROM information_schema.triggers
WHERE trigger_schema IN ('public', 'storage')
ORDER BY trigger_schema, event_object_table, trigger_name;
