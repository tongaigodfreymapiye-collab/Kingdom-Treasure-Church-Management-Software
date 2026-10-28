# Kingdom Treasure – RBAC and Production Setup Guide

## What this updated package includes
- Prototype signup/sign-in screen and role-oriented UI.
- Admin role assignment, with a three-Treasurer cap in the interface.
- Treasurer edit/request workflow; Pastors are intended to be read-only and approve/reject payment requests.
- Assembly overview, master report, payroll register, generated printable payslip.
- The supplied CFMI payslip layout represented as payroll fields.
- Historical import review workbook extracted from the uploaded financial spreadsheets.
- Supabase/PostgreSQL schema starter for server-side roles, financial records, payment approvals, payroll and audit logs.

## Important deployment boundary
The current HTML is still a browser-local prototype. Its account data, passwords, banking details and role checks are stored in localStorage. That is NOT secure authentication, does not send email, does not run scheduled reports while closed, and does not connect to a bank. Do not use real passwords or bank details in this prototype. Production security requires implementing the supplied SQL and connecting the front end to Supabase Auth + database policies / Edge Functions. The schema is a starter and must be reviewed and completed before production.

## Required production controls
1. Create a Supabase project and apply `supabase_schema.sql` after review.
2. Configure Supabase email/password signup, email verification, password reset, and redirect URLs.
3. Implement server-only role assignment. Public sign-up must never let a user choose Admin or Treasurer directly. First Admin must be provisioned out of band.
4. Enforce role policies on every database write: Admin manages users/assemblies; up to three Treasurers can edit finance and request payments; only a Pastor can approve/reject outflows. Treasurers must never execute or approve payments.
5. Add assembly-scope policies so each assembly's records are partitioned and Admin's Master Report can consolidate all assemblies.
6. Store bank details encrypted and reveal only masked account numbers in the UI. Restrict bank-detail access and log every read/write.
7. Send request emails to registered Pastors' verified signup addresses using a server-side email provider. Do not send email from browser-only code.
8. Schedule monthly reports for the last calendar day and year-end statements using a server scheduler (e.g. Supabase Cron + Edge Function). Email all account holders, with assembly permissions and privacy respected.
9. Implement real approval transitions, audit trail, payment provider/manual bank reconciliation and idempotency before marking anything paid.
10. Validate payroll formulas with a qualified local payroll/accounting professional before use.

## Payroll and payslip notes
The uploaded CFMI Pastoral Payslip shows: Basic Salary, Housing Allowance, Transport Allowance, Health Insurance, PAYE, AIDS Levy, employee and employer NSSA, Tithe, Net Pay, assembly, month, payment date and authorisation. The prototype creates a printable payslip from entered payroll values. Its example figures and formula defaults are not authoritative tax guidance; verify the applicable current rates and the church's approved tithe policy before processing payroll.

## Historical record import review
`CFMI_Historical_Import_Review.xlsx` contains:
- `Transaction Import Queue`: 154 candidate income/expense rows extracted from the supplied monthly ledgers.
- `Partnerships 2023 Queue`: 52 dated partnership contribution rows extracted from the 2023 partnership/pledge workbook.
- `Date Review Warnings`: date/month conflicts and unparseable date labels preserved for manual review.
- `Source Inventory`: source workbook and worksheet inventory.

The source ledgers contain mismatches between sheet titles and recorded dates (for example, some sheets labelled January/February contain dates from other months), and the same period appears in both standalone files and quarterly workbooks. For accuracy, extracted rows are marked `Needs Review`; they are NOT auto-posted into live totals. Reconcile date, duplicates, categories, currency, balances and assembly with the original records before importing. This deliberately avoids silently changing historical data or double-counting monthly records.
