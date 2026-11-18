# Zendo

A single Command Center for links, tasks, calendar events, notes, and documents. Keep a personal space or create a shared Command Center and invite teammates. Built with Next.js, TypeScript, and Supabase, with a native Mac desktop companion.

[Open Zendo](https://schoi2032.github.io/zendo/) · [Mac download](https://schoi2032.github.io/zendo/download/)

## Develop

```sh
npm install
cp .env.example .env.local
npm run dev
```

Set the public Supabase project URL and publishable key in `.env.local`. Apply the SQL migrations in `supabase/migrations/` to your Supabase project. Enable Google in Supabase Authentication and allow the app's `/auth/callback/` URL (including the `/zendo` prefix on GitHub Pages) and your local callback. Keep Google client secrets in Supabase, never in frontend variables.

```sh
npm run typecheck
npm test
npm run build
npm run build:mac
```

The existing GitHub Pages workflow provides production configuration from repository variables. Build the Mac app before the web export when changing native code. The included Mac download is an unsigned development preview; a public Mac release requires Developer ID signing and Apple notarization.

See [Mac app implementation and release notes](docs/mac-app.md) and [future Google connections](docs/google-connections.md).
