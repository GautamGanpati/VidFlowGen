# Vidflow

<p align="center">
  <img src="asset/Image%20to%20Text.jpeg" alt="Image to Text" width="280"/>
</p>

AI-powered video generation app built with Flutter. Users describe a scene in a prompt, an AI model generates a short video, and the result is stored for **3 days** with download support.

## Features

- **Create** — Prompt-based AI video generation with recent prompt history
- **Videos** — Grid library of generated clips with expiry countdown
- **Profile** — User stats and backend connection status
- **3-day retention** — Videos auto-expire; download to device before they do
- **Dual database** — Supabase (auth, storage, source of truth) + Turso (edge metadata cache)

## Tech Stack

| Layer | Choice |
|-------|--------|
| UI | Flutter (Material 3, dark Snapchat-inspired theme) |
| State | Riverpod |
| Routing | go_router |
| Backend | Supabase (Postgres, Storage, Edge Functions) |
| Edge cache | Turso (libSQL HTTP API) |
| Downloads | gal + dio |

## Getting Started

### 1. Clone and install

```bash
cd ~/Projects/vidflow
flutter pub get
```

### 2. Configure environment

Copy the example env file and fill in your credentials:

```bash
cp .env.example .env
```

| Variable | Description |
|----------|-------------|
| `SUPABASE_URL` | Your Supabase project URL |
| `SUPABASE_PUBLISHABLE_KEY` | Supabase publishable (client) API key |
| `TURSO_DATABASE_URL` | `libsql://your-db-org.turso.io` |
| `TURSO_AUTH_TOKEN` | Turso database auth token |
| `AI_GENERATION_FUNCTION` | Edge function name (default: `generate-video`) |

The app runs in **demo mode** without credentials — it uses mock video generation.

### 3. Set up Supabase

1. Create a project at [supabase.com](https://supabase.com)
2. Run the migration in `supabase/migrations/001_initial.sql`
3. Create a storage bucket named `generated-videos`
4. Deploy the edge function:

```bash
supabase functions deploy generate-video
```

Wire your AI video provider inside `supabase/functions/generate-video/index.ts`.

### 4. Set up Turso

```bash
turso db create vidflow
turso db shell vidflow < turso/schema.sql
turso db tokens create vidflow
```

### 5. Run the app

```bash
flutter run
```

## Architecture

```
lib/
├── core/           # Theme, router, env config
├── features/       # Home, Videos, Profile screens
├── models/         # GeneratedVideo, UserProfile
├── providers/      # Riverpod providers
├── repositories/   # VideoRepository (orchestrates services)
├── services/       # Supabase, Turso, AI generation, downloads
└── widgets/        # Shared UI components
```

**Data flow:**

1. User submits prompt on Home screen
2. `VideoRepository` creates a record in Supabase and logs prompt to Turso
3. `VideoGenerationService` calls the Supabase Edge Function (or mock in demo)
4. Result is cached in Turso for fast reads; Supabase stores the canonical record
5. Videos appear in the library with a 3-day expiry badge
6. User can preview and download to their device gallery

## 3-Day Retention

- `expires_at` is set to `created_at + 3 days` on insert
- Expired videos are filtered from queries and purged from Turso cache
- Run `cleanup_expired_videos()` via pg_cron or a scheduled Edge Function in production
- Delete files from the `generated-videos` storage bucket when cleaning up

## Next Steps

- [ ] Add Supabase Auth (email/Google sign-in)
- [ ] Integrate your AI video model in the Edge Function
- [ ] Use signed URLs instead of public storage URLs
- [ ] Add push notifications when generation completes
- [ ] Schedule automated cleanup for expired storage objects
