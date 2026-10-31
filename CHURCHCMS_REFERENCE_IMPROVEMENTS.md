# Kingdom Treasure — Product Improvements Inspired by ChurchCMS

Date: 31 October 2026

## Purpose and boundaries

This document records product patterns worth adopting from the public ChurchCMS feature descriptions. It is a product specification and implementation backlog, not a claim that these features have already been implemented or tested in Kingdom Treasure. The current application remains the source of truth for what is operational.

Keep Kingdom Treasure's existing identity, pricing model, Supabase architecture, privacy-first developer model, church/branch separation, and financial-accountability focus. Do not copy ChurchCMS branding, source code, assets, or claims.

## Adopt — priority order

### P1 — Member directory and data portability

- Extend member search to filter by name, email, phone, member number, branch and membership status.
- Add configurable member status values, with sensible defaults: Visitor, New believer, Active, Inactive, Transferred and Archived. Churches may rename/add statuses.
- Add CSV import with a downloadable template, column mapping, preview, duplicate detection, validation report and explicit confirmation before writing records.
- Add CSV export for authorised church administrators. Export only the selected church/branch and fields the user is authorised to see.
- Add a member profile detail view with contact information, join date, branch, status, member number and permitted giving-history summary.
- Keep private pastoral notes out of scope unless a separate, tightly permissioned module is explicitly approved. Do not expose notes to ordinary members or platform-wide developer analytics.

### P2 — Family and household relationships

- Allow an administrator to create a household and link member records (for example spouse/parent/child) using explicit relationship labels.
- Support a household contact only where the church has a legitimate reason and the person has supplied it.
- Avoid automatically combining finances: individual donations remain attributed to the actual donor. Household summaries must be permission-controlled.
- Children’s records require extra care: minimise collected data and restrict access to authorised roles.

### P3 — Giving and fund management

- Make funds first-class configurable records rather than relying only on free-text fund names.
- Provide fund-level income, expenditure, restricted balance and reconciliation views.
- Add optional fundraising campaigns with title, purpose, target, start/end dates, designated fund and progress calculated only from linked, posted transactions.
- Campaigns must not create a second source of truth: donations must still be recorded in the financial ledger and linked to the campaign.
- Do not add payment gateways or recurring online payments until gateway, currency, fees, refunds, reconciliation and compliance requirements are separately designed and tested.

### P4 — Member ID and QR improvements

- Extend the existing QR member ID capability with printable card layouts and a scan-safe opaque identifier.
- QR codes must not contain names, email addresses, phone numbers, giving data or other personal information.
- Scanning should resolve only to a minimal check/lookup screen for an authorised church user. Do not add attendance registration as part of this enhancement because it is outside the agreed product scope.

### P5 — Usability and onboarding

- Add a clear public product landing page with feature overview, pricing, privacy/security explanation, documentation and a demo/contact route.
- Add an in-app first-run checklist for church setup: organisation profile, first branch, funds, departments, opening balances and first member import.
- Use contextual empty states with a next action (e.g. “No members yet — add a member or import a CSV”).
- Keep navigation responsive and consistent; use clear page titles, breadcrumbs/workspace indicator and confirmation states.
- Provide a help/contact entry point. A WhatsApp link may be offered as an optional external contact route, but do not embed an unverified third-party chat widget or send member data to it.

## Explicitly excluded from this release

Do not add the following modules or workflows: attendance registration/check-in, event/service calendar, event registration, prayer requests, appointments, testimonies/feedback feeds, member-to-member messaging, announcements/programmes/activities, push notifications, SMS or WhatsApp broadcasts, member mobile app, live streaming or video rooms. These were previously excluded from the Kingdom Treasure requirements and are not needed to improve the current finance-and-administration product.

## Security and data rules

- Every import, export, profile read/update and campaign operation must be scoped to the authenticated user's church and permitted branch.
- Enforce authorisation in Supabase RLS and server-side functions, not only in browser JavaScript.
- Never trust a client-supplied church_id, role, subscription status or developer flag.
- Keep the reserved developer account separate from normal church operations. The platform overview remains aggregate/anonymised; church-specific details require the church workspace or an authorised, time-limited support grant.
- Record audit events for bulk import, export, member changes, family relationship changes, fund changes and campaign/financial linkage.
- Provide import preview and duplicate handling; never silently overwrite existing records.
- Use least-privilege access for sensitive household and child data.
- Retain a clear data export path and documented deletion/retention process.

## Suggested delivery sequence

1. Stabilise developer/platform workspace and verify the backend functions and RLS policies.
2. Implement member statuses, profile detail and CSV import/export.
3. Add fund master data and ledger-linked campaign reporting.
4. Add optional household relationships with restricted visibility.
5. Improve QR member ID print layouts without adding attendance tracking.
6. Improve public landing page, onboarding checklist and support contact.

## Reference notes

The inspiration is based on the public ChurchCMS feature descriptions for member profiles, family units, custom fields, membership status, CSV import/export, giving funds, campaigns, QR IDs and website/help presentation. Those public descriptions are not independent verification that each feature works as advertised. We should test actual behaviour before treating any pattern as proven.

Reference pages:
- https://churchcms.app/features/
- https://churchcms.app/
- https://churchcms.app/open-source/

## Current implementation status

This document adds the agreed improvement backlog to the developer-platform project package. It does not implement the new member schema, CSV import/export workflow, household relationships, campaign tables, QR card changes or public landing page. Those require separate code, database migrations, RLS policies and functional tests. Existing features must not be represented as newly completed merely because they appear in this specification.
