-- KINGDOM TREASURE: church registration and branch management
-- Safe, additive migration for an EXISTING Supabase project.
-- Back up the project first. Do not run the first-install SQL bundle.
-- Only the reserved, verified platform developer can register new churches.
-- Church administrators (and the developer within the developer's own CFMI home church)
-- can create branches through kt_create_branch.

BEGIN;

-- Add optional organisation contact/profile fields without changing existing records.
ALTER TABLE public.churches
  ADD COLUMN IF NOT EXISTS contact_email text,
  ADD COLUMN IF NOT EXISTS phone text,
  ADD COLUMN IF NOT EXISTS address text,
  ADD COLUMN IF NOT EXISTS city text,
  ADD COLUMN IF NOT EXISTS website text,
  ADD COLUMN IF NOT EXISTS registration_number text;

-- Add optional branch contact/location fields.
ALTER TABLE public.branches
  ADD COLUMN IF NOT EXISTS email text,
  ADD COLUMN IF NOT EXISTS phone text,
  ADD COLUMN IF NOT EXISTS address text,
  ADD COLUMN IF NOT EXISTS city text,
  ADD COLUMN IF NOT EXISTS country text;

-- Ensure the reserved developer can read the organisation directory, but not
-- other churches' accounting records. Existing SELECT policy already limits
-- this policy to basic church rows; RLS on finance tables remains unchanged.

CREATE OR REPLACE FUNCTION public.kt_create_church(
  p_name text,
  p_first_branch text,
  p_country text,
  p_currency text,
  p_contact_email text DEFAULT NULL,
  p_phone text DEFAULT NULL,
  p_city text DEFAULT NULL,
  p_address text DEFAULT NULL,
  p_website text DEFAULT NULL,
  p_registration_number text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_church_id uuid;
  v_branch_id uuid;
  v_currency text;
BEGIN
  IF NOT public.kt_is_developer() THEN
    RAISE EXCEPTION 'Only the verified platform developer can register a church';
  END IF;
  IF NULLIF(trim(p_name), '') IS NULL THEN RAISE EXCEPTION 'Church name is required'; END IF;
  IF NULLIF(trim(p_first_branch), '') IS NULL THEN RAISE EXCEPTION 'First branch name is required'; END IF;
  IF NULLIF(trim(p_country), '') IS NULL THEN RAISE EXCEPTION 'Country is required'; END IF;
  v_currency := upper(trim(coalesce(p_currency, 'USD')));
  IF length(v_currency) <> 3 OR v_currency !~ '^[A-Z]{3}$' THEN
    RAISE EXCEPTION 'Currency must be a three-letter ISO code';
  END IF;
  IF EXISTS (SELECT 1 FROM public.churches WHERE lower(trim(name)) = lower(trim(p_name))) THEN
    RAISE EXCEPTION 'A church with this name is already registered';
  END IF;

  INSERT INTO public.churches(name, currency, country, contact_email, phone, address, city, website, registration_number)
  VALUES (trim(p_name), v_currency, trim(p_country), NULLIF(trim(p_contact_email), ''),
          NULLIF(trim(p_phone), ''), NULLIF(trim(p_address), ''), NULLIF(trim(p_city), ''),
          NULLIF(trim(p_website), ''), NULLIF(trim(p_registration_number), ''))
  RETURNING id INTO v_church_id;

  INSERT INTO public.branches(church_id, name, email, phone, address, city, country)
  VALUES (v_church_id, trim(p_first_branch), NULLIF(trim(p_contact_email), ''),
          NULLIF(trim(p_phone), ''), NULLIF(trim(p_address), ''), NULLIF(trim(p_city), ''), trim(p_country))
  RETURNING id INTO v_branch_id;

  INSERT INTO public.subscriptions(church_id, plan, status, started_at, expires_at)
  VALUES (v_church_id, 'free', 'free', now(), NULL);

  -- Create a standard starter chart of accounts for proper accounting setup.
  INSERT INTO public.accounts(church_id, code, name, account_type, normal_balance) VALUES
    (v_church_id,'1000','Cash and Bank','asset','debit'),
    (v_church_id,'1100','Receivables','asset','debit'),
    (v_church_id,'1500','Property and Equipment','asset','debit'),
    (v_church_id,'2000','Payables','liability','credit'),
    (v_church_id,'3000','Accumulated Funds / Net Assets','net_assets','credit'),
    (v_church_id,'4000','Tithes, Offerings and Donations','income','credit'),
    (v_church_id,'4100','Trading Income','income','credit'),
    (v_church_id,'4200','Other Non-trading Income','income','credit'),
    (v_church_id,'5000','Ministry and Programme Expenses','expense','debit'),
    (v_church_id,'5100','Staff and Pastoral Costs','expense','debit'),
    (v_church_id,'5200','Facilities and Utilities','expense','debit'),
    (v_church_id,'5300','Outreach and Missions','expense','debit');

  RETURN jsonb_build_object('church_id', v_church_id, 'branch_id', v_branch_id,
                            'church_name', trim(p_name), 'branch_name', trim(p_first_branch));
END;
$$;

REVOKE ALL ON FUNCTION public.kt_create_church(text,text,text,text,text,text,text,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kt_create_church(text,text,text,text,text,text,text,text,text,text) TO authenticated;

-- Replace the old one-argument function with a backwards-compatible function
-- that accepts optional branch contact/location details.
DROP FUNCTION IF EXISTS public.kt_create_branch(text);
CREATE FUNCTION public.kt_create_branch(
  p_name text,
  p_email text DEFAULT NULL,
  p_phone text DEFAULT NULL,
  p_address text DEFAULT NULL,
  p_city text DEFAULT NULL,
  p_country text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_church_id uuid;
  v_branch_id uuid;
  v_subscription public.subscriptions;
  v_active_count integer;
BEGIN
  IF NOT public.kt_can_manage() THEN RAISE EXCEPTION 'Church administrator permission required'; END IF;
  v_church_id := public.kt_church_id();
  IF v_church_id IS NULL THEN RAISE EXCEPTION 'Your account is not linked to a church workspace'; END IF;
  IF NULLIF(trim(p_name), '') IS NULL THEN RAISE EXCEPTION 'Branch name is required'; END IF;
  SELECT * INTO v_subscription FROM public.subscriptions WHERE church_id = v_church_id FOR UPDATE;
  SELECT count(*) INTO v_active_count FROM public.branches WHERE church_id = v_church_id AND active;
  IF v_subscription.plan = 'lifetime' AND v_subscription.status = 'active' THEN
    NULL;
  ELSIF v_active_count < 1 + coalesce(v_subscription.extra_branch_slots,0)
    AND v_subscription.status = 'active'
    AND (v_subscription.expires_at IS NULL OR v_subscription.expires_at > now()) THEN
    NULL;
  ELSE
    RAISE EXCEPTION 'Additional branch subscription required';
  END IF;

  INSERT INTO public.branches(church_id, name, email, phone, address, city, country)
  VALUES (v_church_id, trim(p_name), NULLIF(trim(p_email), ''), NULLIF(trim(p_phone), ''),
          NULLIF(trim(p_address), ''), NULLIF(trim(p_city), ''), NULLIF(trim(p_country), ''))
  RETURNING id INTO v_branch_id;
  RETURN v_branch_id;
END;
$$;
REVOKE ALL ON FUNCTION public.kt_create_branch(text,text,text,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kt_create_branch(text,text,text,text,text,text) TO authenticated;

COMMIT;

-- Verification: inspect the CFMI home church, its branches and the developer identity.
SELECT p.role, u.email, c.name AS church_name, b.name AS home_branch,
       s.plan, s.status, count(allb.id) AS total_branches
FROM public.profiles p
JOIN auth.users u ON u.id = p.id
LEFT JOIN public.churches c ON c.id = p.church_id
LEFT JOIN public.branches b ON b.id = p.branch_id
LEFT JOIN public.subscriptions s ON s.church_id = p.church_id
LEFT JOIN public.branches allb ON allb.church_id = p.church_id
WHERE lower(u.email) = lower('tongaigodfreymapiye@gmail.com')
GROUP BY p.role, u.email, c.name, b.name, s.plan, s.status;
