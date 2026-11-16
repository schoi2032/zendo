# Zendo

A calm workspace for tasks, dates, and notes. Next.js + TypeScript, with Supabase Google authentication, Postgres row-level security, and Realtime. Workspaces start empty. No service-role key is used in the app.

## Run locally

1. Install Node.js 22 or later and run `npm ci`.
2. Copy `.env.example` to `.env.local`. Set `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` from your Supabase project's **Connect / API keys** settings. Use the publishable or legacy anon key, never a service-role or secret key. Leave `NEXT_PUBLIC_BASE_PATH` empty locally.
3. Apply `supabase/migrations/202611160001_zendo.sql` in the Supabase SQL Editor (once on a fresh project), or use Supabase CLI migrations against your linked project.
4. Configure Google as described below, then run `npm run dev` and open http://localhost:3000.

Without Supabase configuration the app shows the welcome/setup screen. It does not simulate sign-in or seed pretend user content.

## Google OAuth — account setup required

1. In Google Cloud Console, create/select a project. Configure the Google Auth Platform consent screen, choose your audience, and add your Google accounts as test users while the app is in testing.
2. Create a **Web application** OAuth client. Set its authorized redirect URI to `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback` (copy the exact callback from Supabase's Google provider settings). Google redirects to Supabase, not directly to GitHub Pages.
3. In Supabase **Authentication → Sign In / Providers → Google**, enable Google and save your Google client ID and client secret. Keep the secret in Supabase, never in GitHub source or public environment variables.
4. In Supabase **Authentication → URL Configuration**, set the production Site URL to `https://schoi2032.github.io/zendo/`. Allow these redirect URLs:
   - `http://localhost:3000/auth/callback/`
   - `https://schoi2032.github.io/zendo/auth/callback/`
5. For a different repository, owner, or custom domain, change the production URLs to match. The app derives its callback origin from the browser and uses its build-time base path.

## Deploy to GitHub Pages

The included `.github/workflows/deploy-pages.yml` builds a static Next.js export and deploys `out/`. Supabase hosts authentication and the database; GitHub Pages hosts the frontend.

1. Open https://github.com/schoi2032/zendo/settings/pages and set **Source → GitHub Actions**. Pages must be available for your repository visibility and GitHub plan.
2. Under **Settings → Secrets and variables → Actions → Variables**, add these repository variables:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   These are public browser configuration values; row-level security protects user data. Do not enter a service-role key.
3. Push to `main` (or run **Actions → Deploy Zendo to GitHub Pages → Run workflow**).
4. Check the workflow's deploy job for the confirmed live URL. Expected address: https://schoi2032.github.io/zendo/.

The workflow derives the base path from GitHub Pages, so assets and OAuth callbacks work beneath `/zendo`. Missing Supabase variables still permit publishing the setup screen; add them and rerun the workflow to enable authentication. Variables are embedded at build time, so rebuild after changing them.

To check the Pages build locally:

```sh
npm run typecheck
NEXT_PUBLIC_BASE_PATH=/zendo npm run build
```

`npm run dev` is for local development. A static export should be served from `out/` by a static web host, rather than `next start`.

## Workspaces and security

On sign-in, `bootstrap()` creates a private personal workspace and accepts pending invitations for the authenticated user's verified email. Owners can create email invitations, revoke pending invitations, and remove other members. Invitations are database records: the app does not send email. Share the app URL with your teammate; they must sign in with the invited Google account.

All content reads and writes are scoped by Postgres row-level security to workspace membership. Invitations require ownership, personal workspaces cannot be invited to, and task assignments reference a member of the same workspace. The database enforces these rules independently of the interface. Realtime subscriptions reload workspace content after changes; focusing the window also refreshes data.

## Verification

Before using real data, configure Supabase and Google and run this acceptance check with two Google accounts and a third outside account:

- Sign in with A, add a task with a due date, refresh, and verify the task remains and appears on that date in Calendar.
- Add/edit/delete notes and events. Edit an existing note and verify the autosave status. Disconnect the network to check failed-save feedback.
- Create a shared workspace as A, invite B by email, and sign in as B in another browser profile. Verify B joins, both see edits, B cannot manage invitations or members, and B cannot access A's personal workspace.
- With outside account C, use its Supabase session to query/update known workspace item IDs through the REST API. Reads must return no rows; updates must affect no rows. Try inserting content into A's workspace and verify RLS rejects it.
- Revoke an invitation before accepting it; verify it no longer grants membership. Sign out and refresh to verify content is inaccessible.

Live OAuth, durable persistence, invitation acceptance, and RLS behavior require a configured Supabase project and test accounts. A successful TypeScript/build check alone does not verify those behaviors.
