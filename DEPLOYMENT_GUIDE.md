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

The verified `tongaigodfreymapiye@gmail.com` identity receives the reserved `developer` role from the database trigger. The developer is assigned CFMI/Main Branch as the home workspace and receives permanent lifetime entitlement. The developer always lands on the aggregate Platform overview. Do not create a separate church signup under the developer login.

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

No payment processor was provided. For now, verify payment independently and activate requests from the Developer Console. Before launch, connect a payment provider with signed server-side webhooks and idempotent fulfilment. Never activate plans based only on a client-side success screen. Set prices, currencies, refunds, tax treatment and terms before accepting customers. The developer's own CFMI subscription is permanently free and must never show a payment prompt.

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


## Animated splash screen and logo
Keep `Kingdom-Treasure-Animated-Logo.mp4` and `Kingdom_Treasure_Logo.png` in the same deployment folder as `index.html`. The intro video autoplays muted before the sign-in screen; the skip control and fallback timer ensure users are not blocked if autoplay fails. The same logo appears on sign-in, sidebar and the authenticated page header.


### Browser compatibility
Use the supplied H.264 `Kingdom-Treasure-Animated-Logo.mp4` and keep `Kingdom-Treasure-Intro-Poster.jpg` beside `index.html`. The poster renders immediately; the video is muted for browser autoplay compatibility. If deploying to GitHub Pages, commit and push both media files as well as the updated HTML.


### Full intro playback
The splash is dismissed only by the MP4 `ended` event or the user's Skip Intro action. Do not add a fixed timeout that closes the splash while the video is playing. If autoplay is blocked, the page offers a Play intro control instead.


### Centered intro sizing and timing
The video is centered and constrained to the same maximum width as the sign-in card (480px), with a 16:9 aspect ratio. It plays at normal speed and cannot be dismissed before it finishes; an 8-second minimum is measured from the first `playing` event. The skip control remains available.


## Church member sign-in QR codes
No additional SQL migration is needed for QR generation. After deploying the updated `index.html`, a church administrator opens **Church settings** and downloads the organisation-specific QR code. The QR is generated from the current deployed URL and the church UUID. Members scan it, then sign in with their existing registered member credentials. The app validates the authenticated profile's church ID and `member` role before granting access. Invite and link each member account using the existing **Users & roles → Link member** workflow first. QR generation uses the QRCode.js CDN and requires browser internet access.


## Intro hymn and clean animation
Keep `Kingdom-Treasure-Animated-Logo.mp4` beside `index.html`. The MP4 contains H.264 video and AAC audio (original instrumental hymn "A Heart That Gives") for the full 9.875-second duration. The storyboard text captions have been removed; developer attribution is rendered below the animation in the splash layout. Browsers may block autoplay with sound; in that case users must tap "Play intro with hymn". The sign-in screen is shown only on the video's `ended` event or when Skip intro is selected.


## Official logo assets
Deploy `Kingdom_Treasure_Logo.png` and `Kingdom-Treasure-Favicon.png` beside `index.html`. These are the same official Kingdom Treasure brand mark. The MP4 animation's final logo reveal uses the same original PNG asset; the alternate emblem supplied later is intentionally not used.


## PowerShell-assisted Supabase setup
See `SUPABASE_POWERSHELL_QUICKSTART.md`. Run `Configure-Supabase.ps1` to write the public browser config, `Test-SupabaseConnection.ps1` to test endpoint reachability, `Start-LocalPreview.ps1` for local preview, and `Deploy-SupabaseFunction.ps1` to deploy the secure invitation Edge Function after creating and linking your project. These scripts do not store a service-role key.

## 9. Privacy-first developer platform
Apply `DEVELOPER_PLATFORM_ACCESS_MIGRATION.sql` only after a backup. It removes earlier broad cross-tenant developer read policies, scopes the developer's church workspace to CFMI/Main Branch, creates church-controlled temporary support grants and creates a separate developer-only software business ledger. Deploy the `developer-admin` Edge Function. See `DEVELOPER_PLATFORM_SETUP.md` and `PRIVACY_AND_DATA_GOVERNANCE.md`. Do not claim GDPR or other legal compliance solely because these technical controls are installed.
