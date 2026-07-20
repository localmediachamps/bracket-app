# TAKEDOWN — Platform Architecture & API Contract

Fantasy NCAA wrestling platform. **Stack:** Xano (backend: tables/functions/APIs/tasks) + Vite/React/Tailwind SPA on Vercel (`web/`).

This document is the binding contract for all build agents. Backend agents MUST match table names, field names, endpoint paths, and response shapes exactly — the frontend is built against them. Where XanoScript forces a deviation, note it in a `// DEVIATION:` comment and keep the JSON shape identical.

Existing Xano instance: `xhuf-7flt-jytp.n7d.xano.io`. API groups (keep existing bases):
- auth: `https://xhuf-7flt-jytp.n7d.xano.io/api:47V6PWBN`
- brackets (public + player): `https://xhuf-7flt-jytp.n7d.xano.io/api:17Ryya5W`
- admin: `https://xhuf-7flt-jytp.n7d.xano.io/api:PBpa1T2y`

Auth: Bearer token from `/auth/login` or `/auth/signup`. Admin endpoints call `validate_admin($auth.id)` first. All list endpoints that can grow unbounded accept `page` (1-based) + `per` (default 25, max 100) and return `{items:[...], total, page, per}`.

---

## 1. Data Model (Xano tables)

### user (existing — extend)
`id`, `created_at`, `name`, `email` (unique), `password`, `is_admin` (bool), **new:** `username` (text, unique, required-ish: derive from email prefix if absent), `display_name` (text), `avatar_url` (text?), `bio` (text?), `favorite_school` (text?), `updated_at` (timestamp?).

### tournament (existing — extend)
`id`, `created_at`, `name`, `year`, **new/renamed:**
- `slug` (text, unique) — url-safe, from name+year
- `description` (text?), `location` (text?)
- `start_date` (date?), `end_date` (date?)
- `locks_at` (timestamp?) — prediction deadline (existing field, keep)
- `status` (text, default `draft`) — state machine §4
- `visibility` (text, default `public`) — `public|unlisted`
- `game_modes` (json) — e.g. `["bracket","pickem"]`, default both
- `scoring_config` (json) — versioned, see §5
- `pickem_config` (json) — see §7
- `show_pick_percentages` (bool, default false) — reveal pick popularity before lock
- `allow_late_entries` (bool, default false)
- `created_by` (int? user id)
- `published_at` (timestamp?)
- `source_document_id` (int?)
- `needs_rescore` (bool, default false) — dirty flag for task-based scoring
- `entry_count` (int, default 0) — denormalized count of submitted+draft entries
- indexes: slug unique, status, year desc

### weight_class (existing — extend)
`id`, `created_at`, `tournament_id`, `weight` (int lbs), `status` (`pending|active|completed`), **new:** `name` (text — e.g. `"125 lbs"`), `display_order` (int), `bracket_template` (text, default `ncaa_33` — see §3), `bracket_size` (int? — championship field size e.g. 32), `competitor_count` (int, default 0). Unique (tournament_id, weight).

### wrestler (existing — extend; this IS the per-tournament competitor snapshot)
`id`, `created_at`, `tournament_id`, `weight_class_id`, `seed` (int), `name`, `school`, `record` (text?), `source_raw` (text?), **new:** `normalized_name` (text — lowercase, punctuation-stripped), `withdrawn` (bool, default false), `canonical_wrestler_id` (int?), `metadata` (json?). Unique (weight_class_id, seed).

### bracket_match (existing — extend; the match graph)
`id`, `created_at`, `tournament_id`, `weight_class_id`,
- `round_code` (text) — `pigtail|champ_r1..champ_r6|champ_finals|cons_r1..cons_r8|place_3|place_5|place_7`
- `round_number` (int) — ordering within `bracket_section` (championship: 1..k)
- `round_label` (text) — `"First Round"`, `"Quarterfinals"`, `"Semifinals"`, `"Championship"`, `"Blood Round"`, `"3rd Place"`…
- `match_number` (int — 1-based within round), `display_order` (int — global tiebreak for layout)
- `bracket_section` (text) — `championship|consolation|placement` (replaces `bracket_side`; keep old column name `bracket_side` if rename is risky, but value set is the new one — DECISION: rename to `bracket_section`, update all refs)
- Source slots: `top_source_type` (text?: `seed|match_winner|match_loser`), `top_source_seed` (int?), `top_source_match_id` (int?); same three for `bottom_`
- Participants: `actual_top_wrestler_id?`, `actual_bottom_wrestler_id?`
- Routing: `winner_advances_to_match_id?`, `winner_slot_in_next?` (`top|bottom`), `loser_drops_to_match_id?`, `loser_slot_in_next?`
- Result: `actual_winner_wrestler_id?`, `actual_loser_wrestler_id?` (new), `actual_winner_decision?` → renamed semantics: `victory_type` (text?: `decision|major|tech_fall|fall|medical_forfeit|injury_default|disqualification|forfeit` — keep column `actual_winner_decision` name? DECISION: add new `victory_type`, deprecate old), `actual_score` (text?), `result_notes` (text?)
- `match_status` (text, default `pending`) — `pending|in_progress|complete|corrected|cancelled`
- `version` (int, default 1) — optimistic concurrency on result entry
- `completed_at` (timestamp?), `updated_at` (timestamp?)
- `is_bye` (bool, default false) — single-participant match (auto-advances)
- indexes: (weight_class_id), (tournament_id), (round_code), unique (weight_class_id, round_code, match_number)

### user_bracket (existing — extend; the tournament ENTRY)
`id`, `created_at`, `user_id`, `tournament_id`, `total_points?` (decimal), `rank?`, `is_submitted?`, `submitted_at?`, **new:**
- `status` (text, default `draft`) — `draft|submitted|locked`
- `locked_at` (timestamp?)
- `possible_points` (decimal, default 0) — max additional points still achievable
- `correct_pick_count` (int, default 0), `scored_pick_count` (int, default 0)
- `champions_correct` (int, default 0) — correct champ_finals picks
- `finalists_correct` (int, default 0)
- `prev_rank` (int?) — for rank-change display
- `scoring_version` (int, default 1)
- `updated_at` (timestamp?)
- unique (user_id, tournament_id) already exists ✓

### user_pick (existing — extend; the PREDICTION)
`id`, `created_at`, `updated_at`, `user_bracket_id`, `user_id`, `tournament_id`, `bracket_match_id`, `picked_wrestler_id`, `is_correct?`, `points_earned?` (decimal), **new:** `points_available` (decimal, default 0 — snapshot of config value at pick time), `outcome_status` (text, default `pending`) — `pending|correct|incorrect|eliminated|void`. Unique (user_bracket_id, bracket_match_id) ✓

### fantasy_group (new)
`id`, `created_at`, `tournament_id`, `name`, `slug`, `description` (text?), `owner_id`, `privacy` (text, default `private`) — `public|unlisted|private`, `invite_code` (text, unique — 8-char Crockford base32), `member_limit` (int?), `member_count` (int, default 0), `avatar_emoji` (text, default `🤼`).

### group_membership (new)
`id`, `created_at`, `group_id`, `user_id`, `role` (text, default `member`) — `owner|admin|member`, `status` (text, default `active`) — `active|pending|removed`, `joined_at` (timestamp?). Unique (group_id, user_id).

### notification (new)
`id`, `created_at`, `user_id`, `type` (text — `tournament_open|deadline_soon|entry_incomplete|entry_locked|group_invite|group_member_joined|tournament_started|rank_change|result_entered|tournament_completed|group_final`), `title`, `body` (text?), `data` (json?), `read_at` (timestamp?). Index (user_id, created_at desc).

### audit_log (new)
`id`, `created_at`, `actor_id` (int?), `entity_type` (text), `entity_id` (int?), `action` (text), `previous_value` (json?), `new_value` (json?), `metadata` (json?). Index (entity_type, entity_id), (created_at desc).

### uploaded_document (new)
`id`, `created_at`, `uploaded_by`, `file_name`, `file` (file storage json — Xano `file` type if available, else json with `url`,`path`), `file_size` (int?), `processing_status` (text, default `uploaded`) — `uploaded|processing|needs_review|confirmed|failed`, `extraction_result` (json? — raw AI parse output), `error_message` (text?), `tournament_id` (int? — linked after confirm).

### match_result_history (new — immutable result versions)
`id`, `created_at`, `bracket_match_id`, `tournament_id`, `version` (int), `winner_wrestler_id`, `loser_wrestler_id`, `score` (text?), `victory_type` (text?), `match_status`, `change_type` (text — `entered|corrected|cleared`), `change_reason` (text?), `changed_by` (int?). Index (bracket_match_id, version desc).

### pickem_entry (new — salary-cap game)
`id`, `created_at`, `user_id`, `tournament_id`, `status` (text, default `draft`) — `draft|submitted|locked`, `points_used` (int, default 0), `tiebreaker_1/2/3` (decimal?), `total_points` (decimal, default 0), `rank` (int?), `prev_rank` (int?), `submitted_at` (timestamp?), `locked_at` (timestamp?), `updated_at` (timestamp?). Unique (user_id, tournament_id).

### pickem_pick (new)
`id`, `created_at`, `pickem_entry_id`, `tournament_id`, `weight_class_id`, `wrestler_id`, `cost` (int), `points_earned` (decimal, default 0), `breakdown` (json? — placement/win/bonus points detail). Unique (pickem_entry_id, weight_class_id).

### scoring_rule (existing) — **DELETE** (replaced by `tournament.scoring_config` json).

---

## 2. The Match Graph

A bracket is a **directed graph of `bracket_match` rows**, never visual coordinates. Each match has two participant slots (`top`/`bottom`). A slot is filled from exactly one source:

- `{type:"seed", seed:N}` — initial placement at bracket build time (first championship round + pigtails)
- `{type:"match_winner", match_id:X}` — winner of X advances here
- `{type:"match_loser", match_id:X}` — loser of X drops here (consolation / 3rd place)

Routing edges are denormalized onto each match as `winner_advances_to_match_id` + `winner_slot_in_next` (and `loser_drops_*`) so advancement is a single-row update. Invariant: slot sources and routing edges are two views of the same graph and must agree; the generator writes both.

**Advancement (result application):** when a result is recorded for match M with winner W and loser L:
1. Set M.winner/loser/status/score/victory_type, `version++`, `completed_at`.
2. Write a `match_result_history` row (version = new version).
3. If `winner_advances_to_match_id`: set that match's slot (`winner_slot_in_next`) participant = W. If `loser_drops_to_match_id`: set that slot = L.
4. Audit log entry.
5. Mark `tournament.needs_rescore = true` (task scores affected entries; or inline score for MVP scale).

**Correction:** same path with `change_type=corrected`, requires `change_reason`; recomputes downstream participant slots ONLY if the downstream matches are not yet complete. If a downstream match is already complete, return `409` with `{conflict:true, downstream_match_id}` and require the admin to correct downstream first (reverse chronological correction). Never silently overwrite.

**Bye:** a match whose one slot resolves to a seed and the other to nothing (fewer competitors than field) is stored with `is_bye=true`, `match_status=complete`, winner = the present participant; it auto-advances on generation. Byes are displayed, not predicted (excluded from picks and scoring: predictions on byes are `void`).

---

## 3. Bracket Templates

Generator function `bracket_generate(weight_class_id, template)` deletes existing matches for the weight class and rebuilds. Templates:

### `ncaa_33` (default; the real 2026 NCAA structure — 64 matches)
33 seeds. Pigtail (32v33) → feeds champ_r1 match 1 (vs seed 1); pigtail loser → cons pigtail (251). Championship: r1(16) → r2(8) → QF(4) → SF(2) → finals(1). Seed positions are the canonical official order (bouts 11–26: (1,32),(16,17),(9,24),(8,25),(5,28),(12,21),(13,20),(4,29),(3,30),(14,19),(11,22),(6,27),(7,26),(10,23),(15,18),(2,31)); later rounds pair adjacent matches.
Consolation (follow-the-leader, verified against the official completed bracket):
- cons_pigtail: L(pigtail) vs L(champ R1 mirror match #9); winner takes the mirror loser's cons_r1 #5 slot.
- cons_r1(8): adjacent R1-loser pairs, R-cycle **straight**.
- cons_r2(8): cons_r1 winners vs champ R2 losers, R-cycle **full flip** (#1 ↔ champ R2 #8).
- cons_r3(4): adjacent cons_r2 winners.
- cons_r4 "Blood Round"(4): cons_r3 winners vs champ QF losers, **flip-within-halves** (qf2, qf1, qf4, qf3).
- cons_r5 "Consolation Semis"(2): adjacent blood winners.
- cons_r6 "Consolation Finals"(2): cons_r5 winners vs champ SF losers, **full flip** (SF#2, SF#1).
- place_3 = W(cons_r6)×2; place_5 = L(cons_r6)×2; place_7 = L(cons_r5)×2.

### The R-cycle (general drop-order rule, all sizes up to 256)
The drop order of a champ round's losers into consolation depends only on the round's match count:
- 128 matches (R256): **straight** (1,2,…,128)
- 64 (R128): **full flip** (64,…,1)
- 32 (R64): **swap halves, preserve order** (17..32, 1..16)
- 16 (R32): **straight**
- 8 (R16): **full flip**
- 4 (R8/QF): **flip within halves** (2,1,4,3)
- 2 (R4/SF): **full flip**
Pairing within a consolation round is adjacent in the resulting order. Consolation-internal rounds (no champ drop) pair winners straight.

### Generic: `field_N` with N ∈ {4,8,16,32,64} championship + consolation mode `none|full`
- Competitors C ≤ N seeded 1..C. Byes = N − C (top seeds; bye matches auto-complete). Pigtails when C = N + P (P ≥ 1): pigtail j pairs seeds (N−P+j) vs (N+j), winner takes seed-position (N−P+j), loser drops to a cons pigtail against the mirror match loser (mirror = match the pigtail feeds + N/4, wrapped).
- `full` consolation scales the ncaa_33 pattern with the R-cycle above. Match totals (full consolation): N=8 → 14, N=16 → 30, N=32 (C=32) → 62, ncaa_33 → 64, N=64 → 126. N=4 or `none`: championship + place_3.

### Generic: `field_N` with N ∈ {4,8,16,32,64} championship + consolation mode `none|full`
- Competitors C ≤ N seeded 1..C. Byes = N − C (top seeds get byes: seed s has bye if paired slot seed > C).
- If C > N is impossible — admin picks template with N ≥ C. For C not a power of two, N = next power of two ≥ C… EXCEPT when C = N+1 the `pigtail` option creates one or more pigtail matches: P = C − N pigtails; pigtail j pairs seeds (N−P+j) vs (N+j), winner takes seed-position (N−P+j). (For 33 → N=32, P=1 ✓.)
- Championship rounds: r1..rK (K=log2 N), finals. round_labels by distance from end: finals=`Championship`, before=`Semifinals`, before=`Quarterfinals`, before=`Fourth Round`, `Third Round`, `Second Round`, `First Round`.
- Consolation `full` (scaled NCAA): champ r1 losers → cons_r1 (pairs within quarter); champ r2 losers → cons_r2 vs cons_r1 winners; … stagger so champ round-k losers (k < K−1) enter at cons round 2k−… (follow the ncaa_33 pattern); champ QF losers enter the blood round; SF losers → place_3; final two cons rounds → place_5/place_7. For N=8: QF losers → cons_r1(2)=blood, cons_r2(1)… simpler mapping table per size is acceptable — MUST be validated by the generator's self-check: every non-final match has a winner destination; total match count = C − 1 + (consolation matches); placements exist for 3,5,7 when `full`.
- Consolation `none`: championship only (+ optional place_3).

### Generator self-check (must run after every generate; return issues array)
- every match except finals/placements has `winner_advances_to_match_id`; consolation non-final matches likewise
- no slot has two sources; no circular references (walk ancestor closure)
- every seed 1..C appears exactly once as an initial slot (or in a pigtail)
- bye handling correct for C < N
- match count matches template expectation

---

## 4. Tournament State Machine

```
draft ──publish──▶ open ──(deadline passes / admin lock)──▶ locked ──start──▶ live ──finish──▶ completed ──▶ archived
importing ──▶ needs_review ──confirm──▶ draft
any ──▶ cancelled (audited)
live/locked ──reopen──▶ open (audited, requires reason)
```
- `draft`: editable structure, not visible to players.
- `open`: visible, predictions allowed (create/edit entries, save picks, submit).
- `locked`: no pick changes (server rejects with `423`-style inputerror unless `allow_late_entries`). Pick percentages become visible.
- `live`: results being entered; scoring active.
- `completed`: all matches complete; final standings; read-only.
- `archived`: hidden from directory, direct link still works. NEVER delete.
- Auto-transition `open→locked` via task when `locks_at` passes. `locked→live` and `live→completed` are admin actions (completed also auto-suggested when all matches complete).

Entries: `draft` (picks editable) → `submitted` (still editable until lock) → `locked` (system-locked at deadline; nothing editable). Users may submit late only if `allow_late_entries` and tournament not past lock.

---

## 5. Scoring

`tournament.scoring_config` (json, versioned — bump `version` on every edit AFTER first result; entries snapshot `scoring_version`):

```json
{
  "version": 1,
  "bracket": {
    "pigtail": 1,
    "championship": {"1": 1, "2": 2, "3": 4, "4": 8, "5": 16},
    "consolation":  {"1": 1, "2": 1, "3": 2, "4": 2, "5": 4, "6": 4},
    "placement":    {"place_3": 4, "place_5": 2, "place_7": 2},
    "champion_bonus": 0
  },
  "tiebreakers": ["total_points","champions_correct","finalists_correct","earliest_submission"]
}
```
`championship`/`consolation` map **round_number → points**. Lookup order for a match: pigtail→`pigtail`; placement section→`placement[round_code]`; else `section[round_number]`, falling back to the nearest defined lower round_number, else 1.

**Entry scoring (idempotent, deterministic):** for each user_pick on a non-bye match with a prediction: if match complete and winner == picked → `correct`, `points_earned = points_available`; if complete and winner != picked → `incorrect`, 0; if pending and picked wrestler can no longer reach the match (see below) → `eliminated`, 0. Recompute entry aggregates: `total_points = Σ points_earned`, `correct_pick_count`, `scored_pick_count` (picks on completed matches), `champions_correct`, `finalists_correct`, `possible_points`.

**Possible points:** for pending prediction P on match M with wrestler W: still achievable iff W is currently a participant in M, or W is a participant in some uncompleted match that is an ancestor of M in the graph (walk `top_source_match_id`/`bottom_source_match_id` closure). `possible_points = Σ points_available` over such predictions. (Eliminated predictions contribute 0.)

**Leaderboard:** rank by tiebreaker config. On each rescore: `prev_rank = rank` then re-rank all entries in the tournament (submitted/locked only; drafts rank after, ordered by total_points). Same for pickem (separate leaderboard).

**Rescore scope:** result entry → rescore all entries with a pick on the affected match or any descendant match, then re-rank tournament. Full rescore endpoint exists for admin. All scoring writes are idempotent (re-running yields identical totals).

**Auditability:** scoring config changes after first completed result require admin confirm + audit log; old entries keep `scoring_version` they were scored with until next rescore.

---

## 6. API Contract

Response envelope: raw JSON, no wrapper. Errors: Xano standard `{message}` with proper `error_type` (`inputerror` for validation, `accessdenied`, `notfound`, `unauthorized`).

### auth group
| Method | Path | Notes |
|---|---|---|
| POST | `/auth/signup` | {name, username?, email, password} → {authToken, user} |
| POST | `/auth/login` | {email, password} → {authToken, user} |
| GET | `/auth/me` | → user (self) |
| PATCH | `/auth/me` | {name?, username?, display_name?, avatar_url?, bio?, favorite_school?} → user |

### brackets group — public
| Method | Path | Notes |
|---|---|---|
| GET | `/tournaments` | ?status=&q=&page=&per= → cards: {id,name,slug,year,status,location,start_date,end_date,locks_at,weight_class_count,competitor_count,entry_count,game_modes} |
| GET | `/tournaments/{slugOrId}` | overview: tournament + weight_classes[] + my_entry (if auth) + my_pickem_entry + leaderboard_top5 + group_count |
| GET | `/tournaments/{id}/bracket/{weightClassId}?entry_id=` | **the money endpoint** — shape below |
| GET | `/tournaments/{id}/leaderboard?mode=bracket|pickem&page=&per=` | rows §5 + user {id,username,display_name,avatar_url}, rank_change = prev_rank − rank |
| GET | `/tournaments/{id}/results?weight_class_id=` | completed matches, newest first, paginated |
| GET | `/tournaments/{id}/pick-popularity` | per-match pick % per wrestler + champion pick % per weight. 403 unless (locked or later) or show_pick_percentages |
| GET | `/tournaments/{id}/groups?visibility=public` | public groups for a tournament |
| GET | `/groups/{id}` | group + members preview (respects privacy: members list for members/owner or public) |
| GET | `/groups/{id}/leaderboard?mode=` | entries of active members, ranked |
| GET | `/users/{id}/profile` | public mini-profile + stats + recent finishes |

**Bracket view response** (`GET /tournaments/{id}/bracket/{wc}`):
```json
{
  "weight_class": {"id":1,"name":"125 lbs","weight":125,"display_order":1,"status":"active","bracket_size":32,"competitor_count":33,"template":"ncaa_33"},
  "rounds": [{"code":"champ_r1","number":1,"label":"First Round","section":"championship","match_count":16}],
  "competitors": [{"id":11,"seed":1,"name":"Spencer Lee","school":"Penn State","record":"24-0","withdrawn":false}],
  "matches": [{
    "id":101,"section":"championship","round_code":"champ_r1","round_number":1,"round_label":"First Round",
    "match_number":1,"is_bye":false,"status":"complete","score":"7-2","victory_type":"decision","version":2,
    "top":    {"source":{"type":"seed","seed":1},"competitor":{"id":11,"seed":1,"name":"Spencer Lee","school":"Penn State","record":"24-0"}},
    "bottom": {"source":{"type":"match_winner","match_id":100},"competitor":null},
    "winner_competitor_id":11,"loser_competitor_id":12,
    "winner_dest":{"match_id":120,"slot":"top"},"loser_dest":{"match_id":140,"slot":"top"},
    "user_pick":{"wrestler_id":11,"outcome":"correct","points_available":1,"points_earned":1},
    "pick_percentage":{"top":71,"bottom":29}
  }],
  "entry": {"id":55,"status":"submitted","total_points":42,"possible_points":180,"progress":{"picked":60,"total":61},"complete":false}
}
```
`user_pick` present only when `entry_id` belongs to the requester (or admin). `pick_percentage` only per gating rule. `entry` = requester's entry for this tournament if any (same regardless of weight class).

### brackets group — player (auth required)
| Method | Path | Notes |
|---|---|---|
| POST | `/tournaments/{id}/entries` | get-or-create my bracket entry (409 if tournament not open & no entry) → entry |
| GET | `/entries/{id}` | entry + all picks (own only) |
| PUT | `/entries/{id}/picks` | {picks:[{bracket_match_id, wrestler_id}]} — bulk upsert draft picks. Server validates: entry editable (draft/submitted & tournament open & not locked), wrestler is current participant of match, match not bye/complete-locked. Clears picks that became invalid (wrestler no longer in match) and returns them: {saved:n, cleared:[match_ids], progress} |
| POST | `/entries/{id}/submit` | validates every non-bye match has a pick → {entry, missing:[...]} (422-style inputerror w/ missing list if incomplete) |
| GET | `/entries/{id}/review` | champions per weight, placement picks, incomplete matches, points breakdown |
| GET | `/entries/{id}/compare/{otherId}` | head-to-head §8 |
| POST | `/tournaments/{id}/pickem` | get-or-create pickem entry |
| PUT | `/pickem-entries/{id}` | {picks:[{weight_class_id, wrestler_id}], tiebreaker_1?, tiebreaker_2?, tiebreaker_3?} — validates budget ≤ pickem_config.budget, one per weight |
| POST | `/pickem-entries/{id}/submit` | validates all weights picked |
| GET | `/pickem-entries/{id}` | entry + picks + per-pick breakdown |
| POST | `/groups` | {tournament_id, name, description?, privacy, member_limit?, avatar_emoji?} → group + invite_code (creator = owner member) |
| POST | `/groups/join` | {invite_code} — respects privacy (private→pending unless owner invited? MVP: private groups joinable by code directly; `private_approval` deferred — keep `privacy` values public|unlisted|private, private requires code) → membership |
| POST | `/groups/{id}/leave` | owner leaving transfers to oldest member or deletes group if alone |
| PATCH | `/groups/{id}` | owner/admin only |
| DELETE | `/groups/{id}/members/{userId}` | owner/admin only |
| GET | `/me/dashboard` | my entries (w/ tournament card + progress + rank), my pickem entries, my groups, unread notification count, upcoming deadlines |
| GET | `/me/analytics` | §9 player analytics |
| GET | `/me/notifications?page=` | + `POST /notifications/read-all`, `POST /notifications/{id}/read` |

### admin group (all call `validate_admin`)
| Method | Path | Notes |
|---|---|---|
| POST | `/admin/tournaments` | full manual create: {name, year, slug?, description?, location?, start_date?, end_date?, locks_at?, visibility?, game_modes?, scoring_config?, pickem_config?, weight_classes:[{weight, template?, competitors:[{seed,name,school,record?}]}]} — creates everything, generates brackets, stays `draft` |
| PUT | `/admin/tournaments/{id}` | partial update (not while live w/o audit) |
| POST | `/admin/tournaments/{id}/publish` | draft→open (validates: ≥1 weight, all weights have competitors + generated brackets) |
| POST | `/admin/tournaments/{id}/status` | {action: lock|unlock|start|complete|archive|reopen|cancel, reason?} — audited transitions per §4 |
| POST | `/admin/tournaments/{id}/weights` | add weight class; `PUT /admin/weights/{id}` rename/reorder/template |
| PUT | `/admin/weights/{id}/competitors` | bulk replace competitors [{seed,name,school,record?,withdrawn?}] (pre-results only, or audited post-results w/ withdrawn handling) |
| POST | `/admin/weights/{id}/generate-bracket` | {template} → runs generator + self-check, returns issues |
| GET | `/admin/tournaments/{id}/bracket/{weightClassId}` | same shape as public bracket view, admin mode (includes all metadata) |
| PUT | `/admin/matches/{id}/result` | {winner_wrestler_id, victory_type?, score?, match_status?, notes?, expected_version?, change_reason?} — correction path when version>1 or match already complete; 409 on version mismatch or downstream-complete conflict (§2). Applies advancement + history + audit + flags rescore (inline rescore of affected entries OK at MVP scale) |
| DELETE | `/admin/matches/{id}/result` | {reason} — clears result, unwinds downstream participants (if not complete), history `cleared`, rescore |
| POST | `/admin/tournaments/{id}/rescore` | full idempotent rescore + re-rank |
| GET/PUT | `/admin/tournaments/{id}/scoring-config` | get/update (PUT bumps version; audited if results exist) |
| GET/PUT | `/admin/tournaments/{id}/pickem-config` | budget, seed_costs, tiebreaker labels, pickem scoring |
| POST | `/admin/tournaments/{id}/upload-pdf` | multipart `pdf_file` → stores uploaded_document, runs AI parse inline (existing `parse_bracket_pdf`, extended to also return tournament name/date), status `needs_review` → {document_id, extraction_result} |
| GET | `/admin/documents/{id}` | document + extraction_result + computed validation issues |
| POST | `/admin/documents/{id}/confirm` | {tournament_id?, name?, year?, corrections?...} → creates/updates tournament + weights + competitors + generates brackets from the (possibly corrected) extraction payload; audit; document→confirmed |
| GET | `/admin/tournaments/{id}/analytics` | §9 tournament analytics |
| GET | `/admin/audit-logs?entity_type=&entity_id=&page=` | newest first |
| GET | `/admin/tournaments/{id}/export` | full JSON snapshot (tournament, weights, competitors, matches+history, entries+picks, groups, scoring config) — historical archive export |
| GET | `/admin/tournaments` | admin list all statuses |

### tasks
- `task_lock_tournaments` (every 5 min): open & locks_at < now → locked; lock all submitted/draft entries; notify entry owners (`entry_locked`).
- `task_auto_score` (every 5 min): tournaments with needs_rescore → rescore + re-rank + clear flag (+ rank_change notifications for ±5 or new #1).
- `task_deadline_reminders` (hourly): tournaments locking in 24h±30min or 1h±10min → notify users with draft entries in that tournament (`deadline_soon` / `entry_incomplete`).

---

## 7. Pick'em (salary-cap) Mode

`tournament.pickem_config`:
```json
{"budget": 1000,
 "seed_costs": {"1":200,"2":160,"3":140,"4":120,"5":100,"6":90,"7":80,"8":70,"9":60,"10":50,"11":40,"12":30,"13":20,"14":20,"15":20,"16":20,"default":10},
 "tiebreakers": [{"key":"tiebreaker_1","label":"Tiebreaker 1","hint":"Points by 1st/2nd/3rd place teams in your group"}],
 "scoring": {"placement_points":{"1":16,"2":12,"3":10,"4":9,"5":8,"6":7,"7":6,"8":5},
             "win_points":{"championship":1,"consolation":0.5},
             "bonus_points":{"fall":2,"tech_fall":1.5,"major":1}}}
```
Pick one wrestler per weight class; Σ cost ≤ budget. Wrestler earns: placement points (final placement from bracket: champ_finals winner=1st … place_7 loser=8th; non-placing=0) + win_points per completed win by section + bonus_points by victory_type. `pickem_pick.breakdown` = {placement, wins, bonus}. Entry total = Σ picks. Same lock rules as bracket entries.

---

## 8. Head-to-Head

`GET /entries/{a}/compare/{b}` (requester must own a or b, or entry is in a shared group, or admin):
```json
{"a":{entry summary}, "b":{entry summary},
 "common_picks": n, "differing_picks": n,
 "a_correct": n, "b_correct": n,
 "decisive_matches": [{match brief + a_pick + b_pick}] (pending, picks differ, either can still score),
 "champions": {"a": {weight: name}, "b": {weight: name}}}
```

## 9. Analytics

- **Player** (`/me/analytics`): overall accuracy (correct/scored), by tournament, by weight class, by round_number, champion accuracy, current/best streaks, avg percentile, best finish, most successful weights. Derived from user_pick joined to matches.
- **Tournament** (`/admin/tournaments/{id}/analytics`): total/draft/submitted entries, group count, avg score, score histogram (10 buckets), most-picked champion per weight, pick distribution per match, top 10 most/least correctly predicted matches, completion funnel (viewed→created entry→≥50% picks→submitted), entries over time (by day).

## 10. Notifications

Types per table. Created server-side by: publish (tournament_open → all users? No — to users with entries + group members… MVP: to all users who have any entry or group in that tournament), lock, results (result_entered → entry owners affected, batched), completion, group joins, rank changes. `data` carries deep links `{tournament_id, entry_id, group_id}`.

## 11. Historical Integrity

- Completed tournaments are never deleted; `archived` only hides them.
- Every result write appends `match_result_history`; corrections keep old versions.
- Wrestler rows are per-tournament snapshots (name/school/seed as entered) + optional `canonical_wrestler_id` link for the future identity layer.
- Scoring configs are versioned; entries record `scoring_version`.
- `/admin/tournaments/{id}/export` is the structured export for the future data-science phase.
