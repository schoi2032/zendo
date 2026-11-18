# Zendo for Mac

Zendo is now a single Command Center. Account/appearance settings live in the top-bar gear. Tasks (including undated and completed reminders), notes, documents, links, and calendar-day details remain accessible inside that Command Center. The workspace selector, owner-managed invitations, membership policies, and Supabase realtime updates are retained. New Command Centers are shared workspaces; the automatic personal workspace stays private.

## Run and build

The native companion uses AppKit and WKWebView; Electron and an App Store installation are not required. It loads the existing hosted web application, so it needs an internet connection. It supports macOS 14+, Apple silicon and Intel.

```sh
npm install
npm run typecheck
npm test
npm run build:mac
open desktop/build/Zendo.app
```

The build produces `desktop/build/Zendo.app` and `public/downloads/Zendo-Mac.zip`. The `/download/` web page links to that ZIP. The ZIP is included in the Next static export, including when hosted under `/zendo/` on GitHub Pages.

For a local web preview, launch the app with `open -n desktop/build/Zendo.app --args --url http://127.0.0.1:3000/`. The URL override accepts loopback HTTP addresses only. Production origin and Supabase auth origin are configured in `desktop/Info.plist`.

## Desktop behavior

Desktop Mode fills the main screen's visible area above Finder's desktop icons and below regular application windows. It is a native clickable window; it does not change the system wallpaper image or move any files. The first activation explains this and asks for confirmation. Use the menu bar icon to show/hide Zendo, return to a window, reload, or quit. Secondary displays keep their wallpaper. Spaces, Show Desktop, Stage Manager, full-screen applications, and display reconnection need real-device checks on each supported macOS version before a public release.

Local shortcuts are selected with NSOpenPanel and stored as bookmarks in this app's local preferences. The bridge exposes opaque shortcut IDs and names, never file paths or bookmark data. No arbitrary shell command or arbitrary file-open endpoint is exposed. File shortcuts reject executable/script content, including a check when reopening; apps use the separate app picker. Shortcuts are local to this Mac and are not uploaded to shared workspaces. Launch at login uses SMAppService and can be changed in System Settings.

Calendar and reminder content currently consists of Zendo events and tasks. Apple Calendar/Reminders and Google API synchronization are not implemented. Existing Google sign-in retains its existing scopes.

## Browser authentication

Google sign-in runs through ASWebAuthenticationSession, not inside the embedded web view:

1. Supabase in the app creates the PKCE verifier and authorization URL with `skipBrowserRedirect`.
2. The native bridge checks the exact Supabase origin, Google provider, and existing HTTPS callback. It opens `/desktop-auth/` in the system browser with the authorization URL and a fresh random state in the fragment.
3. That page validates the request and stores only the native flow state in browser sessionStorage, then redirects to Google.
4. The existing `/auth/callback/` recognizes the native flow before code exchange and returns the one-use code plus state to `zendo://auth/callback`.
5. The active native session validates its state and returns the code to the original web view, which exchanges it using its own verifier. Access/refresh tokens never travel in the custom callback or native bridge.

The existing HTTPS callback URL must remain allowed in Supabase. No new Google scopes or Supabase callback URL are required. The website (including `/desktop-auth/`) must be deployed before native sign-in will work. Ordinary browser sign-in continues to use the original PKCE callback.

## Signing and public distribution

The current artifact is an **ad-hoc-signed development preview**, not a Developer ID signed or notarized release. macOS may block a quarantined download. The download page labels this; do not disable Gatekeeper or remove quarantine as a distribution strategy.

There are no valid Developer ID signing identities on this machine. To produce a public release, install the owner's Developer ID Application certificate and configure an existing Keychain notarytool profile, then run:

```sh
ZENDO_SIGNING_IDENTITY='Developer ID Application: YOUR NAME (TEAMID)' ZENDO_NOTARY_PROFILE='YOUR_KEYCHAIN_PROFILE' npm run build:mac
```

The build signs with the hardened runtime, submits the ZIP to Apple, staples the ticket to the app, recreates the download, and assesses Gatekeeper acceptance. Never put certificate private keys, Apple credentials, or notarization passwords in the repository. After signing/notarization succeeds, change the download page's preview wording to match the verified release. The Mac App Store is optional.

## Verification

TypeScript and existing item-filtering/link-safety tests pass. Browser QA with isolated fixture data exercised the single sidebar entry, undated task completion, document and note access, calendar-day events, shared Command Center creation, invitations, responsive widths, and the download link. Native compilation, universal binary architecture, plist validation, and ad-hoc signature verification pass. Real Google authorization, login-item registration, and signed/quarantined installation require an interactive release check.
