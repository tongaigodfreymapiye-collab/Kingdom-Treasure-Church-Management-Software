# Kingdom Treasure — Access Control Notes

The current package uses Supabase Auth and PostgreSQL Row Level Security. It no longer treats browser-local role values as a security boundary.

## Reserved platform developer
- Exact email: `tongaigodfreymapiye@gmail.com`.
- The database bootstrap trigger creates the reserved profile.
- Developer privileges are promoted only after Supabase confirms ownership of the mailbox.
- Church administrators cannot invite this address into a church or grant the developer role.
- Developer access is separate from every church organisation and is not controlled by a church subscription.
- Require MFA and protect the mailbox.

## Church roles
- `church_admin`: manages their church organisation, branch administration, users/invitations, budgets and financial records.
- `treasurer`: maintains financial records for their assigned branch and records pledge payments.
- `pastor`: read-only financial/member access for their assigned branch.
- `department_leader`: assigned branch-level access; department-specific permissions can be expanded.
- `member`: basic church directory and read access.

A church administrator can invite another church administrator, Treasurer, Pastor, Department Leader or Member. The Edge Function validates the caller, organisation and branch, creates a time-limited invitation token, and sends the invitation using Supabase Auth Admin API. The database trigger validates the token before attaching the invited account to the correct church and branch.

## Security boundaries
- No browser-side role assignment.
- No service-role key in the front end.
- Row Level Security separates church tenants and assigned branches.
- Subscription activation RPC is restricted to the reserved developer identity.
- Branch creation is checked in a database function against active branch entitlements.
- Posted transactions create balanced journal entries and an audit record.
- Pledge payments update the pledge and create a donation transaction atomically.

See `supabase_schema.sql` and `DEPLOYMENT_GUIDE.md` for implementation and setup.


## Member Portal permissions
Members have a dedicated portal, not the finance or church-management dashboard. They can:
- View their own membership details and membership number.
- Update only their own contact email and phone.
- View their own posted giving history and pledge balances.
- Download a personal giving statement PDF.

An administrator must link the member login to the corresponding `members` row using the **Link member** action. The database migration adds `members.auth_user_id`, a unique account link, narrow RPCs, and restrictive RLS policies. Members cannot query other members' giving, church-wide transactions, budgets, accounts, journal entries, invitations, or subscription requests.

Explicitly excluded from the member portal: events/services, attendance registration, ministry joining, announcements, church programme access, prayer requests, SMS/email/WhatsApp announcements, pastoral appointment requests, testimonies, and feedback submissions.
