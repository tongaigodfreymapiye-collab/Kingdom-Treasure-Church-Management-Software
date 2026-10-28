-- Kingdom Treasure production schema starter for Supabase/PostgreSQL.
-- Apply only after reviewing with a qualified developer. Never expose the service_role key in the browser.
create extension if not exists pgcrypto;

create type public.kt_role as enum ('Admin','Treasurer','Pastor');
create type public.kt_request_status as enum ('Pending Pastoral Approval','Approved','Rejected','Paid');

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role public.kt_role not null default 'Pastor',
  assembly_id uuid,
  created_at timestamptz not null default now()
);

create table if not exists public.assemblies (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.profiles drop constraint if exists profiles_assembly_id_fkey;
alter table public.profiles add constraint profiles_assembly_id_fkey foreign key (assembly_id) references public.assemblies(id);

-- Enforce maximum of three Treasurers in the database, not just the interface.
create or replace function public.kt_enforce_treasurer_limit()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.role='Treasurer' and (tg_op='INSERT' or old.role is distinct from 'Treasurer') then
    if (select count(*) from public.profiles where role='Treasurer' and id<>new.id) >= 3 then
      raise exception 'Maximum of three Treasurer accounts reached';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists kt_treasurer_limit on public.profiles;
create trigger kt_treasurer_limit before insert or update of role on public.profiles
for each row execute function public.kt_enforce_treasurer_limit();

create or replace function public.kt_role()
returns public.kt_role language sql stable security definer set search_path=public as $$
  select role from public.profiles where id=auth.uid()
$$;
create or replace function public.kt_is_pastor()
returns boolean language sql stable security definer set search_path=public as $$
  select coalesce(public.kt_role()='Pastor',false)
$$;
create or replace function public.kt_is_admin_or_treasurer()
returns boolean language sql stable security definer set search_path=public as $$
  select coalesce(public.kt_role() in ('Admin','Treasurer'),false)
$$;

create table if not exists public.financial_records (
  id uuid primary key default gen_random_uuid(),
  assembly_id uuid not null references public.assemblies(id),
  direction text not null check(direction in ('Income','Expense')),
  transaction_date date not null,
  category text not null,
  description text,
  amount numeric(14,2) not null check(amount>=0),
  currency char(3) not null,
  exchange_rate numeric(16,6) not null default 1 check(exchange_rate>0),
  payment_method text,
  payment_status text not null default 'Posted',
  reference text,
  source_file text,
  source_sheet text,
  source_row integer,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.payment_requests (
  id uuid primary key default gen_random_uuid(),
  assembly_id uuid not null references public.assemblies(id),
  requested_by uuid not null references auth.users(id),
  description text not null,
  payee text not null,
  amount numeric(14,2) not null check(amount>0),
  currency char(3) not null,
  notes text,
  status public.kt_request_status not null default 'Pending Pastoral Approval',
  decided_by uuid references auth.users(id),
  decided_at timestamptz,
  created_at timestamptz not null default now(),
  check(status not in ('Approved','Rejected','Paid') or decided_by is not null)
);

create table if not exists public.pastor_payroll (
  id uuid primary key default gen_random_uuid(),
  assembly_id uuid not null references public.assemblies(id),
  pastor_user_id uuid references auth.users(id),
  pastor_name text not null,
  pastor_email text,
  period date not null,
  payment_date date,
  currency char(3) not null default 'USD',
  basic_salary numeric(14,2) not null default 0,
  housing_allowance numeric(14,2) not null default 0,
  transport_allowance numeric(14,2) not null default 0,
  health_insurance numeric(14,2) not null default 0,
  paye numeric(14,2) not null default 0,
  aids_levy numeric(14,2) not null default 0,
  employee_nssa numeric(14,2) not null default 0,
  employer_nssa numeric(14,2) not null default 0,
  tithe_deduction numeric(14,2) not null default 0,
  net_pay numeric(14,2) not null default 0,
  status public.kt_request_status not null default 'Pending Pastoral Approval',
  created_by uuid references auth.users(id),
  approved_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

-- Highly sensitive data: access only through protected server functions and approved finance workflows.
create table if not exists public.pastor_bank_details (
  id uuid primary key default gen_random_uuid(),
  payroll_profile_id uuid not null references public.pastor_payroll(id) on delete cascade,
  bank_name text not null,
  account_holder text not null,
  account_number_encrypted bytea not null,
  bank_code text,
  created_at timestamptz not null default now()
);

create table if not exists public.audit_log (
  id bigint generated always as identity primary key,
  actor uuid references auth.users(id),
  action text not null,
  entity_type text not null,
  entity_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.assemblies enable row level security;
alter table public.financial_records enable row level security;
alter table public.payment_requests enable row level security;
alter table public.pastor_payroll enable row level security;
alter table public.pastor_bank_details enable row level security;
alter table public.audit_log enable row level security;

-- Read access for authenticated users; assembly scoping should be enforced by server-side policies in a multi-assembly deployment.
create policy "profiles read authenticated" on public.profiles for select to authenticated using (true);
create policy "assemblies read authenticated" on public.assemblies for select to authenticated using (true);
create policy "records read authenticated" on public.financial_records for select to authenticated using (true);
create policy "records insert admin treasurer" on public.financial_records for insert to authenticated with check(public.kt_is_admin_or_treasurer());
create policy "records update admin treasurer" on public.financial_records for update to authenticated using(public.kt_is_admin_or_treasurer()) with check(public.kt_is_admin_or_treasurer());
create policy "records delete admin treasurer" on public.financial_records for delete to authenticated using(public.kt_is_admin_or_treasurer());

create policy "payment request read authenticated" on public.payment_requests for select to authenticated using(true);
create policy "treasurer creates own request" on public.payment_requests for insert to authenticated with check(public.kt_role()='Treasurer' and requested_by=auth.uid() and status='Pending Pastoral Approval');
create policy "pastor decides request" on public.payment_requests for update to authenticated
using(public.kt_is_pastor() and status='Pending Pastoral Approval')
with check(public.kt_is_pastor() and status in ('Approved','Rejected') and decided_by=auth.uid());
-- No Treasurer policy can approve, mark paid, or otherwise update a payment request.

create policy "payroll read finance and pastors" on public.pastor_payroll for select to authenticated using(public.kt_role() in ('Admin','Treasurer','Pastor'));
create policy "payroll create finance" on public.pastor_payroll for insert to authenticated with check(public.kt_is_admin_or_treasurer());
create policy "payroll edit finance before approval" on public.pastor_payroll for update to authenticated
using(public.kt_is_admin_or_treasurer() and status='Pending Pastoral Approval')
with check(public.kt_is_admin_or_treasurer() and status='Pending Pastoral Approval');
create policy "bank details finance only" on public.pastor_bank_details for select to authenticated using(public.kt_role() in ('Admin','Treasurer'));
create policy "bank details insert finance" on public.pastor_bank_details for insert to authenticated with check(public.kt_is_admin_or_treasurer());
create policy "audit read admin" on public.audit_log for select to authenticated using(public.kt_role()='Admin');
create policy "audit insert authenticated" on public.audit_log for insert to authenticated with check(actor=auth.uid());

-- IMPORTANT production follow-ups:
-- 1) Add assembly-scope policies using the current profile's assembly_id plus explicit Admin cross-assembly privileges.
-- 2) Never allow browser clients to insert/update profiles.role. Use a trusted Edge Function/admin-only RPC to assign roles.
-- 3) Implement encrypted bank-detail write/read through server-side Edge Functions; do not return raw account numbers to ordinary clients.
-- 4) Add transactional payroll approval/payment workflow and idempotency controls.
-- 5) Schedule monthly/year-end report generation using Supabase Cron/Edge Functions and a verified email provider.
