-- Kingdom Treasure: grant the reserved platform developer full administrator
-- privileges inside Consuming Fire Ministries International (CFMI), while
-- preserving the separate platform developer identity.
-- Run this targeted migration in Supabase SQL Editor after taking a backup.
-- It does not reset data, alter credentials, or change the developer role.

BEGIN;

DO $$
DECLARE
  v_user_id uuid;
  v_church_id uuid;
  v_branch_id uuid;
BEGIN
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE lower(email) = lower('tongaigodfreymapiye@gmail.com')
    AND email_confirmed_at IS NOT NULL
  LIMIT 1;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Verified reserved developer account not found.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = v_user_id AND role = 'developer'
  ) THEN
    RAISE EXCEPTION 'Reserved account is not marked as developer; refusing to change roles.';
  END IF;

  SELECT id INTO v_church_id
  FROM public.churches
  WHERE lower(trim(name)) = lower('Consuming Fire Ministries International')
  ORDER BY created_at
  LIMIT 1;

  IF v_church_id IS NULL THEN
    INSERT INTO public.churches(name, currency, country)
    VALUES ('Consuming Fire Ministries International', 'USD', 'Zimbabwe')
    RETURNING id INTO v_church_id;
  END IF;

  SELECT id INTO v_branch_id
  FROM public.branches
  WHERE church_id = v_church_id
    AND lower(trim(name)) = lower('Main Branch')
  LIMIT 1;

  IF v_branch_id IS NULL THEN
    INSERT INTO public.branches(church_id, name, active)
    VALUES (v_church_id, 'Main Branch', true)
    RETURNING id INTO v_branch_id;
  END IF;

  UPDATE public.profiles
  SET church_id = v_church_id,
      branch_id = v_branch_id,
      full_name = COALESCE(NULLIF(full_name, ''), 'Tongai Godfrey Mapiye'),
      role = 'developer'
  WHERE id = v_user_id;

  INSERT INTO public.subscriptions(church_id, plan, status, started_at, expires_at, extra_branch_slots, updated_at)
  VALUES (v_church_id, 'lifetime', 'active', now(), NULL, 0, now())
  ON CONFLICT (church_id) DO UPDATE
  SET plan = 'lifetime', status = 'active', expires_at = NULL,
      updated_at = now();
END $$;

-- In the developer's own CFMI workspace, treat the developer as a church
-- administrator across all CFMI branches. This does NOT grant access to any
-- other church because every check is constrained to the developer's home church.
CREATE OR REPLACE FUNCTION public.kt_can_see_branch(p_branch_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = 'pg_catalog', 'public'
AS $$
  SELECT COALESCE(EXISTS (
    SELECT 1
    FROM public.profiles p
    JOIN public.branches b ON b.id = p_branch_id
    WHERE p.id = auth.uid()
      AND b.church_id = p.church_id
      AND (
        p.role = 'church_admin'
        OR p.role = 'developer'
        OR b.id = p.branch_id
      )
  ), false)
$$;

-- Allow the developer to use the same branch-management action within CFMI.
-- Lifetime subscription entitlement is checked below, just as for an admin.
CREATE OR REPLACE FUNCTION public.kt_create_branch(p_name text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  cid uuid;
  sub public.subscriptions;
  n integer;
  bid uuid;
BEGIN
  IF NOT public.kt_can_manage() THEN
    RAISE EXCEPTION 'Church administrator permission required';
  END IF;
  cid := public.kt_church_id();
  IF cid IS NULL THEN RAISE EXCEPTION 'Developer home church is not configured'; END IF;
  SELECT * INTO sub FROM public.subscriptions WHERE church_id = cid FOR UPDATE;
  SELECT count(*) INTO n FROM public.branches WHERE church_id = cid AND active;
  IF sub.plan = 'lifetime' AND sub.status = 'active' THEN
    NULL;
  ELSIF n < 1 + sub.extra_branch_slots AND sub.status = 'active'
    AND (sub.plan = 'lifetime' OR sub.expires_at IS NULL OR sub.expires_at > now()) THEN
    NULL;
  ELSE
    RAISE EXCEPTION 'Additional branch subscription required';
  END IF;
  INSERT INTO public.branches(church_id, name)
  VALUES (cid, trim(p_name)) RETURNING id INTO bid;
  RETURN bid;
END;
$$;

COMMIT;

-- Verify the reserved developer remains a developer and is linked to CFMI/Main Branch.
SELECT p.id, u.email, p.role, c.name AS church, b.name AS branch,
       s.plan, s.status
FROM public.profiles p
JOIN auth.users u ON u.id = p.id
LEFT JOIN public.churches c ON c.id = p.church_id
LEFT JOIN public.branches b ON b.id = p.branch_id
LEFT JOIN public.subscriptions s ON s.church_id = p.church_id
WHERE lower(u.email) = lower('tongaigodfreymapiye@gmail.com');
