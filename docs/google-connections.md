# Google connections: next stage

The Command Center currently uses Zendo data and saved links. Calendar and Drive synchronization is not implemented or enabled by this change. Existing Google sign-in continues to use its existing permissions.

## Account setup

Use the existing Zendo Google Cloud project; do not recreate Supabase or its database.

1. Open Google Cloud → APIs & Services → Library. Enable **Google Calendar API**, **Google Drive API**, and **Google Picker API** (for selecting individual files).
2. In Google Auth Platform → Data Access, configure the Calendar read-only scope `https://www.googleapis.com/auth/calendar.readonly` and the per-file Drive scope `https://www.googleapis.com/auth/drive.file`.
3. Keep your own email and any test accounts in Audience → Test users while testing. Production release may need Google verification for the requested scopes.
4. Keep the existing Supabase redirect URI in your Web OAuth client: `https://bvmhulpfpwqdpfopucpg.supabase.co/auth/v1/callback`.
5. Keep the app callback allowed in Supabase: `https://schoi2032.github.io/zendo/auth/callback/` (and the localhost callback for development).
6. Google Picker will also need an API key restricted to the Picker API and this site's allowed HTTP referrers, plus the Google Cloud project number. For website restrictions, include `https://schoi2032.github.io/*`, `http://localhost:3000/*` for local development, and `https://docs.google.com/*` because Picker renders in Google's iframe. These are configuration values; Google OAuth client secrets belong only in the backend.

Enabling APIs alone does not connect a user's data. Zendo must implement a separate Connect action, request consent for these scopes, and handle disconnection and expired permission.

## Implementation needed

- Add personal Connected Apps settings with separate Connect/Disconnect actions for Calendar and Drive. Request extra permission only when the user chooses that connection; don't block normal Google sign-in on Calendar/Drive consent.
- Build token exchange/refresh handlers in authenticated Supabase Edge Functions. GitHub Pages can continue hosting the frontend. Store refresh tokens encrypted in a private backend-only table, with encryption/client secrets in Edge Function secrets; never in public environment variables, shared workspace items, or links.
- Supabase refreshes its own sessions, not Google API tokens. Refresh provider access separately and support permission revocation, expiration, and reconnecting.
- Start Calendar as read-only; display sources, all-day events, and the user's time zone. Don't write to Google Calendar or import a user's entire schedule into a shared workspace by default.
- Use Google Picker with `drive.file` to select individual files. This scope can permit operations on chosen files; implement only the read/open behavior needed initially. It does not grant a full-Drive search. Keep Google file access controls in place when members open saved links.
- Ask explicitly before publishing any personal external event/file details into a shared workspace. Revoking membership must also remove access to shared connection data.

Official references:
- https://developers.google.com/workspace/calendar/api/quickstart/js
- https://developers.google.com/workspace/drive/api/guides/api-specific-auth
- https://developers.google.com/workspace/drive/picker/guides/overview
- https://supabase.com/docs/guides/auth/social-sign-in
