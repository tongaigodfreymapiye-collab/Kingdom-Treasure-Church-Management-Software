-- Run after DEVELOPER_PLATFORM_ACCESS_MIGRATION.sql.
-- Read-only verification; expected no cross-tenant developer-read policies.
SELECT u.email,p.role,c.name AS home_church,b.name AS home_branch,s.plan,s.status,s.expires_at
FROM auth.users u JOIN public.profiles p ON p.id=u.id
LEFT JOIN public.churches c ON c.id=p.church_id
LEFT JOIN public.branches b ON b.id=p.branch_id
LEFT JOIN public.subscriptions s ON s.church_id=p.church_id
WHERE lower(u.email)=lower('tongaigodfreymapiye@gmail.com');

SELECT policyname,tablename,cmd,qual
FROM pg_policies
WHERE schemaname='public' AND policyname LIKE 'developer_read_all%';

SELECT
  has_function_privilege('anon','public.kt_developer_platform_overview()','EXECUTE') AS anon_can_call_platform_overview,
  has_function_privilege('authenticated','public.kt_developer_platform_overview()','EXECUTE') AS authenticated_can_call_platform_overview,
  has_table_privilege('authenticated','public.platform_business_ledger','SELECT') AS authenticated_can_read_business_ledger,
  has_table_privilege('service_role','public.platform_business_ledger','INSERT') AS service_role_can_write_business_ledger;

SELECT count(*) AS support_request_table_rows FROM public.platform_support_requests;
