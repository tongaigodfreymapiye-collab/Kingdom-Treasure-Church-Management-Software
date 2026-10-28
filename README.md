# Kingdom Treasure Church Management Software

A browser-based prototype for church financial management.

## Included
- Dashboard with income, expenses, net movement and payables
- Income and expense records with payment method, currency, event, fund and exchange rate
- Pledge register and pledge payment recording
- Payables and receipt-backed reimbursement claims with review, approval and partial settlement
- Assets, gifts in kind and resale inventory register
- Fundraising and resale activity summaries
- Period-based report previews and PDF reports with the Kingdom Treasure logo and church details
- Excel export for registers and complete workbook backup
- Excel/CSV import with preview and confirmation
- Church details and reporting currency settings
- Responsive layout for desktop, tablet and mobile

## Run locally
Open `index.html` in a modern browser. Excel and PDF features load XLSX and jsPDF libraries from public CDNs, so those features require internet access.

## Important prototype limitations
This is a functional front-end prototype, not a production-ready accounting platform. Records are stored in the current browser's local storage. They are not shared across users or devices, and local storage is not a secure database or a substitute for managed backups. Receipt files are stored locally in the browser. There is no authentication, server-side permission enforcement, secure cloud file storage, full double-entry posting engine, bank feed, automated bank reconciliation, or jurisdiction-specific tax/accounting compliance. Some statements are clearly labelled simplified and must not be treated as audited or statutory accounts.

Before live use, connect a secure backend (for example Supabase/PostgreSQL with row-level security and server-side accounting functions), implement authenticated roles and approvals, enforce balanced double-entry postings, add secure file storage, test restore/backup procedures, and have the accounting rules reviewed by a qualified accountant for the church's jurisdiction.

## GitHub Pages
Upload `index.html` and `Kingdom_Treasure_logo.png` to the root of a GitHub repository and enable GitHub Pages. This makes the prototype accessible, but each browser keeps its own local data; it does not create shared church records.
