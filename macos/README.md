# Zendo Desktop

A local Mac menu-bar companion that displays the Zendo website as a live desktop dashboard. It uses the same Supabase data and workspace permissions. Requires macOS 13+ and Apple's Command Line Tools to build.

```sh
bash macos/test.sh
bash macos/build.sh
open "macos/build/Zendo Desktop.app"
```

The app is built locally and ad-hoc signed. It isn't notarized for distribution to other Macs. No existing wallpaper, desktop files, login items, or system preferences are changed.

## One-time Google sign-in setup

In your existing Supabase project, open **Authentication → URL Configuration → Redirect URLs** and add exactly:

```text
com.zendo.desktop://auth/callback
```

Keep the existing Google Cloud Supabase callback and website redirect URLs. No new Google client, client secret, database, or migration is needed for this desktop companion.

The app opens in a regular window while signed out. After sign-in succeeds (or an existing session is restored), it moves to desktop mode. Signing out returns to a regular window.

Start Google sign-in from inside Zendo Desktop. The companion opens an `ASWebAuthenticationSession` in the system browser, then sends only the one-use code back to the original webview. Its existing PKCE verifier remains in that webview's persistent local storage. Do not sign in in an unrelated browser tab and copy the callback URL.

## Use

Click **Z** in the Mac menu bar:

- **Show Command Center:** put the signed-in dashboard behind ordinary windows on all normal Spaces. While signed out, show the normal sign-in window.
- **Open as Window:** use a regular resizable window for focused editing and sign-in.
- **Hide Dashboard:** reveal your original desktop and Finder icons.
- **Click Through to Desktop:** turn off dashboard clicks so Finder can receive them. Turn it off to edit Zendo again.
- **Display:** choose which monitor shows the dashboard.
- **Dashboard Address:** defaults to `https://schoi2032.github.io/zendo/`. For local changes, run `npm run dev` and set it to `http://localhost:3000/`. Browser and companion sessions are separate; switching origins requires signing in again.
- **Quit:** remove the dashboard and menu-bar item.

A clickable dashboard sits above Finder's desktop icons, below ordinary app windows. It covers the icons while visible; hide it to use them. Full-screen apps may cover the dashboard. The chosen display and dashboard address persist; click-through resets on relaunch so it cannot strand you with an unclickable dashboard.

Closing the regular window hides the dashboard; it does not quit the app. Quit from the Z menu. Reopen the built app manually when needed; automatic launch at login is not enabled.

Links open in your browser. Uploads use the Mac file picker. Offline pages show Retry. Returning to the app or waking the Mac refreshes workspace data without reloading an open editor.

## Verification limits

The native build and routing tests can validate compilation, allowed origins, callback routing, and PKCE challenge preservation. Google consent/return, Space layering, display switching, Finder interaction, and file dialogs require interactive testing on the Mac. They are not guaranteed by a successful compile alone.
