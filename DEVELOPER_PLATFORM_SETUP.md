# Kingdom Treasure — Privacy-first Developer Platform Update

## Developer experience

- The reserved, verified developer signs in and lands on the **Platform overview** dashboard.
- The overview shows platform-wide counts and anonymised monthly activity only. It does not list other churches, members, donors, user emails, phone numbers, or per-church financial rows.
- Platform financial trend rows are suppressed unless at least five distinct churches contribute to the month/currency group. The purpose is to reduce the risk of identifying one church from an aggregate.
- The developer's ordinary church workspace is the developer's CFMI home church and assigned `Main Branch`. The developer's branch-level workspace is separate from platform aggregates.
- The developer's subscription page shows permanent entitlement: unlimited branches, unlimited users, all advanced features and no payment prompt.

## Church-approved support access

1. A church administrator opens **Settings → Request developer assistance** and submits a reason and scope.
2. A pending request does not grant access.
3. An authorised church administrator explicitly approves a four-hour read-only window (database maximum: 24 hours).
4. The developer can open the support snapshot only while the grant is approved and unexpired.
5. The snapshot returns only the requested diagnostic scope. Donor/member contact data is not exposed. The `user_access_review` scope may reveal user account names/emails and permits the developer to suspend/restore non-developer accounts in that church while the grant remains active.
6. A church administrator can revoke access immediately from Settings. The developer can also close/revoke the session. Revocation blocks subsequent server requests; data already rendered in a browser cannot be remotely recalled, so the support page should be closed after use.
7. Approval and revocation are written to the church audit log where the database schema permits.

Scopes:
- `read_only_diagnostics`: counts and branch-level diagnostic totals; no detailed financial amounts.
- `financial_review`: diagnostic counts plus financial totals by currency.
- `user_access_review`: user-role counts only; no user identities or contact details.

External church user suspension/restoration is permitted only when the church has explicitly approved an active `user_access_review` grant. The endpoint checks the target user belongs to that same church and protects all developer identities. Outside that scope, user access changes are restricted to the developer's CFMI home church.

## Software business accounting

A separate `platform_business_ledger` stores Kingdom Treasure software business income and expenses. Use it for software subscriptions, lifetime licences, implementation/support revenue, hosting, development, marketing, processing and administration costs. It is not a church accounting ledger and must never be mixed with tithes, offerings, donations, pledges or church expenses.

The Developer dashboard shows business totals and a monthly sales/cost chart. The Platform administration page provides a business ledger entry form and history. Access is server-side through the developer-admin Edge Function; the service-role key must never appear in `config.js`, HTML, GitHub Pages or browser storage.

## Apply the database migration

1. Back up the Supabase project first.
2. Open Supabase → SQL Editor → New query.
3. Run `DEVELOPER_PLATFORM_ACCESS_MIGRATION.sql` in full.
4. Verify its final query returns the reserved developer, CFMI, Main Branch, `lifetime`, `active`, and a NULL expiry.
5. This migration removes the earlier `developer_read_all_*` policies and tightens church/branch/profile/subscription policies to the developer's home church. It does not grant unrestricted cross-church table reads.
6. Do not rerun the original first-install SQL.

The migration assumes the existing Kingdom Treasure schema and the earlier function-permission hardening have already been installed. If any policy name differs or SQL errors, stop and review the actual `pg_policies` output before attempting a manual change.

## Deploy the developer-admin Edge Function

From the repository root, with Supabase CLI installed and authenticated:

```powershell
supabase functions deploy developer-admin --project-ref wabkzxvlwkmwisijofmk
supabase secrets set RESERVED_DEVELOPER_EMAIL=tongaigodfreymapiye@gmail.com --project-ref wabkzxvlwkmwisijofmk
```

The Supabase project supplies the server-side `SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` environment variables. Never paste or publish the service-role key.

## Publish the website

Upload the updated project contents to the existing GitHub repository and commit to `main`. Keep the actual project's existing `config.js` URL and publishable key. The site should be deployed at the repository's GitHub Pages URL.

## Test plan

1. Sign in as the reserved developer; confirm the first page is Platform overview.
2. Confirm the platform overview shows aggregate counts and charts, not other church names, member identities or donor details.
3. Open the CFMI workspace; confirm the developer sees only the assigned Main Branch in branch-scoped church records.
4. Confirm the developer subscription is permanent and has no purchase buttons.
5. As a test church administrator, submit a support request. Confirm the developer cannot open it while pending.
6. Approve the request as the church administrator; confirm the developer can open the limited snapshot until expiry.
7. Revoke the request from the church side; confirm the developer can no longer open the snapshot. Also test developer-side close/revoke.
8. Add test income and expenses to the separate software business ledger; verify the totals and graph.
9. Test CFMI income, expenses, members, pledges, posting, journal entries, budgets, reports and exports.
10. Confirm a different church administrator cannot read CFMI records and CFMI users cannot read another church's records.

## Privacy and compliance note

These controls are privacy-by-design safeguards, not a certification or legal opinion that the product is compliant with GDPR, Zimbabwean law, or every other applicable privacy/accounting requirement. Before production use, the platform operator and each church should document controller/processor roles, lawful bases, privacy notices, data-processing terms, retention/deletion schedules, data-subject request handling, incident/breach procedures, access logging, subprocessors, hosting locations and international-transfer safeguards. Obtain qualified legal and accounting review for the countries in which the service operates.
