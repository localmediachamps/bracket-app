# Mat Savvy — Fantasy Wrestling Brackets

Predict. Pick. Win. A fantasy platform for NCAA-style wrestling tournaments:

- **Bracket Challenge** — predict the winner of all 61 matches in all 10 weight classes (March-Madness-style scoring, configurable per round).
- **Pick'em Showdown** — salary-cap game: pick one wrestler per weight with a 1000-point budget.
- **Private groups** with invite codes, group leaderboards, head-to-head comparison.
- **Admin suite** — PDF bracket import (AI-assisted with human review), manual tournament builder, fast result entry, configurable scoring, analytics, full audit trail.
- **Historical archive** — results are versioned, never deleted, exportable.

## Architecture

| Layer | Tech | Location |
|---|---|---|
| Frontend | Vite + React 19 + Tailwind v4 + TanStack Query + framer-motion | `web/` |
| Backend | Xano (tables, functions, REST APIs, scheduled tasks) | `tables/`, `functions/`, `apis/`, `tasks/` |
| Hosting | Vercel (static SPA) + Xano instance `xhuf-7flt-jytp` | `vercel.json` |

Source of truth for the whole system: **`docs/build/ARCHITECTURE.md`** (data model, match graph, scoring, state machine, API contract) and **`docs/build/FRONTEND_SPEC.md`** (design system + pages).

The bracket is a **directed match graph** in the database (each match knows its slot sources and winner/loser destinations) — never hard-coded columns. The frontend derives the visual layout from the graph.

## Local development

```bash
# frontend
cd web
npm install
npm run dev          # http://localhost:5173

# production build check
npm run build
```

The frontend talks directly to the Xano API groups (no local backend needed):
- auth: `https://xhuf-7flt-jytp.n7d.xano.io/api:47V6PWBN`
- app: `https://xhuf-7flt-jytp.n7d.xano.io/api:17Ryya5W`
- admin: `https://xhuf-7flt-jytp.n7d.xano.io/api:PBpa1T2y`

## Backend sync (Xano)

Backend code is XanoScript (`.xs`) synced with the Xano VSCode extension:

1. Open the workspace in VSCode with the Xano extension connected to instance `xhuf-7flt-jytp`, workspace `Bracket App`, branch `v1`.
2. Run **XanoScript: Push all changes to Xano** (command palette) after pulling this repo.
3. Verify in the Xano dashboard that tables/functions/APIs/tasks appear.

## Seed the demo tournament (2026 NCAA DI)

All 330 wrestlers (10 weights × 33 seeds) were extracted from `2026 NCAA DI Brackets.pdf` into `docs/build/seed_2026_payload.json`.

```bash
# after pushing the backend, with an admin account:
ADMIN_EMAIL=you@x.com ADMIN_PASSWORD=secret node scripts/seed_2026.mjs --publish
```

This creates the tournament (draft), generates all 610 matches (61/weight) via the bracket engine with self-check, and optionally publishes it (open for picks).

> Tip: make your account admin first — in the Xano dashboard set `user.is_admin = true` for your row, or sign up and flip it there.

## Deployment (Vercel)

`vercel.json` is configured: build `web/` (Vite), output `web/dist`, SPA rewrite to `index.html`. Connect the repo root to Vercel; no env vars needed (API URLs are baked into `web/src/lib/api.js`).

## Repo map

```
apis/           Xano REST endpoints (authentication / brackets / admin groups)
functions/      XanoScript functions (bracket engine, scoring, groups, analytics, ai)
tables/         Xano table schemas
tasks/          Scheduled jobs (auto-lock, auto-score, deadline reminders)
web/            React SPA (see web/src/components/bracket for the bracket engine)
docs/build/     ARCHITECTURE.md + FRONTEND_SPEC.md + seed data
scripts/        seed_2026.mjs and other ops scripts
static/         LEGACY vanilla frontend (superseded by web/ — safe to delete)
```

## Known limitations (v1)

- One bracket entry + one pick'em entry per user per tournament (by design).
- Notifications are in-app only (email/push later).
- Private groups join via invite code (approval-flow groups deferred).
- External results ingestion/crawling is not in this build (data model ready).
- Score recalculation runs inline on result entry (fine at MVP scale; the `needs_rescore` flag + `auto_score` task provide the queue path for bigger fields).
