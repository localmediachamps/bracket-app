# TAKEDOWN — Frontend Specification

Vite + React 18 + Tailwind CSS SPA in `web/`. React Router v6, TanStack Query, zustand, framer-motion, lucide-react, canvas-confetti. Deployed on Vercel (SPA rewrites). Talks to Xano per `docs/build/ARCHITECTURE.md` §6 — treat those shapes as truth.

## Brand & Design Language

**Name:** TAKEDOWN — *Fantasy Wrestling Brackets*.
**Vibe:** A dark arena at night — spotlight on the mat. Premium sports product (think ESPN x Linear x a fight-night poster). Dramatic, kinetic, confident. No purple/blue gradients, no generic SaaS look.

### Tokens (Tailwind config)
- `mat` (bg scale): 950 `#0A0A0B` (page), 900 `#101012` (surface), 850 `#16161A` (card), 800 `#1D1D22` (raised), 700 `#26262D` (border-ish), 600 `#34343D`
- `gold`: 300 `#FFD87A`, 400 `#F5C44F`, 500 `#E8AE2E` (primary accent), 600 `#C08F1E` — champion gold
- `blood`: 400 `#F0564A`, 500 `#D93A2E` — losses, incorrect, admin danger
- `pin`: 400 `#3ECF8E`, 500 `#22B573` — wins, correct, live green
- `ink`: 100 `#F4F1EA` (warm off-white text), 300 `#C9C6BC`, 500 `#8B887C` (muted), 600 `#5C5A52`
- Fonts: `Archivo` (UI, 400–800) + `Archivo Black` (display/headlines, uppercase, tight tracking) + `JetBrains Mono` (scores, seeds, numbers). Google Fonts link in index.html.
- Radius: cards `rounded-xl`, pills `rounded-full`, matches `rounded-lg`. Shadows: `shadow-glow` = `0 0 40px -8px rgb(232 174 46 / 0.25)`.
- Texture: subtle diagonal mat-stripes utility class `.bg-mat-stripes` (repeating-linear-gradient 45deg, white 2% alpha) for BYE/empty slots and hero backdrop; `.bg-arena` radial spotlight (gold 6% → transparent) at page top.

### Core components (`src/components/ui/`)
Button (variants: primary gold, secondary outline, ghost, danger; sizes sm/md/lg; loading spinner), Card (glass: mat-850 + border mat-700 + hover border-gold/30 transition), Badge/StatusPill (tournament & match states with dot pulse for live), Input/Select/Textarea (dark, gold focus ring), Tabs (underline slide), Modal (framer-motion scale/fade), Toast (sonner-style hand-rolled: top-right stack), Skeleton, EmptyState (illustrative icon + CTA), Avatar (initials, gold ring for admins/champs), ProgressRing (SVG, for weight completion), Stat (big mono number + label), Tooltip, Drawer (mobile), Dropdown, Switch, SearchInput (cmdk-style), Countdown (flip-ish timer to deadline), ConfettiBurst helper.

### Layout
`AppShell`: sticky top nav (logo "TAKEDOWN" in Archivo Black w/ gold takedown-figure mark, links: Tournaments, Groups, Dashboard; right: notifications bell w/ unread dot, avatar dropdown). Mobile: bottom tab bar (Tournaments, Dashboard, Groups, Profile) + top bar with logo+bell. Max width 1280px, px-4. Admin pages get an `AdminShell` with left rail (icons+labels, collapsible) inside content area.
Footer: minimal, "Built for wrestling fans" + year.

### Motion & delight
Page transitions: 150ms fade+rise. Staggered card entrances. Animated number tickers on stats/leaderboard points. Confetti on entry submit + group create. Gold shimmer sweep on the champion match card. Bracket pick: slot fills with gold flash, connector line animates draw to next match. Skeletons everywhere data loads. Respect `prefers-reduced-motion`.

## The Bracket Engine (`src/components/bracket/`)

`BracketView` — reusable, mode-driven: `predict | results | readonly | compare | admin`.
- **Layout from the match graph only.** Columns = rounds: championship rounds left→right (pigtail shares col 1 area or its own col 0 when present), placement matches as a final column; consolation rounds as a second band below championship, also left→right. Row position: leaf (source-type seed) matches get sequential rows; every other match's y = mean of its source matches' y (resolve via `winner_dest`/`loser_dest` graph edges + slot sources). Consolation band ordered to mirror the championship rows of their feeding matches.
- **MatchCard**: two slots; each slot shows seed chip (mono, mat-700), name (semibold, truncate), school (muted, xs). States: empty/TBD (striped), bye (striped + "BYE"), pickable (hover: border-gold, translate-y-px), picked (gold left-bar + gold name), correct (pin left-bar + ✓ + `+N pts` chip), incorrect (blood left-bar + ✗, strikethrough name), eliminated (dimmed + "ELIM" tag), live (pulsing dot), official winner (bold + trophy micro-icon on finals).
- **Connectors**: SVG overlay, elbow paths from match right edge to destination slot left edge (computed from laid-out DOM rects, redrawn on layout/zoom). Picked path: gold, animated draw (stroke-dashoffset). Official winner path: pin. Compare mode: diverging picks highlighted blood vs pin.
- **Pan/zoom**: container with CSS transform scale + translate; buttons (+/−/fit), wheel-zoom (ctrl), drag-pan, pinch on touch. Zoom range 0.35–1.6. "Fit" computes bounding box. Minimap (bottom-right, click-to-navigate) on desktop.
- **Round headers**: sticky top row per column with label + match count.
- **Weight rail**: horizontal scrollable pill tabs per weight class with ProgressRing of user's picks; active = gold.
- **Predict interactions**: click slot → pick; click again → unpick (clears downstream cascade); propagation: winner auto-fills destination slot; changing an earlier pick clears downstream picks that referenced the displaced wrestler (toast: "3 downstream picks cleared"). All client-side from the graph; autosave debounce 800ms → `PUT /entries/{id}/picks`; optimistic w/ rollback toast on error.
- **A11y**: each slot a `<button>` with aria-label ("Pick Spencer Lee, seed 1, Penn State, First Round match 1"); arrow-key navigation between matches; bracket also has a "List view" toggle (rounds as accordions of match rows — doubles as the small-screen fallback and SR-friendly path).
- **Mobile**: horizontal scroll snap columns, pinch zoom, list-view toggle prominent; weight rail sticky.

## Pages

Routes (React Router). `*` = auth required, `**` = admin required.

### Public
- `/` **Landing**: full-bleed dark hero — giant Archivo Black "PREDICT EVERY MATCH." over arena spotlight, animated bracket lines drawing in background (SVG), gold CTA "Browse Tournaments" + secondary "How it works". Sections: live/upcoming tournament cards (real data), "Two ways to play" (Bracket Challenge vs Pick'em Showdown cards), how-it-works 3-step, leaderboard teaser (top 5 of flagship tournament), footer. Marketing polish: big numbers, marquee of schools, subtle grain.
- `/login`, `/register`: centered card over arena bg; split layout on desktop (left: brand panel w/ quote + bracket art; right: form). Error shake, success redirect.
- `/tournaments` **Directory**: filter chips by status (All/Open/Locked/Live/Completed), search, sort (date, popularity). Cards: name (Archivo Black), status pill, date/location, stats row (weights, competitors, players), deadline countdown for open ones, hover lift + gold border. Staggered entrance, skeleton grid.
- `/tournaments/:slug` **Tournament hub**: header (name, meta, status, countdown, CTA button contextual: "Make Your Picks" / "View Bracket" / "Enter Pick'em"), tab bar: **Bracket** (weight rail + BracketView readonly or predict-aware), **Leaderboard** (mode toggle bracket/pickem: podium top-3 cards w/ medals, table w/ rank-change arrows, accuracy bars, pagination; highlight self row), **Pick Popularity** (after lock: per-weight champion pick bars, per-match popularity heat on bracket, contrarian badges), **Results** (filterable feed by weight/round, victory-type badges), **Groups** (public groups + create/join CTAs).
- `/groups/:id` public group page: name, emoji avatar, member list w/ avatars, group leaderboard, join button (code pre-filled via `?code=`).
- `/users/:id` public profile: avatar, stats cards, finish history.

### Player `*`
- `/dashboard`: greeting header w/ streak flame; "Action needed" strip (incomplete entries, deadlines); my entries as rich cards (tournament art, rank, points, possible points sparkbar, progress ring, CTA continue/submitted/locked states); my pick'em entries; my groups row; recent notifications preview.
- `/tournaments/:slug/predict` **Prediction editor**: the crown jewel. Header: tournament + deadline countdown + overall progress bar + Save state indicator ("Saved ✓" / "Saving…"). Weight rail with per-weight progress rings. BracketView mode=predict. Right/bottom summary drawer: my champions grid (weight → name), unresolved matches list (click scrolls+zooms to match), Submit button (disabled until complete, tooltip explains). Submit → review modal (champions summary + warning about lock) → confetti → status submitted.
- `/tournaments/:slug/pickem` **Pick'em editor**: budget meter (gold, animated, "640 / 1000"), weight rows: each shows budgeted cost chip + opens a picker drawer: sortable/searchable wrestler table (seed, name, school, record, cost), seed-cost legend sidebar (like UI Example 2 but beautiful), tiebreaker inputs, submit flow. Points-used bar per pick, over-budget shake + blood highlight.
- `/entries/:id/review`: read-only bracket + per-round points breakdown (earned vs available), correct/incorrect tallies, champions list.
- `/compare/:aId/:bId` **Head-to-head**: split header (two avatars, totals, "you lead by 12"); stat comparison bars; decisive-matches list ("these 7 pending matches separate you"); shared picks vs differing picks tabs; per-weight champion comparison table.
- `/groups`: my groups cards + join-by-code input + create button.
- `/groups/new`: form w/ privacy explainer cards, emoji picker, live invite-link preview. Success screen: big invite code + copy buttons + share link.
- `/profile`: edit form (avatar url, display name, username, favorite school, bio); stats dashboard (accuracy donut, by-weight bars, by-round bars, streaks, finishes table) — recharts NOT allowed; hand-roll tiny SVG bar/donut components.
- `/notifications`: list w/ type icons, unread highlight, mark-all-read, deep links.

### Admin `**` (`/admin`, AdminShell left rail: Dashboard, Tournaments, [current tournament: Overview, Builder, Import, Results, Scoring, Analytics], Audit Log)
- `/admin`: stat cards (tournaments by status, total players, entries, results entered), recent audit activity feed, quick actions.
- `/admin/tournaments/new` **Wizard**: step 1 choose path — "Upload PDF" vs "Build manually" (two big cards). Manual: basics form → weight classes editor (add weights, paste/type competitor lists w/ seed-school-name quick-parse from textarea lines: `1 Spencer Lee Penn State`) → template picker per weight (ncaa_33 / field sizes + consolation toggle) → scoring config (sliders/inputs w/ presets "NCAA Standard", "March Madness") → review & create. PDF path: upload dropzone → processing state (animated steps: upload→extract→structure→review) → **Import review**: extracted weights/competitors table w/ inline edit, uncertainty highlights (missing seed/school rows flagged blood), validation issues panel (dupes, seed gaps), bracket preview per weight, confirm → tournament created (draft).
- `/admin/tournaments/:id`: hub — status card w/ transition buttons (publish/lock/start/complete/archive/reopen w/ reason modal), countdown, entry stats, completion %, links to sub-pages, danger zone (cancel).
- `/admin/tournaments/:id/builder`: weights list; per weight: competitor table (inline edit rows, add/remove, withdrawn toggle), generate/regenerate bracket button w/ self-check issues display, bracket preview.
- `/admin/tournaments/:id/results` **Fast result entry**: weight tabs; match list grouped by round (list, not bracket — speed); each pending match: two competitor buttons, click winner → victory type + score quick row (chips: Dec/Major/TF/Fall + score input) → save (keyboard: Enter advances to next). Completed: shows winner, edit → correction modal (requires reason, shows version, warns if downstream complete → blocked w/ explanation), clear result. Progress per weight. Optimistic UI.
- `/admin/tournaments/:id/scoring`: bracket scoring grid (section × round → points inputs), placement points, champion bonus, tiebreaker order drag-list, pick'em config (budget, seed-cost table editor, scoring values), save w/ version bump warning when results exist.
- `/admin/tournaments/:id/analytics`: stat cards (entries, completion funnel), most-picked champions grid, pick distribution bars per weight champion, score histogram, hardest/easiest matches tables, entries-over-time area chart (hand-rolled SVG).
- `/admin/audit`: filterable table (entity, action, actor, time), expandable rows showing prev→new diff.

### Responsive rules
- <640px: bottom tabs, single column, bracket list-view default, drawers instead of sidebars, tables → stacked cards, hide minimap.
- 640–1024: rail collapses to icons, 2-col grids.
- \>1024: full layouts, bracket canvas default.
- Touch targets ≥ 44px; no hover-only interactions.

### Quality bar
No console errors; every fetch has loading + error + empty states; forms validate inline; all mutations optimistic where safe; focus-visible rings; color never sole indicator (icons + text too).
