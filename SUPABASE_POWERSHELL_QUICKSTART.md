# Kingdom Treasure - Supabase + PowerShell Quickstart

## What you need to do in Supabase first

1. Sign in to https://supabase.com/dashboard using your own account.
2. Select **New project**. Name it `Kingdom Treasure`.
3. Choose a strong database password and store it in a password manager. Do not send it in chat.
4. Choose a region close to the main users. Wait for provisioning.
5. Open **Project Settings → API** (or API Keys).
6. Copy the Project URL and the public `anon` / publishable key. Do not copy the `service_role` or secret key.

## Step 1 - Configure the website

Open PowerShell in this extracted application folder and run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Configure-Supabase.ps1
```

Paste the Project URL, public anon/publishable key and the final application URL. For an initial local test, use `http://localhost:8000`; update the Site URL and Redirect URLs again after GitHub Pages is enabled.

## Step 2 - Create the database

1. In Supabase Dashboard, open **SQL Editor → New query**.
2. Open `KINGDOM_TREASURE_FIRST_INSTALL.sql` in a text editor.
3. Copy the entire SQL file into the SQL Editor and run it on the new, empty project.
4. Review the SQL Editor output. Stop if any statement reports an error; do not continue with a partially installed schema.
5. The SQL bundle includes the core schema and the member-portal security migration.

**Important:** This is a first-install bundle for a new project. Never run it blindly against an existing/live database. Back up first and use reviewed migrations.

## Step 3 - Authentication settings

In **Authentication → URL Configuration**:
- Site URL: your final GitHub Pages URL.
- Redirect URLs: add the final GitHub Pages URL and `http://localhost:8000/**`.
- Enable email confirmations.
- Configure custom SMTP before inviting real users or commercial launch.
- Enable MFA for the developer account.

The reserved developer account is `tongaigodfreymapiye@gmail.com`. Register that email through the normal sign-up flow, verify the mailbox, then sign in. The database trigger promotes the verified reserved address to the developer role. Do not create a church under the developer login.

## Step 4 - Test locally

```powershell
.\Test-SupabaseConnection.ps1 -ProjectUrl "https://YOUR-PROJECT-REF.supabase.co" -PublishableKey "YOUR_PUBLIC_ANON_OR_PUBLISHABLE_KEY"
.\Start-LocalPreview.ps1
```

Open `http://localhost:8000`. Test a normal church signup with a separate email address first. Verify the email and sign in. Confirm the church, first branch, free subscription and starter chart of accounts are created.

Then register and verify `tongaigodfreymapiye@gmail.com` to test the reserved developer role.

## Step 5 - Deploy the invitation Edge Function

Install Node.js LTS, then install Supabase CLI (the CLI may also be installed using the official Supabase CLI installation method):

```powershell
npm install -g supabase
```

Run:

```powershell
.\Deploy-SupabaseFunction.ps1 -ProjectRef "YOUR-PROJECT-REF" -AppOrigin "https://YOUR-USERNAME.github.io/YOUR-REPOSITORY/"
```

The script runs `supabase login`, links the project, sets `APP_ORIGIN`, and deploys `invite-user`. The Edge Function uses Supabase's server-side `SUPABASE_SERVICE_ROLE_KEY`; it must never be placed in `config.js`.

## Step 6 - GitHub Pages

1. Create or open the GitHub repository.
2. Upload/commit all files from this folder to the repository root.
3. Confirm `config.js` contains only the Project URL and public anon/publishable key.
4. In **Settings → Pages**, choose GitHub Actions or deploy from the selected branch/root.
5. Add the exact published URL to Supabase Authentication → URL Configuration.
6. Test sign-up, email confirmation, sign-in, password reset and QR sign-in from the published domain.

## Acceptance checklist

- [ ] A non-developer account cannot access Developer Console or promote itself.
- [ ] Verified reserved developer email receives developer role.
- [ ] Church signup creates an isolated church and first branch.
- [ ] Member invitations work and the Edge Function rejects non-admin callers.
- [ ] A member can access only their own profile, posted giving and pledges.
- [ ] QR link rejects accounts from a different church and unlinked accounts.
- [ ] RLS prevents cross-church data reads and writes.
- [ ] Free plan is limited to one branch.
- [ ] Annual/lifetime entitlements are only activated after verified payment.
- [ ] Financial postings balance debits and credits; accountant reviews reports.

## What is not automated yet

This setup does not create the Supabase project, configure SMTP, create a GitHub repository, or connect a payment processor. Those require your account and provider credentials. Payment processing should be completed with a server-verified webhook before accepting live payments.
