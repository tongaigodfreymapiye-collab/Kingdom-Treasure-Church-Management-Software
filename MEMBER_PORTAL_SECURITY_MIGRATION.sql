-- Kingdom Treasure member portal security migration
-- Run AFTER supabase_schema.sql in the Supabase SQL Editor.
-- Members are mapped to one existing member-directory record by an administrator.
alter table public.members
  add column if not exists auth_user_id uuid unique references auth.users(id) on delete set null;

create or replace function public.kt_member_id()
returns uuid language sql stable security definer set search_path=public as $$
  select id from public.members
  where auth_user_id=auth.uid()
    and church_id=public.kt_church_id()
  limit 1
$$;

-- A member can update only their own contact details through this narrow RPC.
create or replace function public.kt_update_my_member_contact(p_email text, p_phone text)
returns void language plpgsql security definer set search_path=public as $$
begin
  if public.kt_role() <> 'member' then
    raise exception 'This action is only available to church members';
  end if;
  update public.members
     set email=nullif(trim(p_email),''),
         phone=nullif(trim(p_phone),'')
   where auth_user_id=auth.uid()
     and church_id=public.kt_church_id();
  if not found then
    raise exception 'Your login is not linked to a membership record';
  end if;
end $$;
revoke all on function public.kt_update_my_member_contact(text,text) from public;
grant execute on function public.kt_update_my_member_contact(text,text) to authenticated;

-- Only church administrators (or the platform developer) may link a church user
-- to an existing membership record. Both records must belong to the same church.
create or replace function public.kt_link_member_profile(p_profile_id uuid, p_member_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_profile public.profiles%rowtype; v_member public.members%rowtype;
begin
  if not (public.kt_can_manage() or public.kt_is_developer()) then
    raise exception 'Only a church administrator can link membership accounts';
  end if;
  select * into v_profile from public.profiles where id=p_profile_id;
  select * into v_member from public.members where id=p_member_id;
  if v_profile.id is null or v_member.id is null
     or v_profile.church_id is distinct from public.kt_church_id()
     or v_member.church_id is distinct from public.kt_church_id()
     or v_profile.role <> 'member' then
    raise exception 'The selected profile and member record must belong to this church and the profile must have the Member role';
  end if;
  if v_member.auth_user_id is not null and v_member.auth_user_id <> p_profile_id then
    raise exception 'This membership record is already linked to another login';
  end if;
  update public.members set auth_user_id=p_profile_id where id=p_member_id;
end $$;
revoke all on function public.kt_link_member_profile(uuid,uuid) from public;
grant execute on function public.kt_link_member_profile(uuid,uuid) to authenticated;

-- Restrictive policies combine with existing policies (rather than accidentally
-- widening access). Member accounts see only their own member record, own giving,
-- and own pledges. Management/finance roles retain existing permissions.
drop policy if exists kt_member_guard_members on public.members;
create policy kt_member_guard_members on public.members as restrictive
for select to authenticated
using (public.kt_role() <> 'member' or auth_user_id=auth.uid());

drop policy if exists kt_member_guard_transactions on public.financial_transactions;
create policy kt_member_guard_transactions on public.financial_transactions as restrictive
for select to authenticated
using (
  public.kt_role() <> 'member'
  or (direction='income' and member_id=public.kt_member_id() and status='posted')
);

drop policy if exists kt_member_guard_pledges on public.pledges;
create policy kt_member_guard_pledges on public.pledges as restrictive
for select to authenticated
using (public.kt_role() <> 'member' or member_id=public.kt_member_id());

drop policy if exists kt_member_guard_profiles on public.profiles;
create policy kt_member_guard_profiles on public.profiles as restrictive
for select to authenticated
using (public.kt_role() <> 'member' or id=auth.uid());

-- Prevent members from reading management accounting data directly through the API.
drop policy if exists kt_member_guard_accounts on public.accounts;
create policy kt_member_guard_accounts on public.accounts as restrictive
for select to authenticated
using (public.kt_role() <> 'member');

drop policy if exists kt_member_guard_journal_entries on public.journal_entries;
create policy kt_member_guard_journal_entries on public.journal_entries as restrictive
for select to authenticated
using (public.kt_role() <> 'member');

drop policy if exists kt_member_guard_journal_lines on public.journal_lines;
create policy kt_member_guard_journal_lines on public.journal_lines as restrictive
for select to authenticated
using (public.kt_role() <> 'member');

drop policy if exists kt_member_guard_budgets on public.budgets;
create policy kt_member_guard_budgets on public.budgets as restrictive
for select to authenticated
using (public.kt_role() <> 'member');

drop policy if exists kt_member_guard_departments on public.departments;
create policy kt_member_guard_departments on public.departments as restrictive
for select to authenticated
using (public.kt_role() <> 'member');

-- Members must not read church-wide subscription requests or invitations.
drop policy if exists kt_member_guard_subscriptions on public.subscriptions;
create policy kt_member_guard_subscriptions on public.subscriptions as restrictive
for select to authenticated
using (public.kt_role() <> 'member');

drop policy if exists kt_member_guard_subscription_requests on public.subscription_requests;
create policy kt_member_guard_subscription_requests on public.subscription_requests as restrictive
for select to authenticated
using (public.kt_role() <> 'member');

drop policy if exists kt_member_guard_invitations on public.church_invitations;
create policy kt_member_guard_invitations on public.church_invitations as restrictive
for select to authenticated
using (public.kt_role() <> 'member');
