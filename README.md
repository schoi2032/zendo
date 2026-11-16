# Zendo

A calm workspace for tasks, dates, and notes. Built with Next.js, TypeScript, and Supabase.

[Open Zendo](https://schoi2032.github.io/zendo/)

## Local development

```sh
npm ci
cp .env.example .env.local
npm run dev
```

Fill in `.env.local` with your Supabase project URL and publishable key. Open http://localhost:3000.

## One-time setup

1. Create a Supabase project and run `supabase/migrations/202611160001_zendo.sql` in its SQL Editor.
2. Enable Google in Supabase Authentication. Create a Google Cloud Web OAuth client and add the callback URL shown by Supabase as its authorized redirect URI. Save the client ID and secret in Supabase.
3. Set Supabase's Site URL to `https://schoi2032.github.io/zendo/` and allow these redirect URLs:
   - `http://localhost:3000/auth/callback/`
   - `https://schoi2032.github.io/zendo/auth/callback/`
4. In GitHub repository **Settings → Secrets and variables → Actions → Variables**, add `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` (the publishable key). Never use a secret/service-role key.
5. Run **Actions → Deploy Zendo to GitHub Pages → Run workflow**. Future pushes to `main` deploy automatically.

## Checks

```sh
npm run typecheck
NEXT_PUBLIC_BASE_PATH=/zendo npm run build
```

Build checks pass. Live sign-in, persistence, invitations, and database permissions still require testing with a configured Supabase project and separate Google accounts. Invitations do not send email; share the app URL with invited teammates.
