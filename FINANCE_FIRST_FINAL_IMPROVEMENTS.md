# Kingdom Treasure — Finance-first improvement update

## Scope
This update is a conservative frontend enhancement of the existing application. It preserves the current Supabase project configuration, authentication flow, database schema, RLS policies, developer role, support functions, branding assets and existing financial records. No database reset or first-install SQL is required.

## Improvements in this update
- Modern responsive styling, stronger focus states, improved table readability, mobile spacing and print layout.
- Dashboard and transaction register show totals separately by currency. No automatic or misleading cross-currency addition is performed.
- Monthly dashboard chart separates income and expenses by currency.
- Transaction register filters by text, direction, status, currency and date range.
- Transaction CSV export respects the active filters and includes key accounting fields.
- Member directory CSV export for data portability.
- Transaction register highlights posted, draft and void counts separately.
- Budget actual calculations match the budget currency, avoiding cross-currency comparisons.
- Page title and metadata now describe the finance-first purpose.

## Existing functionality retained
- Supabase URL and publishable key in `config.js` are retained unchanged.
- Existing authentication, reserved developer identity, CFMI workspace logic, RLS-bound data access and role checks are retained.
- Existing financial transaction posting trigger, journal lines, pledge-payment RPC, budgets, reports, branch controls, subscription controls, support workflows and developer business ledger are retained.
- Existing logos, intro video, poster, member QR feature, deployment scripts and SQL migrations are retained.

## Important accounting boundaries
- The app must not combine amounts across different currencies without a configured and auditable exchange-rate process. This update avoids mixed-currency dashboard and budget totals; other advanced statements still need a formal accounting review before statutory use.
- A posted transaction is not a substitute for bank reconciliation. Opening balances, bank reconciliation, period close, reversals/void controls, full accrual accounting, fixed-asset registers and exchange-rate revaluation remain future accounting work.
- CSV exports are data portability tools, not audited statements.
- Existing report previews are management reports. Do not represent them as audited or statutory accounts.
- No live Supabase end-to-end tests have been performed from this package build. Deploy to a staging copy first and test with non-sensitive sample transactions.

## Deployment safety
1. Download and unzip this package.
2. Keep a backup of the current GitHub repository contents.
3. Confirm `config.js` has the same project URL and publishable key as your live repository. Do not replace it with `config.example.js`.
4. Upload the contents of the project folder to the existing GitHub repository.
5. Do not run `KINGDOM_TREASURE_FIRST_INSTALL.sql` or replace the existing Supabase database.
6. Do not rotate keys or change Supabase Authentication URL settings as part of this frontend update.
7. Test sign-in, CFMI workspace, add a draft transaction, post a sample income and expense, confirm journal lines, run reports, test CSV exports, verify branch isolation, and test developer dashboard.

## Files changed
- `index.html` — UI polish, currency-safe dashboard totals/chart, transaction filters/CSV export, member CSV export, currency-matched budget actuals, metadata.
- `FINANCE_FIRST_FINAL_IMPROVEMENTS.md` — this change record.

No SQL or `config.js` changes were made.
