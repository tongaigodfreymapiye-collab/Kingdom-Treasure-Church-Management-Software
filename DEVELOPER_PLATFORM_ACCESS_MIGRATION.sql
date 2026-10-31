-- Kingdom Treasure privacy-first developer platform migration
-- Replaces the earlier broad cross-church developer-read migration.
-- Run once in Supabase SQL Editor after taking a database backup.
-- The reserved developer is assigned to CFMI/Main Branch and receives lifetime entitlement.
-- Cross-church detail is available only through a church-approved, time-limited support grant.

BEGIN;

-- A. Ensure the reserved verified developer has a home church and branch.
DO $$
DECLARE v_user_id uuid; v_church_id uuid; v_branch_id uuid;
BEGIN
  SELECT id INTO v_user_id FROM auth.users
   WHERE lower(email)=lower('tongaigodfreymapiye@gmail.com') AND email_confirmed_at IS NOT NULL LIMIT 1;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Verified reserved developer account not found.'; END IF;

  SELECT id INTO v_church_id FROM public.churches
   WHERE lower(trim(name))=lower('Consuming Fire Ministries International') ORDER BY created_at LIMIT 1;
  IF v_church_id IS NULL THEN
    INSERT INTO public.churches(name,currency,country)
    VALUES('Consuming Fire Ministries International','USD','Zimbabwe') RETURNING id INTO v_church_id;
  END IF;

  SELECT id INTO v_branch_id FROM public.branches
   WHERE church_id=v_church_id AND lower(trim(name))=lower('Main Branch') LIMIT 1;
  IF v_branch_id IS NULL THEN
    INSERT INTO public.branches(church_id,name,active) VALUES(v_church_id,'Main Branch',true)
    RETURNING id INTO v_branch_id;
  END IF;

  UPDATE public.profiles SET church_id=v_church_id, branch_id=v_branch_id,
    full_name=COALESCE(NULLIF(full_name,''),'Tongai Godfrey Mapiye'), role='developer'
  WHERE id=v_user_id;

  INSERT INTO public.subscriptions(church_id,plan,status,started_at,expires_at,extra_branch_slots,updated_at)
  VALUES(v_church_id,'lifetime','active',now(),NULL,0,now())
  ON CONFLICT(church_id) DO UPDATE SET plan='lifetime',status='active',expires_at=NULL,updated_at=now();
END $$;

-- B. Remove any earlier broad developer-read policies. They must not remain active.
DROP POLICY IF EXISTS developer_read_all_departments ON public.departments;
DROP POLICY IF EXISTS developer_read_all_members ON public.members;
DROP POLICY IF EXISTS developer_read_all_pledges ON public.pledges;
DROP POLICY IF EXISTS developer_read_all_accounts ON public.accounts;
DROP POLICY IF EXISTS developer_read_all_transactions ON public.financial_transactions;
DROP POLICY IF EXISTS developer_read_all_journal_entries ON public.journal_entries;
DROP POLICY IF EXISTS developer_read_all_journal_lines ON public.journal_lines;
DROP POLICY IF EXISTS developer_read_all_budgets ON public.budgets;

-- Tighten existing developer bypasses so ordinary app queries expose only the home church.
DROP POLICY IF EXISTS "church read tenant or developer" ON public.churches;
DROP POLICY IF EXISTS "branch read tenant" ON public.branches;
DROP POLICY IF EXISTS "profile read tenant" ON public.profiles;
DROP POLICY IF EXISTS "subscription read tenant" ON public.subscriptions;
DROP POLICY IF EXISTS "subscription read" ON public.subscriptions;
DROP POLICY IF EXISTS "subscription requests read" ON public.subscription_requests;
DROP POLICY IF EXISTS "invitations read admin" ON public.church_invitations;
DROP POLICY IF EXISTS "invitations read home branch" ON public.church_invitations;
DROP POLICY IF EXISTS "audit read admin" ON public.audit_log;
DROP POLICY IF EXISTS "audit read home branch" ON public.audit_log;

DROP POLICY IF EXISTS "church read home tenant" ON public.churches;
DROP POLICY IF EXISTS "branch read home tenant" ON public.branches;
DROP POLICY IF EXISTS "profile read home tenant or self" ON public.profiles;
DROP POLICY IF EXISTS "profile read home branch or self" ON public.profiles;
DROP POLICY IF EXISTS "subscription read home tenant" ON public.subscriptions;
DROP POLICY IF EXISTS "subscription requests read home tenant" ON public.subscription_requests;
CREATE POLICY "church read home tenant" ON public.churches
  FOR SELECT TO authenticated USING (id=public.kt_church_id());
CREATE POLICY "branch read home tenant" ON public.branches
  FOR SELECT TO authenticated USING (church_id=public.kt_church_id() AND public.kt_can_see_branch(id));

-- The developer's everyday church workspace is limited to the developer's assigned CFMI branch.
-- Church administrators may see all branches in their own church; other roles see their assigned branch.
CREATE OR REPLACE FUNCTION public.kt_can_see_branch(p_branch_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='pg_catalog','public' AS $$
  SELECT COALESCE(EXISTS (
    SELECT 1 FROM public.profiles p JOIN public.branches b ON b.id=p_branch_id
    WHERE p.id=auth.uid() AND b.church_id=p.church_id
      AND (p.role='church_admin' OR b.id=p.branch_id)
  ),false)
$$;
CREATE POLICY "profile read home branch or self" ON public.profiles
  FOR SELECT TO authenticated USING (id=auth.uid() OR (church_id=public.kt_church_id() AND public.kt_can_see_branch(branch_id)));
CREATE POLICY "subscription read home tenant" ON public.subscriptions
  FOR SELECT TO authenticated USING (church_id=public.kt_church_id());
CREATE POLICY "subscription requests read home tenant" ON public.subscription_requests
  FOR SELECT TO authenticated USING (church_id=public.kt_church_id());
CREATE POLICY "invitations read home branch" ON public.church_invitations
  FOR SELECT TO authenticated USING (church_id=public.kt_church_id() AND (public.kt_role()='church_admin' OR (public.kt_role()='developer' AND public.kt_can_see_branch(branch_id))));

-- Keep the audit trail branch-scoped for the developer's CFMI workspace.
ALTER TABLE public.audit_log ADD COLUMN IF NOT EXISTS branch_id uuid REFERENCES public.branches(id) ON DELETE SET NULL;
CREATE OR REPLACE FUNCTION public.kt_audit_financial_transaction()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='pg_catalog','public' AS $$
BEGIN
  INSERT INTO public.audit_log(church_id,branch_id,actor,action,entity,entity_id,details)
  VALUES(NEW.church_id,NEW.branch_id,auth.uid(),CASE WHEN TG_OP='INSERT' THEN 'create' ELSE 'update' END,
    'financial_transaction',NEW.id::text,jsonb_build_object('direction',NEW.direction,'amount',NEW.amount,'currency',NEW.currency,'status',NEW.status));
  RETURN NEW;
END $$;
CREATE POLICY "audit read home branch" ON public.audit_log
  FOR SELECT TO authenticated USING (church_id=public.kt_church_id() AND (public.kt_role()='church_admin' OR public.kt_can_see_branch(branch_id)));

-- C. Church-controlled temporary support access requests.
CREATE TABLE IF NOT EXISTS public.platform_support_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  church_id uuid NOT NULL REFERENCES public.churches(id) ON DELETE CASCADE,
  requested_by uuid NOT NULL REFERENCES auth.users(id),
  reason text NOT NULL CHECK(length(trim(reason)) BETWEEN 10 AND 1000),
  scope text NOT NULL CHECK(scope IN ('read_only_diagnostics','financial_review','user_access_review')),
  status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','revoked','expired','declined')),
  requested_at timestamptz NOT NULL DEFAULT now(),
  approved_by uuid REFERENCES auth.users(id),
  approved_at timestamptz,
  expires_at timestamptz,
  revoked_by uuid REFERENCES auth.users(id),
  revoked_at timestamptz,
  last_accessed_at timestamptz
);
CREATE INDEX IF NOT EXISTS platform_support_requests_church_status_idx
  ON public.platform_support_requests(church_id,status,expires_at);
ALTER TABLE public.platform_support_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.platform_support_requests FROM PUBLIC,anon,authenticated;

-- D. Separate ledger for the software business (not a church fund or church account).
CREATE TABLE IF NOT EXISTS public.platform_business_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  direction text NOT NULL CHECK(direction IN ('income','expense')),
  entry_date date NOT NULL DEFAULT CURRENT_DATE,
  category text NOT NULL,
  description text NOT NULL,
  amount numeric(14,2) NOT NULL CHECK(amount>0),
  currency char(3) NOT NULL DEFAULT 'USD',
  reference text,
  created_by uuid NOT NULL REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS platform_business_ledger_date_idx ON public.platform_business_ledger(entry_date DESC);
ALTER TABLE public.platform_business_ledger ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.platform_business_ledger FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.platform_business_ledger TO service_role;
GRANT SELECT,UPDATE ON public.platform_support_requests TO service_role;

-- E. Church admin creates a support request. It does NOT grant access by itself.
CREATE OR REPLACE FUNCTION public.kt_request_developer_support(p_reason text,p_scope text DEFAULT 'read_only_diagnostics')
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='pg_catalog','public' AS $$
DECLARE v_id uuid; v_church uuid;
BEGIN
  IF auth.uid() IS NULL OR public.kt_role() <> 'church_admin' THEN RAISE EXCEPTION 'Only a church administrator can request developer assistance.'; END IF;
  v_church:=public.kt_church_id();
  IF v_church IS NULL THEN RAISE EXCEPTION 'Your account is not assigned to a church.'; END IF;
  IF p_scope NOT IN ('read_only_diagnostics','financial_review','user_access_review') THEN RAISE EXCEPTION 'Invalid support scope.'; END IF;
  IF length(trim(COALESCE(p_reason,'')))<10 OR length(p_reason)>1000 THEN RAISE EXCEPTION 'Please provide a support reason between 10 and 1000 characters.'; END IF;
  INSERT INTO public.platform_support_requests(church_id,requested_by,reason,scope)
  VALUES(v_church,auth.uid(),trim(p_reason),p_scope) RETURNING id INTO v_id;
  INSERT INTO public.audit_log(church_id,actor,action,entity,entity_id,details) VALUES(v_church,auth.uid(),'developer_support_requested','platform_support_request',v_id::text,jsonb_build_object('scope',p_scope));
  RETURN v_id;
END $$;

-- F. Church admin explicitly approves a maximum 24-hour read-only access window.
CREATE OR REPLACE FUNCTION public.kt_approve_developer_support(p_request_id uuid,p_duration_hours integer DEFAULT 4)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='pg_catalog','public' AS $$
DECLARE v_req public.platform_support_requests%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL OR NOT public.kt_can_manage() THEN RAISE EXCEPTION 'Church administrator permission required.'; END IF;
  IF p_duration_hours NOT BETWEEN 1 AND 24 THEN RAISE EXCEPTION 'Access duration must be between 1 and 24 hours.'; END IF;
  SELECT * INTO v_req FROM public.platform_support_requests WHERE id=p_request_id AND church_id=public.kt_church_id() FOR UPDATE;
  IF v_req.id IS NULL OR v_req.status NOT IN ('pending','expired') THEN RAISE EXCEPTION 'Support request is unavailable or already processed.'; END IF;
  UPDATE public.platform_support_requests SET status='approved',approved_by=auth.uid(),approved_at=now(),expires_at=now()+make_interval(hours=>p_duration_hours),revoked_by=NULL,revoked_at=NULL WHERE id=p_request_id;
  INSERT INTO public.audit_log(church_id,actor,action,entity,entity_id,details) VALUES(v_req.church_id,auth.uid(),'developer_support_approved','platform_support_request',p_request_id::text,jsonb_build_object('scope',v_req.scope,'duration_hours',p_duration_hours));
END $$;


-- Church administrator can see only support requests belonging to its own church.
CREATE OR REPLACE FUNCTION public.kt_list_my_support_requests()
RETURNS TABLE(id uuid,reason text,scope text,status text,requested_at timestamptz,expires_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path='pg_catalog','public' AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT public.kt_can_manage() THEN RAISE EXCEPTION 'Church administrator permission required.'; END IF;
  RETURN QUERY SELECT r.id,r.reason,r.scope,r.status,r.requested_at,r.expires_at
    FROM public.platform_support_requests r WHERE r.church_id=public.kt_church_id()
    ORDER BY r.requested_at DESC LIMIT 30;
END $$;

-- G. Church admin can revoke its own grant at any time.
CREATE OR REPLACE FUNCTION public.kt_revoke_developer_support(p_request_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='pg_catalog','public' AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT public.kt_can_manage() THEN RAISE EXCEPTION 'Church administrator permission required.'; END IF;
  UPDATE public.platform_support_requests SET status='revoked',revoked_by=auth.uid(),revoked_at=now()
   WHERE id=p_request_id AND church_id=public.kt_church_id() AND status='approved';
  IF NOT FOUND THEN RAISE EXCEPTION 'No active support grant found for this church.'; END IF;
  INSERT INTO public.audit_log(church_id,actor,action,entity,entity_id,details) VALUES(public.kt_church_id(),auth.uid(),'developer_support_revoked','platform_support_request',p_request_id::text,'{}'::jsonb);
END $$;

-- H. Developer-only aggregate overview: no church names, member identities, donors or per-church rows.
CREATE OR REPLACE FUNCTION public.kt_developer_platform_overview()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='pg_catalog','public' AS $$
DECLARE v_result jsonb;
BEGIN
  IF auth.uid() IS NULL OR lower(COALESCE(auth.jwt()->>'email','')) <> lower('tongaigodfreymapiye@gmail.com') OR NOT public.kt_is_developer() THEN
    RAISE EXCEPTION 'Reserved developer access required.';
  END IF;
  SELECT jsonb_build_object(
    'church_count',(SELECT count(*) FROM public.churches),
    'branch_count',(SELECT count(*) FROM public.branches),
    'active_subscriptions',(SELECT count(*) FROM public.subscriptions WHERE status='active'),
    'pending_support_requests',(SELECT count(*) FROM public.platform_support_requests WHERE status='pending'),
    'user_count',(SELECT count(*) FROM public.profiles),
    'member_count',(SELECT count(*) FROM public.members),
    'transaction_count',(SELECT count(*) FROM public.financial_transactions WHERE status='posted'),
    'financial_detail_suppressed',(SELECT count(*) FROM public.churches)<5,
    'monthly_activity',COALESCE((
      SELECT jsonb_agg(jsonb_build_object('month',mth,'currency',currency,'income',income,'expense',expense) ORDER BY mth,currency)
      FROM (
        SELECT to_char(date_trunc('month',transaction_date),'YYYY-MM') AS mth,currency,
          sum(amount) FILTER(WHERE direction='income') AS income,
          sum(amount) FILTER(WHERE direction='expense') AS expense
        FROM public.financial_transactions WHERE status='posted' AND transaction_date>=current_date-interval '12 months'
        GROUP BY 1,currency HAVING count(DISTINCT church_id)>=5
      ) q
    ),'[]'::jsonb)
  ) INTO v_result;
  RETURN v_result;
END $$;

REVOKE ALL ON FUNCTION public.kt_request_developer_support(text,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.kt_approve_developer_support(uuid,integer) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.kt_revoke_developer_support(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.kt_list_my_support_requests() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.kt_developer_platform_overview() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.kt_request_developer_support(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.kt_approve_developer_support(uuid,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.kt_revoke_developer_support(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.kt_list_my_support_requests() TO authenticated;
GRANT EXECUTE ON FUNCTION public.kt_developer_platform_overview() TO authenticated;

COMMIT;

-- Verify home church and permanent developer entitlement.
SELECT u.email,p.role,c.name AS home_church,b.name AS home_branch,s.plan,s.status,s.expires_at
FROM auth.users u JOIN public.profiles p ON p.id=u.id
LEFT JOIN public.churches c ON c.id=p.church_id
LEFT JOIN public.branches b ON b.id=p.branch_id
LEFT JOIN public.subscriptions s ON s.church_id=p.church_id
WHERE lower(u.email)=lower('tongaigodfreymapiye@gmail.com');
