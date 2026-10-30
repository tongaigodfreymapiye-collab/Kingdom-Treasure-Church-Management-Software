# Deployment and activation guide

## 1. Supabase project
Create a Supabase project. In **Project Settings → API**, copy:
- Project URL
- anon / publishable public key

Paste them into `config.js`. This public key is safe to expose only because Row Level Security is enabled. Never paste the `service_role` key into `config.js`, `index.html`, GitHub, or any browser-visible file.

## 2. Database
Open **SQL Editor → New query**, paste all of `supabase_schema.sql`, and run it once on a fresh project. It creates:
- Church, branch, profile and subscription tables
- Role and tenant helper functions
- Signup bootstrap trigger
- Invitation validation trigger path
- Financial transaction, chart of accounts, journal entries and journal lines
- Pledge register and atomic pledge payment function
- Budgets, departments, member records and audit trail
- Row Level Security policies

Do not rerun blindly on a live database: this starter is intended for a fresh project. Back up and use migrations for later schema changes.

## 3. Authentication settings
In Supabase → Authentication → URL Configuration:
- Set Site URL to your deployed GitHub Pages URL.
- Add that URL and `http://localhost:8000` to Redirect URLs.
- Enable email confirmations.
- Configure custom SMTP before commercial use so verification, password reset and user invitations are reliably delivered.
- Enable MFA for the developer account.

The first registration with `tongaigodfreymapiye@gmail.com` receives the reserved `developer` role from the database trigger. Verify and control this mailbox. Do not create a church under this developer login. Every other public signup creates a new church, first branch, church administrator profile, free subscription and starter chart of accounts.

## 4. Secure church user invitations
Install the Supabase CLI and link the project, then deploy the Edge Function:
```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase functions deploy invite-user
```
Set function secrets:
```bash
supabase secrets set APP_ORIGIN=https://YOUR-USERNAME.github.io/YOUR-REPOSITORY/
```
The deployed function uses the platform-provided `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` secrets. The service-role key remains server-side only. Test invitations with a second email address and confirm the invited profile joins the correct church and branch.

## 5. GitHub Pages
Commit the contents of this directory to the repository root. In GitHub → Settings → Pages, select the deployment branch and root folder. Wait for deployment, then open the published URL. Keep `config.js` populated with only the public URL and anon/publishable key.

## 6. Commercial activation
The application records subscription requests:
- Free: one branch, basic operations.
- Annual Church: USD $20 per year, one branch, unlimited member/user accounts, advanced reports and PDF/Excel downloads.
- Lifetime Church: USD $200 once-off, unlimited branches and users, permanent entitlement.
- Additional branch: request a branch add-on; the developer approves it after separately agreed payment.

No payment processor was provided. For now, verify payment independently and activate requests from the Developer Console. Before launch, connect a payment provider with signed server-side webhooks and idempotent fulfilment. Never activate plans based only on a client-side success screen. Set prices, currencies, refunds, tax treatment and terms before accepting customers.

## 7. Acceptance test checklist
- [ ] Register a normal test church; confirm a church, first branch, free subscription and accounts are created.
- [ ] Verify email, sign out, sign in and reset password.
- [ ] Register the reserved developer mailbox only when its owner controls the inbox; confirm developer console is visible only to that account.
- [ ] Invite a Treasurer and a Member; confirm each joins the selected church and branch.
- [ ] Try to read another church's IDs with the anon key; RLS must return no rows.
- [ ] Try to create a second branch on Free; database must reject it.
- [ ] Record a posted income and expense; confirm journal entries have equal total debits and credits.
- [ ] Record a pledge and a part/full payment; confirm the pledge balance and income ledger update.
- [ ] Confirm free plans can preview reports but cannot download PDF/Excel.
- [ ] Verify paid activation only after payment evidence is checked.
- [ ] Back up database, test restore, and have a Zimbabwean accountant review reports before live financial use.

## 8. Known next-stage work
- Payment gateway and automated recurring billing.
- Secure profile/role management UI, audit-log browser, MFA enforcement and account suspension.
- Full double-entry accounting: opening balances, account mapping, accruals, receivables, payables, bank reconciliation, asset register/depreciation, liabilities, payroll, FX rates, restricted fund accounting and close controls.
- Donor year-end statements with date range, receipt sequence and delivery workflow.
- Statutory ZIMRA tax determination and TaRMS integration (not available from this front end).
- PDF/Excel report validation, tests, backups, monitoring, privacy notice and data-retention policy.


## Member portal database update
After the original schema has been applied, run `MEMBER_PORTAL_SECURITY_MIGRATION.sql` in Supabase SQL Editor. This migration adds the one-to-one user-to-member link and member-only row-level security. Then invite members and use Users & roles → Link member to connect each accepted login to its member record. Existing member records remain intact; no member account is automatically linked by email.
