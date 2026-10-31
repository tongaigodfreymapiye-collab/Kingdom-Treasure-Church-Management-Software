# Developer + CFMI Church Administrator access

This update keeps the reserved account's `developer` role. It also links that account to **Consuming Fire Ministries International / Main Branch** and grants administrator-level permissions only within that home church.

## What this enables
- Sign in with the existing developer account.
- Land on the platform dashboard, with a separate **CFMI church workspace** navigation item.
- Open the CFMI workspace and use church finance, members, reports, users, settings and branch administration pages.
- Manage all CFMI branches under the CFMI tenant boundary.
- Keep platform administration separate from CFMI church accounting.
- Retain the lifetime subscription entitlement for CFMI.

## Important deployment order
1. Back up the Supabase project.
2. In Supabase SQL Editor, run `DEVELOPER_CFMI_ADMIN_ACCESS_MIGRATION.sql` once.
3. Confirm the final verification query returns the developer email, `developer`, Consuming Fire Ministries International, Main Branch and `lifetime / active`.
4. Deploy the updated `index.html` and included assets to the existing GitHub Pages repository.
5. Sign in and select **CFMI church workspace** from the left navigation.

Do not rerun the original first-install SQL. This is a targeted migration and does not replace `config.js`, Supabase credentials, existing records or the platform developer identity.

The migration is designed to limit the branch-administrator bypass to the developer's assigned home church. It does not grant the developer unrestricted access to other churches' personal or financial records.
