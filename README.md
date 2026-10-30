# Kingdom Treasure — Church Management & Financial Accountability

A responsive, multi-tenant church management web application. The browser UI is a static site; authentication and shared records run on Supabase Auth + PostgreSQL with Row Level Security.

## Included in this package
- Free church registration and email/password sign-in, email verification and password reset.
- Reserved developer identity: `tongaigodfreymapiye@gmail.com`; developer role is assigned by the database bootstrap trigger, never by a public form.
- Church organisation + first branch created at signup; secure branch-scoped data access.
- Secure church-user invitations through a Supabase Edge Function (Admin API); roles: Treasurer, Pastor, Department Leader and Member.
- Member directory; income and expense capture; fund, department, donor/member and tax classification.
- Budgets with fixed, variable and capital/facilities cost categories.
- Pledge register and payment posting.
- Dashboard charts; income by fund, balance sheet management view, cash movement, department expenditure, budget vs actual, donor giving, pledge, missionary-support, trading-income review and trial-balance previews.
- Balanced two-line journal postings generated for posted cash transactions; audit log for financial transaction changes.
- Commercial plan controls: Free, $20/year Annual Church, $200 once-off Lifetime Church, plus separately approved branch add-ons.
- PDF and Excel exports gated to paid annual/lifetime plans.
- Existing Kingdom Treasure logo, historical import review workbook and supplied pastoral payslip template retained.

## Important production boundary
This repository is a deployable application source, not a hosted service. A Supabase project must be created and configured by the owner. No Supabase credentials, payment gateway credentials, email provider credentials, or verified merchant account were supplied. Consequently:
- Authentication works after Supabase setup.
- Subscription requests are recorded and manually activated by the reserved developer after payment is verified. No payment is falsely shown as collected.
- PDF/Excel libraries and charts load from public CDNs, so internet access is required.
- Some statements are management reports, not audited or statutory accounts. Opening balances, full accrual accounting, bank reconciliation, fixed-asset depreciation, payroll/tax calculations, multi-currency revaluation, year-end close and accounting policy configuration require further implementation and professional review.
- The Zimbabwe Financial Reporting Manual is written for public-sector reporting entities; this app borrows relevant good-practice structures but does not assert all churches must apply IPSAS.
- ZIMRA classifications are monitoring aids, not a tax opinion or automated return filing.

## Quick start
See `DEPLOYMENT_GUIDE.md`. The short version:
1. Create a Supabase project.
2. Run `supabase_schema.sql` in the Supabase SQL Editor.
3. Set Authentication → URL Configuration: add your GitHub Pages URL to Site URL and Redirect URLs.
4. Enable email confirmations and configure an SMTP provider for reliable verification and invitations.
5. Set `url` and `anonKey` in `config.js`. The anon/publishable key is public by design; never expose `service_role`.
6. Deploy the `supabase/functions/invite-user` Edge Function with its secrets.
7. Commit the package to GitHub and enable GitHub Pages.

## Local preview
Serve this directory through a local static server (for example, `python -m http.server 8000`) and open `http://localhost:8000`. Do not use the production service_role key in the browser.


## Member Portal (updated)
Ordinary users with the `member` role see only two portal areas:
- **My profile:** membership details and self-service update of their own email/phone contact information.
- **My giving:** their own posted giving history, personal pledge progress, and a downloadable personal giving statement.

The member portal deliberately excludes church-wide events/services, attendance registration, ministry joining, announcements, church programme access, prayer requests, SMS/email/WhatsApp communications, pastoral appointment requests, testimonies, and feedback submissions.

### Enable member self-service
1. Apply `supabase_schema.sql` to a new project (or keep the already deployed schema).
2. Run `MEMBER_PORTAL_SECURITY_MIGRATION.sql` in the Supabase SQL Editor.
3. In the Church Administrator's **Users & roles** page, invite the person with the `Member` role.
4. Once the person accepts and signs in, open **Users & roles** and select **Link member** beside their user record. Choose the matching existing member-directory record.
5. The member can then sign in and see only their own profile, giving records, and pledges.

Do not link the same membership record to multiple login accounts. The database enforces one login per member record.


## Animated opening and application branding
The application now plays `Kingdom-Treasure-Animated-Logo.mp4` as a full-screen, muted introduction before revealing the sign-in screen. Users can skip the intro; a fallback removes it if autoplay is blocked. The logo asset `Kingdom_Treasure_Logo.png` is used on the sign-in screen, sidebar, and every authenticated page header. Keep both assets beside `index.html` when deploying.


### Splash playback compatibility fix
The intro video is encoded as H.264 MP4 (yuv420p, fast-start) for Chrome/Edge/Safari browser playback. `Kingdom-Treasure-Intro-Poster.jpg` displays immediately while the video loads. Keep the MP4, poster JPG and logo PNG beside `index.html`.


### Intro playback completion
The splash screen now closes only when the video emits its native `ended` event or the user selects Skip Intro. There is no fixed-duration dismissal timer and no reduced-motion early dismissal. A retry button appears only if autoplay has not started; buffering or a longer load does not shorten playback.


### Centered 8-second minimum intro
The intro video is displayed centered in a compact 480px-wide card (matching the sign-in panel width) on the same green gradient background. Playback runs at its normal speed and the splash remains visible until the video finishes, with an 8-second minimum measured from actual playback start. Users can still skip.


## Church-specific member sign-in QR
Church administrators and the developer can open **Church settings** to generate and download a QR code unique to the organisation's church ID. The QR contains the deployed application URL plus the `church` query parameter. Members scan it with their phone camera; the application opens the sign-in screen in that church context. After authentication, the app verifies that the account has the same `church_id` and has the `member` role. Accounts from other churches and non-member roles are rejected from this QR sign-in flow.

The QR is a church-specific sign-in link, not an access credential and not a public account-creation mechanism. Members must already have an account created through the church's invitation workflow and have their login linked to their existing member-directory record by an administrator. The QR generator uses the QRCode.js CDN, so the browser needs internet access when the administrator opens Church settings.


## Silent visual animation + original worship hymn update
The intro video has been rebuilt without the storyboard caption strips or text overlays. The uploaded golden-radiance image is incorporated as a clean, text-free transition/background treatment. The final video includes an original 9.875-second instrumental worship hymn, "A Heart That Gives" (organ/choir-pad/piano-style synthesized arrangement), muxed as AAC audio in the MP4. Developer credits and hymn title appear beneath the video, not over the animation. The browser attempts autoplay with sound; if its autoplay policy blocks audio, the user sees "Play intro with hymn" and can start the full audiovisual intro with one tap. The sign-in screen appears on the video's ended event, or if the user chooses Skip intro.


## Official Kingdom Treasure brand consistency
The supplied alternative emblem is not used. The original Kingdom Treasure chest/church-and-cross logo in `Kingdom_Treasure_Logo.png` is the sole brand mark used on the sign-in screen, sidebar, top navigation, favicon/app icon and the final animation reveal. The animation's final reveal was rebuilt on a clean evergreen-and-gold background using that exact original logo asset. `Kingdom-Treasure-Favicon.png` is generated from the same official logo.
