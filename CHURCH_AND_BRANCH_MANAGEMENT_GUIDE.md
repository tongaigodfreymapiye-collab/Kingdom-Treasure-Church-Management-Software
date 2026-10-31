# Church and Branch Management Update

## What this update changes

- Adds a **Church organisations** register to Platform administration.
- Adds a secure **Add church** workflow for the verified platform developer.
- Creates a church and its first branch in one database transaction.
- Creates a free subscription record and a standard starter chart of accounts for each newly registered church.
- Captures organisation name, first branch, country, base currency, contact email, phone, city, address, website and registration number.
- Adds a branch form with branch name, email, phone, address, city and country.
- Replaces the empty member branch selector with an explicit branch requirement and prevents saving a member without selecting a valid active branch.
- Loads church and branch financial records only when a church workspace is active; the developer platform overview does not preload other churches' finance data.

## Important permissions boundary

The developer can register church organisations and see their basic directory details. Registering a church does **not** grant the developer unrestricted access to that church's member records, donations, expenses or reports. Those records remain protected by the church's own tenant-level RLS policies. CFMI remains the developer's home church and the developer retains the developer role plus administrator capabilities inside CFMI.

Creating a church does not create a login for its church administrator or send an invitation. That is a separate onboarding action and must be completed using a verified administrator invitation workflow.

## Deployment order

1. Back up the live Supabase project.
2. If the developer is not already linked to CFMI/Main Branch, run `DEVELOPER_CFMI_ADMIN_ACCESS_MIGRATION.sql` once.
3. Run `CHURCH_AND_BRANCH_MANAGEMENT_MIGRATION.sql` in Supabase SQL Editor. This is an additive migration for the existing database. **Do not run `KINGDOM_TREASURE_FIRST_INSTALL.sql`.**
4. Check the verification query at the bottom of the migration. The developer should still show role `developer`, church `Consuming Fire Ministries International`, branch `Main Branch`, and lifetime active entitlement.
5. Publish the updated `index.html` and related project files to GitHub Pages.
6. Sign in, open Platform administration, register a test church, then open CFMI Church branches and confirm that its Main Branch appears in the member form.

## Troubleshooting the branch dropdown

The member form requires at least one active branch for the current church. If the list is empty:

- Confirm the signed-in profile has the CFMI `church_id` and Main Branch `branch_id`.
- Confirm the Main Branch exists in `public.branches` for the same church ID.
- Confirm the CFMI administrator migration and this branch-management migration completed successfully.
- Use Refresh after the migration. Do not insert branch rows manually or disable RLS to work around the issue.

## Data and safety notes

- Church currency is stored as a three-letter currency code.
- Church and branch names are required; contact details are optional.
- Duplicate church names (case-insensitive) are rejected by the registration RPC.
- The create-church RPC is `SECURITY DEFINER` and checks the verified developer identity server-side.
- The create-branch RPC checks the authenticated user's church administrator permission and the church's subscription entitlement.
- No existing church, member, transaction, budget or journal data is deleted or rewritten by this migration.
