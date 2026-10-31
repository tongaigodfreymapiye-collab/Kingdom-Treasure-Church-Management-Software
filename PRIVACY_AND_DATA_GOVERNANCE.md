# Kingdom Treasure privacy and data governance design

## Access model

| Context | Developer access |
|---|---|
| Platform overview | Aggregate counts and privacy-suppressed monthly trends only |
| CFMI home church | Church/branch data permitted by the developer's own profile and RLS; assigned Main Branch is the default branch context |
| Other church without an approved grant | No individual church records |
| Other church with active support grant | Time-limited, scope-limited, read-only diagnostic snapshot |
| Software business ledger | Separate developer-only business accounts, not church accounting data |

## Support access lifecycle

1. A church administrator creates a request with a reason and declared scope.
2. A request remains pending and grants no access.
3. A church administrator explicitly approves a 1–24 hour window.
4. The developer can read only the corresponding diagnostic snapshot while the grant remains active.
5. The church administrator or developer can revoke the grant; expiry also ends access.
6. Approval/revocation actions are recorded in audit history where available.

## Data minimisation

The platform dashboard must not show church names, member names, donor identities, emails, phone numbers, or per-church financial rows. Financial trends are aggregated across at least five distinct contributing churches per month/currency group. If the threshold is not met, those financial trend points are suppressed.

Support snapshots do not return individual member/donor contact information. Financial totals are returned only for the `financial_review` scope. User role counts and account names/emails are returned only for `user_access_review`; only that explicit scope permits suspension/restoration of non-developer church accounts. Revocation blocks future server reads/actions, but cannot remotely erase data already displayed in a browser.

## Software business accounts

Software sales and operating costs are stored in `platform_business_ledger`, a separate developer-only ledger. Church financial records remain in each church's own accounting tables. Never consolidate church offerings or donations into the software company's revenue.

## Operational safeguards still required

- Publish a privacy notice and data retention schedule.
- Define controller/processor roles and execute data-processing agreements where required.
- Document lawful bases and purposes for each category of personal data.
- Provide data-subject access, correction, deletion/restriction and complaint processes as applicable.
- Define incident response and breach notification responsibilities.
- Review hosting region, subprocessors and cross-border transfer mechanisms.
- Keep service-role secrets server-side and rotate them if exposed.
- Review support grants and audit logs periodically.
- Obtain qualified legal/accounting advice; this document is not a compliance certification.
