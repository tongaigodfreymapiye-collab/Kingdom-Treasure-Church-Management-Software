-- Kingdom Treasure production schema | Supabase PostgreSQL
-- Apply in Supabase SQL Editor. Never expose service_role credentials in the browser.
create extension if not exists pgcrypto;

create type public.kt_role as enum ('developer','church_admin','treasurer','pastor','department_leader','member');
create type public.kt_plan as enum ('free','annual','lifetime');
create type public.kt_tx_direction as enum ('income','expense');
create type public.kt_tx_status as enum ('draft','posted','void');
create type public.kt_tax_class as enum ('donation','non_trading','trading','other');

create table public.churches(
 id uuid primary key default gen_random_uuid(), name text not null, currency char(3) not null default 'USD',
 country text not null default 'Zimbabwe', created_at timestamptz not null default now()
);
create table public.branches(
 id uuid primary key default gen_random_uuid(), church_id uuid not null references public.churches on delete cascade,
 name text not null, active boolean not null default true, created_at timestamptz not null default now(), unique(church_id,name), unique(id,church_id)
);
create table public.profiles(
 id uuid primary key references auth.users on delete cascade, church_id uuid references public.churches on delete cascade,
 branch_id uuid, full_name text not null default '', role public.kt_role not null default 'member',
 created_at timestamptz not null default now(),
 foreign key(branch_id,church_id) references public.branches(id,church_id)
);
create table public.subscriptions(
 church_id uuid primary key references public.churches on delete cascade, plan public.kt_plan not null default 'free',
 status text not null default 'free' check(status in ('free','active','expired','suspended')),
 started_at timestamptz, expires_at timestamptz, extra_branch_slots integer not null default 0 check(extra_branch_slots>=0),
 updated_at timestamptz not null default now()
);
create table public.church_invitations(
 id uuid primary key default gen_random_uuid(), church_id uuid not null references public.churches on delete cascade,
 branch_id uuid not null, email text not null, role public.kt_role not null check(role in ('church_admin','treasurer','pastor','department_leader','member')),
 token_hash text not null unique, expires_at timestamptz not null, accepted_at timestamptz,
 invited_by uuid references auth.users, created_at timestamptz default now(),
 foreign key(branch_id,church_id) references public.branches(id,church_id)
);
create table public.subscription_requests(
 id uuid primary key default gen_random_uuid(), church_id uuid not null references public.churches on delete cascade,
 requested_by uuid not null references auth.users, requested_plan text not null check(requested_plan in ('annual','lifetime','branch_addon')),
 status text not null default 'pending' check(status in ('pending','approved','rejected')),
 payment_reference text, created_at timestamptz not null default now(), reviewed_at timestamptz
);

create table public.departments(
 id uuid primary key default gen_random_uuid(), church_id uuid not null references public.churches on delete cascade,
 name text not null, description text, created_at timestamptz default now(), unique(church_id,name), unique(id,church_id)
);
create table public.members(
 id uuid primary key default gen_random_uuid(), church_id uuid not null references public.churches on delete cascade,
 branch_id uuid not null, full_name text not null, email text, phone text, member_number text, joined_on date,
 created_at timestamptz default now(), foreign key(branch_id,church_id) references public.branches(id,church_id), unique(id,church_id)
);
create table public.pledges(
 id uuid primary key default gen_random_uuid(), church_id uuid not null references public.churches on delete cascade,
 branch_id uuid not null, member_id uuid, donor_name text not null, purpose text not null, fund text not null default 'General Fund',
 pledged_amount numeric(16,2) not null check(pledged_amount>0), paid_amount numeric(16,2) not null default 0 check(paid_amount>=0),
 currency char(3) not null default 'USD', pledged_on date not null default current_date, due_date date, status text not null default 'open',
 created_at timestamptz default now(), foreign key(branch_id,church_id) references public.branches(id,church_id),
 foreign key(member_id,church_id) references public.members(id,church_id)
);
create table public.accounts(
 id uuid primary key default gen_random_uuid(), church_id uuid not null references public.churches on delete cascade,
 code text not null, name text not null, account_type text not null check(account_type in ('asset','liability','net_assets','income','expense')),
 normal_balance text not null check(normal_balance in ('debit','credit')), active boolean not null default true,
 unique(church_id,code), unique(id,church_id)
);
create table public.financial_transactions(
 id uuid primary key default gen_random_uuid(), church_id uuid not null references public.churches on delete cascade,
 branch_id uuid not null, department_id uuid, member_id uuid, donor_name text, cost_type text check(cost_type in ('fixed','variable','capital')), direction public.kt_tx_direction not null,
 transaction_date date not null, category text not null, description text, amount numeric(16,2) not null check(amount>0),
 currency char(3) not null default 'USD', fund text not null default 'General Fund',
 tax_class public.kt_tax_class not null default 'other', payment_method text, reference text,
 status public.kt_tx_status not null default 'posted', created_by uuid references auth.users,
 created_at timestamptz not null default now(), foreign key(branch_id,church_id) references public.branches(id,church_id),
 foreign key(department_id,church_id) references public.departments(id,church_id), foreign key(member_id,church_id) references public.members(id,church_id), unique(id,church_id)
);
create table public.journal_entries(
 id uuid primary key default gen_random_uuid(), church_id uuid not null references public.churches on delete cascade,
 branch_id uuid not null, entry_date date not null, description text, source_transaction_id uuid,
 created_by uuid references auth.users, created_at timestamptz default now(),
 foreign key(branch_id,church_id) references public.branches(id,church_id), unique(source_transaction_id)
);
create table public.journal_lines(
 id uuid primary key default gen_random_uuid(), church_id uuid not null references public.churches on delete cascade,
 journal_entry_id uuid not null references public.journal_entries on delete cascade, account_id uuid not null,
 debit numeric(16,2) not null default 0 check(debit>=0), credit numeric(16,2) not null default 0 check(credit>=0),
 fund text not null default 'General Fund', department_id uuid, branch_id uuid not null,
 check((debit=0 and credit>0) or (credit=0 and debit>0)),
 foreign key(account_id,church_id) references public.accounts(id,church_id),
 foreign key(branch_id,church_id) references public.branches(id,church_id),
 foreign key(department_id,church_id) references public.departments(id,church_id)
);
create table public.budgets(
 id uuid primary key default gen_random_uuid(), church_id uuid not null references public.churches on delete cascade,
 branch_id uuid not null, department_id uuid, name text not null, cost_type text not null check(cost_type in ('fixed','variable','capital')),
 amount numeric(16,2) not null check(amount>=0), currency char(3) not null default 'USD',
 period_start date not null, period_end date not null, created_at timestamptz default now(),
 check(period_end>=period_start), foreign key(branch_id,church_id) references public.branches(id,church_id),
 foreign key(department_id,church_id) references public.departments(id,church_id)
);
create table public.audit_log(
 id bigint generated always as identity primary key, church_id uuid references public.churches on delete cascade,
 actor uuid references auth.users, action text not null, entity text, entity_id text, details jsonb not null default '{}', created_at timestamptz default now()
);

-- Helpers: all tenant decisions are made from server-side auth.uid() profile.
create or replace function public.kt_church_id() returns uuid language sql stable security definer set search_path=public as $$
 select church_id from public.profiles where id=auth.uid()
$$;
create or replace function public.kt_role() returns public.kt_role language sql stable security definer set search_path=public as $$
 select role from public.profiles where id=auth.uid()
$$;
create or replace function public.kt_is_developer() returns boolean language sql stable security definer set search_path=public as $$
 select coalesce((select p.role='developer' and lower(u.email)='tongaigodfreymapiye@gmail.com'
 from public.profiles as p join auth.users as u on u.id=p.id where p.id=auth.uid()),false)
$$;
create or replace function public.kt_can_manage() returns boolean language sql stable security definer set search_path=public as $$
 select coalesce(public.kt_role() in ('developer','church_admin'),false)
$$;
create or replace function public.kt_can_edit_finance() returns boolean language sql stable security definer set search_path=public as $$
 select coalesce(public.kt_role() in ('developer','church_admin','treasurer'),false)
$$;
create or replace function public.kt_can_see_branch(p_branch_id uuid) returns boolean language sql stable security definer set search_path=public as $$
 select coalesce(public.kt_role() in ('developer','church_admin') or exists(
   select 1 from public.profiles where id=auth.uid() and branch_id=p_branch_id
 ),false)
$$;

-- Signup bootstrap. Only verified ownership of the reserved developer email grants developer role.
create or replace function public.kt_bootstrap_user() returns trigger language plpgsql security definer set search_path=public as $$
declare cid uuid; bid uuid; nm text; bn text; inv public.church_invitations; rawtoken text;
begin
 if lower(new.email)='tongaigodfreymapiye@gmail.com' then
   if new.email_confirmed_at is not null then
     insert into public.profiles(id,full_name,role) values(new.id,coalesce(new.raw_user_meta_data->>'full_name','Tongai Godfrey Mapiye'),'developer');
   else
     insert into public.profiles(id,full_name,role) values(new.id,coalesce(new.raw_user_meta_data->>'full_name','Tongai Godfrey Mapiye'),'member');
   end if;
 elsif coalesce(new.raw_user_meta_data->>'kt_invite_token','')<>'' then
   rawtoken:=new.raw_user_meta_data->>'kt_invite_token';
   select * into inv from public.church_invitations where token_hash=encode(digest(rawtoken,'sha256'),'hex')
     and lower(email)=lower(new.email) and accepted_at is null and expires_at>now() for update;
   if inv.id is null then raise exception 'Invalid or expired church invitation'; end if;
   insert into public.profiles(id,church_id,branch_id,full_name,role)
   values(new.id,inv.church_id,inv.branch_id,coalesce(new.raw_user_meta_data->>'full_name','Church User'),inv.role);
   update public.church_invitations set accepted_at=now() where id=inv.id;
 else
   nm:=coalesce(nullif(new.raw_user_meta_data->>'church_name',''),'My Church');
   bn:=coalesce(nullif(new.raw_user_meta_data->>'branch_name',''),'Main Branch');
   insert into public.churches(name) values(nm) returning id into cid;
   insert into public.branches(church_id,name) values(cid,bn) returning id into bid;
   insert into public.profiles(id,church_id,branch_id,full_name,role)
   values(new.id,cid,bid,coalesce(new.raw_user_meta_data->>'full_name','Church Administrator'),'church_admin');
   insert into public.subscriptions(church_id,plan,status) values(cid,'free','free');
   insert into public.accounts(church_id,code,name,account_type,normal_balance) values
    (cid,'1000','Cash and Bank','asset','debit'),(cid,'1100','Receivables','asset','debit'),
    (cid,'1500','Property and Equipment','asset','debit'),(cid,'2000','Payables','liability','credit'),
    (cid,'3000','Accumulated Funds / Net Assets','net_assets','credit'),
    (cid,'4000','Tithes, Offerings and Donations','income','credit'),
    (cid,'4100','Trading Income','income','credit'),(cid,'4200','Other Non-trading Income','income','credit'),
    (cid,'5000','Ministry and Programme Expenses','expense','debit'),
    (cid,'5100','Staff and Pastoral Costs','expense','debit'),(cid,'5200','Facilities and Utilities','expense','debit'),
    (cid,'5300','Outreach and Missions','expense','debit');
 end if;
 return new;
end $$;
drop trigger if exists kt_auth_user_bootstrap on auth.users;
create trigger kt_auth_user_bootstrap after insert on auth.users for each row execute function public.kt_bootstrap_user();

-- Reserved developer access is promoted only after Supabase confirms mailbox ownership.
create or replace function public.kt_promote_reserved_developer() returns trigger language plpgsql security definer set search_path=public as $$
begin
 if lower(new.email)='tongaigodfreymapiye@gmail.com' and new.email_confirmed_at is not null
    and old.email_confirmed_at is null then
   update public.profiles set role='developer',church_id=null,branch_id=null where id=new.id;
 end if;
 return new;
end $$;
drop trigger if exists kt_reserved_developer_verified on auth.users;
create trigger kt_reserved_developer_verified after update of email_confirmed_at on auth.users
for each row execute function public.kt_promote_reserved_developer();

-- Subscription gates and branch allowance. Annual plan covers the primary branch; add-ons are explicit.
create or replace function public.kt_create_branch(p_name text) returns uuid language plpgsql security definer set search_path=public as $$
declare cid uuid; sub public.subscriptions; n integer; bid uuid;
begin
 if not public.kt_can_manage() or public.kt_role()='developer' then raise exception 'Church administrator permission required'; end if;
 cid:=public.kt_church_id(); select * into sub from public.subscriptions where church_id=cid for update;
 select count(*) into n from public.branches where church_id=cid and active;
 if sub.plan='lifetime' and sub.status='active' then null;
 elsif n < 1+sub.extra_branch_slots and sub.status='active'
   and (sub.plan='lifetime' or sub.expires_at is null or sub.expires_at>now()) then null;
 else raise exception 'Additional branch subscription required'; end if;
 insert into public.branches(church_id,name) values(cid,trim(p_name)) returning id into bid; return bid;
end $$;

create or replace function public.kt_activate_subscription(p_request_id uuid,p_church_id uuid,p_plan text,p_expires_at timestamptz default null)
returns void language plpgsql security definer set search_path=public as $$
declare rq public.subscription_requests;
begin
 if not public.kt_is_developer() then raise exception 'Developer only'; end if;
 select * into rq from public.subscription_requests where id=p_request_id and church_id=p_church_id for update;
 if rq.id is null or rq.status<>'pending' then raise exception 'Request not found or already reviewed'; end if;
 if p_plan='branch_addon' then
   update public.subscriptions set extra_branch_slots=extra_branch_slots+1,status='active',updated_at=now() where church_id=p_church_id;
 else
   update public.subscriptions set plan=p_plan::public.kt_plan,status='active',started_at=now(),expires_at=p_expires_at,updated_at=now() where church_id=p_church_id;
 end if;
 update public.subscription_requests set status='approved',reviewed_at=now() where id=p_request_id;
end $$;

-- Post every posted transaction to a balanced two-line journal entry.
create or replace function public.kt_post_transaction() returns trigger language plpgsql security definer set search_path=public as $$
declare cashid uuid; incomeid uuid; expenseid uuid; jeid uuid; targetid uuid; fundname text;
begin
 if new.status<>'posted' or (tg_op='UPDATE' and old.status='posted') then return new; end if;
 select id into cashid from public.accounts where church_id=new.church_id and code='1000';
 if new.direction='income' then
   targetid:=case when new.tax_class='trading' then (select id from public.accounts where church_id=new.church_id and code='4100')
     when new.tax_class='donation' then (select id from public.accounts where church_id=new.church_id and code='4000')
     else (select id from public.accounts where church_id=new.church_id and code='4200') end;
   insert into public.journal_entries(church_id,branch_id,entry_date,description,source_transaction_id,created_by)
   values(new.church_id,new.branch_id,new.transaction_date,coalesce(new.description,new.category),new.id,new.created_by) returning id into jeid;
   insert into public.journal_lines(church_id,journal_entry_id,account_id,debit,credit,fund,department_id,branch_id)
   values(new.church_id,jeid,cashid,new.amount,0,new.fund,new.department_id,new.branch_id),
         (new.church_id,jeid,targetid,0,new.amount,new.fund,new.department_id,new.branch_id);
 else
   targetid:=case when lower(new.category) like '%salary%' then (select id from public.accounts where church_id=new.church_id and code='5100')
     when lower(new.category) like '%rent%' or lower(new.category) like '%utilit%' or lower(new.category) like '%facilit%' then (select id from public.accounts where church_id=new.church_id and code='5200')
     when lower(new.category) like '%mission%' or lower(new.category) like '%outreach%' then (select id from public.accounts where church_id=new.church_id and code='5300')
     else (select id from public.accounts where church_id=new.church_id and code='5000') end;
   insert into public.journal_entries(church_id,branch_id,entry_date,description,source_transaction_id,created_by)
   values(new.church_id,new.branch_id,new.transaction_date,coalesce(new.description,new.category),new.id,new.created_by) returning id into jeid;
   insert into public.journal_lines(church_id,journal_entry_id,account_id,debit,credit,fund,department_id,branch_id)
   values(new.church_id,jeid,targetid,new.amount,0,new.fund,new.department_id,new.branch_id),
         (new.church_id,jeid,cashid,0,new.amount,new.fund,new.department_id,new.branch_id);
 end if;
 return new;
end $$;
create trigger kt_financial_post after insert or update of status on public.financial_transactions for each row execute function public.kt_post_transaction();

create or replace function public.kt_record_pledge_payment(p_pledge_id uuid,p_amount numeric,p_date date,p_method text default 'Cash')
returns uuid language plpgsql security definer set search_path=public as $$
declare p public.pledges; txid uuid; paid numeric;
begin
 if not public.kt_can_edit_finance() then raise exception 'Finance permission required'; end if;
 select * into p from public.pledges where id=p_pledge_id and church_id=public.kt_church_id() and public.kt_can_see_branch(branch_id) for update;
 if p.id is null then raise exception 'Pledge not found'; end if;
 if p_amount<=0 or p_amount>p.pledged_amount-p.paid_amount then raise exception 'Payment must be positive and cannot exceed the outstanding pledge'; end if;
 update public.pledges set paid_amount=paid_amount+p_amount,
   status=case when paid_amount+p_amount>=pledged_amount then 'fulfilled' else 'part-paid' end
 where id=p_pledge_id;
 insert into public.financial_transactions(church_id,branch_id,member_id,donor_name,direction,transaction_date,category,description,amount,currency,fund,tax_class,payment_method,status,created_by)
 values(p.church_id,p.branch_id,p.member_id,p.donor_name,'income',p_date,'Pledge Payment',p.purpose,p_amount,p.currency,p.fund,'donation',p_method,'posted',auth.uid())
 returning id into txid;
 return txid;
end $$;

create or replace function public.kt_audit_financial_transaction() returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into public.audit_log(church_id,actor,action,entity,entity_id,details)
 values(new.church_id,auth.uid(),case when tg_op='INSERT' then 'create' else 'update' end,
 'financial_transaction',new.id::text,jsonb_build_object('direction',new.direction,'amount',new.amount,'currency',new.currency,'status',new.status));
 return new;
end $$;
create trigger kt_financial_audit after insert or update on public.financial_transactions for each row execute function public.kt_audit_financial_transaction();

-- RLS policies
alter table public.churches enable row level security;
alter table public.branches enable row level security;
alter table public.profiles enable row level security;
alter table public.subscriptions enable row level security;
alter table public.subscription_requests enable row level security;
alter table public.church_invitations enable row level security;
alter table public.departments enable row level security;
alter table public.members enable row level security;
alter table public.pledges enable row level security;
alter table public.accounts enable row level security;
alter table public.financial_transactions enable row level security;
alter table public.journal_entries enable row level security;
alter table public.journal_lines enable row level security;
alter table public.budgets enable row level security;
alter table public.audit_log enable row level security;

create policy "church read tenant or developer" on public.churches for select to authenticated using(id=public.kt_church_id() or public.kt_is_developer());
create policy "church update admin" on public.churches for update to authenticated using(id=public.kt_church_id() and public.kt_can_manage()) with check(id=public.kt_church_id() and public.kt_can_manage());
create policy "branch read tenant" on public.branches for select to authenticated using((church_id=public.kt_church_id() and (public.kt_can_manage() or public.kt_can_see_branch(id))) or public.kt_is_developer());
create policy "branch update admin" on public.branches for update to authenticated using(church_id=public.kt_church_id() and public.kt_can_manage()) with check(church_id=public.kt_church_id() and public.kt_can_manage());
create policy "profile read tenant" on public.profiles for select to authenticated using(church_id=public.kt_church_id() or id=auth.uid() or public.kt_is_developer());
create policy "profile update self limited" on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid() and role=public.kt_role() and church_id is not distinct from public.kt_church_id());
create policy "invitations read admin" on public.church_invitations for select to authenticated using(church_id=public.kt_church_id() and public.kt_can_manage() or public.kt_is_developer());
create policy "subscription read" on public.subscriptions for select to authenticated using(church_id=public.kt_church_id() or public.kt_is_developer());
create policy "subscription requests read" on public.subscription_requests for select to authenticated using(church_id=public.kt_church_id() or public.kt_is_developer());
create policy "subscription request create" on public.subscription_requests for insert to authenticated with check(church_id=public.kt_church_id() and requested_by=auth.uid() and public.kt_role()='church_admin');
create policy "departments read tenant" on public.departments for select to authenticated using(church_id=public.kt_church_id());
create policy "departments write finance" on public.departments for all to authenticated using(church_id=public.kt_church_id() and public.kt_can_edit_finance()) with check(church_id=public.kt_church_id() and public.kt_can_edit_finance());
create policy "members read tenant" on public.members for select to authenticated using(church_id=public.kt_church_id() and public.kt_can_see_branch(branch_id));
create policy "members write finance" on public.members for all to authenticated using(church_id=public.kt_church_id() and public.kt_can_edit_finance() and public.kt_can_see_branch(branch_id)) with check(church_id=public.kt_church_id() and public.kt_can_edit_finance() and public.kt_can_see_branch(branch_id));
create policy "pledges read tenant" on public.pledges for select to authenticated using(church_id=public.kt_church_id() and public.kt_can_see_branch(branch_id));
create policy "pledges write finance" on public.pledges for all to authenticated using(church_id=public.kt_church_id() and public.kt_can_edit_finance() and public.kt_can_see_branch(branch_id)) with check(church_id=public.kt_church_id() and public.kt_can_edit_finance() and public.kt_can_see_branch(branch_id));
create policy "accounts read tenant" on public.accounts for select to authenticated using(church_id=public.kt_church_id());
create policy "transactions read tenant" on public.financial_transactions for select to authenticated using(church_id=public.kt_church_id() and public.kt_can_see_branch(branch_id));
create policy "transactions create finance" on public.financial_transactions for insert to authenticated with check(church_id=public.kt_church_id() and public.kt_can_edit_finance() and public.kt_can_see_branch(branch_id) and created_by=auth.uid());
create policy "transactions update finance drafts" on public.financial_transactions for update to authenticated using(church_id=public.kt_church_id() and public.kt_can_edit_finance() and public.kt_can_see_branch(branch_id) and status<>'posted') with check(church_id=public.kt_church_id() and public.kt_can_edit_finance() and public.kt_can_see_branch(branch_id));
create policy "journal read tenant" on public.journal_entries for select to authenticated using(church_id=public.kt_church_id() and public.kt_can_see_branch(branch_id));
create policy "journal lines read tenant" on public.journal_lines for select to authenticated using(church_id=public.kt_church_id() and public.kt_can_see_branch(branch_id));
create policy "budgets read tenant" on public.budgets for select to authenticated using(church_id=public.kt_church_id() and public.kt_can_see_branch(branch_id));
create policy "budgets write finance" on public.budgets for all to authenticated using(church_id=public.kt_church_id() and public.kt_can_edit_finance() and public.kt_can_see_branch(branch_id)) with check(church_id=public.kt_church_id() and public.kt_can_edit_finance() and public.kt_can_see_branch(branch_id));
create policy "audit read admin" on public.audit_log for select to authenticated using(church_id=public.kt_church_id() and public.kt_can_manage() or public.kt_is_developer());
create policy "audit insert own" on public.audit_log for insert to authenticated with check(church_id=public.kt_church_id() and actor=auth.uid());

-- Grants required for authenticated app clients; RLS still governs every row.
grant usage on schema public to authenticated;
grant select,update on public.churches to authenticated;
grant select,update on public.branches to authenticated;
grant select on public.profiles to authenticated;
grant select on public.subscriptions to authenticated;
grant select,insert on public.subscription_requests to authenticated;
grant select on public.church_invitations to authenticated;
grant select,insert,update,delete on public.departments,public.members,public.pledges,public.budgets to authenticated;
grant select on public.accounts,public.journal_entries,public.journal_lines to authenticated;
grant select,insert,update on public.financial_transactions to authenticated;
grant select,insert on public.audit_log to authenticated;
grant execute on function public.kt_create_branch(text) to authenticated;
grant execute on function public.kt_record_pledge_payment(uuid,numeric,date,text) to authenticated;
grant execute on function public.kt_activate_subscription(uuid,uuid,text,timestamptz) to authenticated;

-- Security notes:
-- * Only verified email ownership of the exact reserved developer address receives developer role.
-- * Never expose service_role key. Enable email confirmation, password reset, MFA for developer.
-- * For production invitations, add an Edge Function using Supabase Admin API to invite users and assign
--   roles server-side. Do not let clients write profiles.role or create profiles in another church.
-- * Payment gateway integration is intentionally not simulated. Developer activation must follow verified
--   payment evidence; connect a provider webhook/Edge Function before automated payment fulfilment.
-- * The automated journals are a simple balanced cash-based starter. Add accruals, receivables/payables,
--   bank reconciliation, asset depreciation, opening balances, restricted fund releases, FX revaluation,
--   payroll and formal year-end close before representing reports as audited/statutory accounts.
