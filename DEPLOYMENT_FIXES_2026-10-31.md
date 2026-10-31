# Kingdom Treasure deployment fixes — 31 October 2026

This package includes targeted frontend/deployment corrections:

- `index.html` cache-busts `config.js` so GitHub Pages/browser caches fetch the current Supabase project configuration.
- Startup validates the Supabase project URL and public key and displays a useful configuration warning instead of silently failing.
- Reserved developer email onboarding no longer submits church-name/branch metadata; the account is created as the reserved developer identity and promoted only by the existing email-confirmation database trigger.
- Duplicate intro playback handlers were consolidated.
- Added `Kingdom Treasure Logo.png` as a compatibility alias for older deployed HTML references; the official underscore-named logo remains the primary asset.
- `Test-SupabaseConnection.ps1` now tests `/auth/v1/health` using only the `apikey` header. It no longer sends a publishable key as a Bearer JWT or treats the REST root as the health endpoint.

## Deploy

1. Keep the existing Supabase database and its security patch; do not rerun the first-install SQL.
2. Replace the contents of the GitHub Pages repository with the contents of this ZIP (the files inside the project folder, not the outer folder itself).
3. Confirm `config.js` still contains the correct project URL and public publishable key. Never upload a service-role/secret key.
4. Wait for the GitHub Pages deployment to complete.
5. Open the site in a private/incognito window or use Ctrl+Shift+R.
6. Open `config.js?v=20261031-kt2-fix1` from the site and confirm the correct project URL is displayed.
7. Test the Supabase Auth health endpoint with the included PowerShell script.
8. Test developer sign-in or the one-time reserved developer signup flow. Email confirmation must be completed before the database promotes the account.

## Important

This is a static source/deployment repair and static validation, not proof that every live Supabase workflow has passed end-to-end testing. Test registration, member linking, income/expense recording, pledge payments, accounting journal creation, audit logging, reports, and branch isolation with controlled test data before entering real financial records.

## Supabase Auth URL configuration for GitHub Pages

In Supabase Dashboard → Authentication → URL Configuration:

- Set Site URL to `https://tongaigodfreymapiye-collab.github.io/Kingdom-Treasure-Church-Management-Software/`.
- Add that same full URL to Redirect URLs.
- Keep `http://localhost:8000/**` as an additional Redirect URL only if you still use local preview.

This is required so confirmation and password-reset links return to the deployed application instead of localhost.
