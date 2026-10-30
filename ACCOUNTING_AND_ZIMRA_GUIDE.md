# Accounting and ZIMRA design notes

## ZIMRA Public Notice 98 of 2024
The supplied notice (issued 11 December 2024) states that donations, tithes, offerings and contributions made by members or benefactors, and non-trading receipts, are exempt from income tax. It separately identifies income from trading activities as taxable, including sales of church literature/books/music, branded merchandise, meals, clothing and similar items. It notes that such sales may also attract VAT depending on applicable thresholds. It reminds churches to register for applicable taxes and submit outstanding returns through the TaRMS Self-Service Portal, with payments made on time and in the applicable currency.

The application therefore captures an income classification:
- `donation`: donations, tithes, offerings and contributions
- `non_trading`: non-trading receipts
- `trading`: trading income requiring tax review
- `other`: needs review

It includes a trading-income review report. It does not determine tax liability, calculate VAT thresholds, register a church, submit TaRMS returns or make tax payments. Those decisions depend on current law, facts, thresholds and ZIMRA guidance and must be reviewed by a qualified Zimbabwean tax practitioner.

## Zimbabwe Financial Reporting Manual (2023)
The supplied ZFRM explains that it supports accrual IPSAS adoption by public-sector reporting entities. It highlights transparency, accountability, clear financial reporting and stewardship. Relevant design ideas include:
- Annual reporting and governance/service performance disclosures (chapters 3; printed pages 16–19).
- Statement of financial performance, statement of financial position, changes in net assets/equity, budget-versus-actual comparison, comparative information and notes (chapter 4; printed pages 20–23).
- Cash flow reporting (chapter 6; printed page 26).
- Accounting policies, estimates and error correction (chapter 5; printed pages 24–25).
- Related-party disclosures (chapter 10; printed pages 30–32).
- Foreign exchange reporting (chapter 7; printed pages 27–28).

**Scope caution:** ZFRM sections 1.2.1–1.2.4 describe its scope as public-sector reporting entities (e.g. ministries, local authorities, constitutional entities, statutory funds and designated public entities). It does not establish that every church is an IPSAS reporting entity. The app uses selected stewardship and presentation practices as a design reference, not a blanket assertion of legal applicability or IPSAS compliance.

## Controls implemented in this build
- Separate funds and ministry departments.
- Transaction categories and tax classification.
- Budget records by department, period and fixed/variable/capital classification.
- Balanced two-line cash journal posting for posted transactions.
- Trial balance preview, income by fund, cash movement, department costs, pledge and trading income reports.
- Role and branch access controls, with a financial transaction audit trail.

## Limitations before statutory or audited use
The automated posting is a simplified cash-basis starting point. It does not yet implement full accrual recognition, opening balances, bank reconciliation, receivables/payables, restricted-fund releases, asset capitalisation/depreciation, provisions, employee benefits, exchange-rate translation, hyperinflation accounting, related-party note workflows, audit sign-off or formal annual close. Some generated statements are therefore management views, not complete statutory statements. A Zimbabwean accountant should configure the chart of accounts and approve policies, statement formats and tax treatment before the software is used as the church's official books.
