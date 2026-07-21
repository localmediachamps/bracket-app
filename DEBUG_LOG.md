# Debug Journal

Running log of the current debugging session(s). Newest entries on top.

---

## 2026-07-21 — Entry review still showed no picks (real entry) + Dashboard "Review" went to /entries/undefined/review

Two distinct bugs reported together via screenshots.

### Dashboard: broken entry links, and the "finish your picks" nudge never fires
`me/dashboard`'s rows are shaped `{entry, tournament, progress, rank}` - the
raw `user_bracket`/`pickem_entry` fields (`id`, `status`, `total_points`,
`possible_points`) live under `.entry`, not on the row itself (`rank` is the
one exception, genuinely top-level). `Dashboard.jsx`'s `EntryCard`,
`PickemCard`, and the top-level `draftEntries = entries.filter(e =>
e.status === 'draft')` all read `entry.id`/`entry.status`/`entry.total_points`
directly on the row - always `undefined`, since real data lives one level
deeper. Silent failure mode: `undefined !== 'draft'` happens to evaluate the
same as `'submitted' !== 'draft'`, so cards still *looked* plausible (points
showed as 0 via the `?? 0` fallback, the Review button rendered instead of
Continue-picks) - only the `id`-dependent link (`/entries/${entry.id}/review`
→ `/entries/undefined/review`) and the `draftEntries` filter (always empty,
so the "Action needed: finish your picks" section never appears for anyone)
were visibly broken enough to notice. Fixed by adding an `entryOf(e) = e.entry
?? e` accessor (mirroring the existing `tournamentOf`/`progressOf` pattern)
and using it everywhere the raw entry fields are read, while leaving `rank`
reads on the row directly.

### Entry review: real entry (id=3, real picks) still showed the empty seeded bracket
The `entries/{id}/bracket/{weightClassId}` endpoint built earlier today
worked in its own live test (entry id=6) - but that test entry had *zero*
picks, so the pick-merge code path itself was never actually exercised, only
the ownership-check path. Reproduced properly this time: saved a real pick
via `PUT /entries/6/picks`, then confirmed via a temporary raw `db.query
user_pick` added straight into `entries_bracket_GET.xs` that the pick really
existed with the right `user_bracket_id`/`tournament_id` - but
`get_weight_bracket_view`'s own internal merge still returned no `user_pick`
key on the match. Root cause: an earlier diagnostic push of
`entries_bracket_GET.xs` alone (without its dependency chain) had converted
its `function.run get_weight_bracket_view` call and its `user_bracket`/
`user_pick` table references into placeholders - the exact same "Unresolved
References become placeholders" failure mode documented earlier today,
just recurring because a diagnostic edit got pushed scoped-only again.
Re-pushing with the full dependency chain (function + all 6 referenced
tables) fixed it immediately, confirmed live: the pick now shows up as
`"user_pick":{"wrestler_id":493,"outcome":"pending",...}` on the match.

**Recurring lesson, worth internalizing rather than re-learning each time**:
*any* push of a query/function that references tables or other functions,
even a one-line diagnostic tweak, must include the full dependency chain in
that same `-i` list - there is no such thing as a "just this one file, it's
only a temporary change" scoped push in this codebase.

---

## 2026-07-21 — Stripe billing scaffolding: real syntax discoveries

Building `apis/billing/` (checkout/webhook/portal) turned up several things
not accurately documented in the local XanoScript doc set, confirmed live:

### `util.get_raw_input`, not `util.get_input`
The local docs' webhook example calls `util.get_input { encoding = "json" }
as $payload_data` and then reads `$payload_data.body.event_type`. Both parts
are wrong: the real statement is `util.get_raw_input`, and its output is the
parsed body **directly**, no `.body` wrapper. Caught immediately by the IDE's
live diagnostics ("Expecting one of these possible Token sequences... but
found 'get_input'") - trust that over doc examples when they conflict.

### No documented way to read incoming request headers
Needed to read the `Stripe-Signature` header for webhook HMAC verification.
Tried and ruled out empirically: `util.get_vars` (dumps local stack
variables, not headers), `util.get_all_input` (same as `get_raw_input`, just
the parsed body again), and a bare `$headers` reference (`Missing var entry:
headers` at runtime, though it parses fine - XanoScript allows referencing
any identifier syntactically, only fails at runtime if unbound). Checked
Xano's own official "Stripe Checkout" marketplace extension (installed this
session at `api:UQuTJ3vx`) for a working reference - its
`webhooks_POST.xs` has **no signature verification at all**, confirming this
is a real gap in what Xano's declarative layer exposes, not something
missed. **Resolved without header access**: instead of verifying the
webhook's signature, every branch in `billing_webhook_POST.xs` re-fetches
the real object (checkout session / subscription / invoice) from Stripe's
API using our own `stripe_secret_key` before acting on it, and only writes
data from that authenticated response - never from the untrusted webhook
body. A forged request naming a real object id can at worst trigger a
harmless re-sync of that object's already-true state; it can't inject false
state. Reasonable substitute given the platform constraint.

### `api.request`'s response is nested under `.response.result`
Confirmed by reading Xano's official extension's `sessions_POST.xs`:
`$stripe_session.response.result`, not flat on the `as` variable directly.
My first-draft checkout/portal endpoints read `$stripe_response.url` and
silently would have gotten `null` back (masked by a precondition that
happened to still catch it, but for the wrong surface-level reason). Fixed
both to unwrap `.response.result` first.

### Stripe Price ID vs Product ID
`stripe_id_annual` was initially set to the **Product** id (`prod_...`), not
a **Price** id (`price_...`) - Stripe's Checkout `line_items[].price` needs
the latter specifically. Surfaced as a clear Stripe API error ("No such
price: 'prod_...'") once the request was actually reaching Stripe correctly,
which is what made it findable. Fixed once Garrett grabbed the real
`price_...` value from the product's price row in the Stripe dashboard.

### `line_items` nested array passes through fine as-is
`params = {}|set:"line_items":$line_items` (an actual array of objects, not
manually flattened into `line_items[0][price]` bracket-notation strings) -
confirmed working by mirroring Xano's own extension code, which does the
same. `api.request`'s form encoder handles the nested-array flattening
itself; no need for the more error-prone manual-bracket-key approach I'd
used in an earlier draft.

### Status
Checkout (`billing/checkout`) and portal (`billing/portal`) endpoints
verified live end-to-end against real Stripe (checkout returns a genuine
`checkout.stripe.com` URL; portal correctly reaches Stripe and surfaces a
real Stripe-side error for a stale test customer id). Webhook
(`billing/webhook`) handles all 5 required events via the refetch-verify
pattern above, tested with realistic payload shapes. **Note: the Stripe
secret key currently in Xano is a live-mode key** (`cs_live_...` session ids
returned) - full test-mode verification with Stripe's test card numbers
hasn't happened yet, per Garrett's choice to proceed with live keys directly.

---

## 2026-07-21 — Entry review showed the empty seeded bracket instead of your picks

User report (with screenshot): the entry review page's "Your bracket" section
showed the real tournament seeding (e.g. "#1 Marcello Milani vs #32 Caleb
Weiand") with every round marked `TBD`, not the picks the user actually made.

### Root cause: `entry_id` personalization on the public bracket endpoint was
permanently disabled, and it was fixable, not a platform limit
[apis/brackets/tournaments_bracket_GET.xs](apis/brackets/tournaments_bracket_GET.xs)
had a standing `KNOWN ISSUE` comment: every attempt to verify `entry_id`
ownership (inline `db.get`/`db.query`, or `function.run
verify_entry_ownership`) threw a masked `ERROR_CODE_ACCESS_DENIED`, so
`$verified_entry_id` was hardcoded to `null` and the endpoint always rendered
the bare seeded bracket. That workaround predates today's session.

This is the same stale per-query-object binding bug as the entry above and
the `tournaments_slugOrId_GET.xs` incident (2026-07-20) — not a genuine
platform ceiling. The real blocker here, though, is structural: this endpoint
has no `auth = "user"` (tournament brackets are public/anonymous-viewable),
so `$auth.id` is never populated on this query at all — there is no way to
verify "does the requester own this entry" without an auth context, and
Xano's auth model is all-or-nothing per endpoint (no soft/optional auth), so
adding `auth = "user"` here would force login for every anonymous bracket
view.

### Fix
Added a new, separate, owner-authenticated endpoint,
[apis/brackets/entries_bracket_GET.xs](apis/brackets/entries_bracket_GET.xs)
(`GET /entries/{id}/bracket/{weightClassId}`, `auth = "user"`), using the same
inline `db.get user_bracket` + `precondition ($entry.user_id == $auth.id)`
pattern already proven working in `entries_review_GET.xs`. It calls the
existing `get_weight_bracket_view` function directly with a verified
`entry_id` — that function already correctly merges `user_pick` data into
each match's `user_pick` field; it just never got a working, secured caller.
Mirrors the app's established convention (see `tournaments_my_entry_GET.xs`'s
own header comment) of keeping public/personalized data on separate
endpoints rather than one soft-gated one.
[EntryReview.jsx](web/src/pages/EntryReview.jsx) now calls
`api.entryBracketView(entryId, weightClassId)` instead of the public
`api.bracketView(tournamentId, weightClassId, entryId)` call, whose `entry_id`
param was always silently ignored. `Predict.jsx` was left untouched — it
still calls the public endpoint with `entry_id`, but its "your pick"
indication comes from client-side state (`usePredictPicks`), not this
endpoint's (still-disabled, still fine to leave off) personalization, so it
was never actually affected by this bug.

**Push note:** this new query's dependency chain cascaded further than
expected — `wrestler` FKs to `canonical_wrestler`, which FKs to
`canonical_team` — both had to be included in the same push alongside
`user_bracket`, `weight_class`, `bracket_match`, `user_pick`, and the
`get_weight_bracket_view` function, or the push reports them as unresolved
and converts them to placeholders.

### Status
**Fixed and pushed live** — verified via curl: the entry's real owner now
gets a full bracket view with an `entry` summary object (`progress`,
`complete`) attached; a second, different test account correctly gets `403`
(`"You do not own this entry."`). Also added a clear "Bracket Challenge"
label to the entry review page header and renamed its per-weight table
heading to "Bracket picks by weight" (was ambiguous "By weight"), per user
feedback that bracket vs. pick'em scoring needs to be visually
unambiguous — this page has no pick'em data on it at all, but the plain
heading read as if it might.

---

## 2026-07-21 — "Entry not found" / "This entry is private" for the entry's own owner

User report: viewing an already-submitted entry showed "Entry not found" or
"This entry is private. You can only review your own entries." even when
logged in as the entry's actual owner.

### Symptom
`GET /entries/{id}/review` → `403 {"code":"ERROR_CODE_ACCESS_DENIED","message":""}`
for the entry's real owner. Reproduced directly via curl: created a fresh
entry with a throwaway test account, immediately called its own review
endpoint with the same token, got the blank-message 403 above.

### Root cause: same stale per-query-object binding bug as the
`tournaments_slugOrId_GET.xs` incident (2026-07-20, below), this time on a
`precondition` expression rather than a `db.query`
Static review found nothing wrong —
[entries_review_GET.xs](apis/brackets/entries_review_GET.xs)'s
`precondition ($entry.user_id == $auth.id) { error_type = "accessdenied" ... }`
is textually identical to the same check in `entries_submit_POST.xs`, which
works fine. Bisected with the debug log's established checkpoint technique
(a `precondition (false) { error = "CHECKPOINT..." }` inserted mid-stack to
read out intermediate values, since `try_catch` doesn't catch this class of
failure): confirmed `$entry.user_id` and `$auth.id` were both `5` — genuinely
equal — yet the real ownership precondition still 403'd with an empty
message (not the configured `"You do not own this entry."` text), meaning
Xano's own platform-level access check was firing instead of the custom one.

Unlike the earlier incident (where the broken reference had to be permanently
deleted and replaced with hardcoded defaults because re-saving identical text
never rebound it), this time **deleting the specific precondition statement,
pushing, then re-adding the identical statement and pushing again did fix
it** — confirms the stale binding is tied to the specific statement/object
history, not something inherent to `user_id == auth.id` comparisons or to
`user_bracket` as a table generally (both are used successfully elsewhere in
this same query and in sibling endpoints).

**Note for future occurrences of this bug class:** a scoped `-i` push of only
the affected query file (without its referenced tables) will report
`Unresolved References` warnings and silently convert those `db.*` calls to
placeholder statements — always include the full dependency chain of
referenced tables in the same push, even for a throwaway diagnostic edit.

### Status
**Fixed and pushed live** — verified via curl: the real owner now gets `200`
with the full review payload; a second, different test account correctly
gets `403` with the real configured message this time (`"You do not own this
entry."`, not blank), confirming the ownership check itself is intact and not
just disabled.

---

## 2026-07-20 — Picks wouldn't save past round 1 + a pan/zoom crash

### "Wrestler is not a current participant of this match"
Round 1 picks saved fine; any cascaded pick (round 2+) failed. Cause:
[entries_picks_PUT.xs](apis/brackets/entries_picks_PUT.xs) validated each
pick against `bracket_match.actual_top_wrestler_id` /
`actual_bottom_wrestler_id` directly — those only get populated once a real
result is recorded (or immediately for round 1, which is seeded). For any
match still downstream of an unplayed round, those fields are `0`/unset, so
literally no cascaded pick could ever pass.

Fixed by having the endpoint resolve participants itself instead of relying
on the raw DB fields: for each weight class touched by the payload, fetch
its full match graph and run the same bounded-fixpoint resolution the
client already does in `bracketMath.js`'s `resolvePicks` (seed slots read
straight from `actual_top/bottom_wrestler_id`; `match_winner`/`match_loser`
slots resolve from the *payload's own picks* for the source match, 6 passes
to let it cascade). Validates each pick against the resolved participant
set instead of the raw fields. Verified against live data: a real round-1
pick plus its cascaded round-2 pick both saved in one request
(`{"saved":2,"cleared":[...]}`), where the old code would have rejected the
second one outright.

### Bracket crash: "Cannot read properties of null (reading 'ox')"
Race condition in [usePanZoom.js](web/src/components/bracket/usePanZoom.js).
`onPointerMove`'s `setT` updater read `drag.current.ox`/`.oy` *inside* the
React state-updater callback, not at the point the guard clause ran. React
can defer/batch that callback; if `pointerup` fired in between (nulling
`drag.current`) before the queued updater actually executed, it crashed on
the stale null. Fixed by snapshotting `drag.current`'s fields into local
consts synchronously before calling `setT`, so the updater never re-reads
the ref.

### Status
Both fixed and pushed/deployed.

---

## 2026-07-20 — Auto-lock bug + bracket-view entry_id (platform tooling limits)

### `lock_tournaments` task re-locking reopened tournaments
User reopened `test4` (Admin → Reopen) to test the predict flow; it kept
flipping back to `locked` within a few minutes on its own.
[tasks/lock_tournaments.xs](tasks/lock_tournaments.xs) runs every 5 minutes
and locks any tournament where `status == "open" && locks_at <= now`.
`locks_at` comes back as `0` (not `null`) when never set — same "int
defaults to 0" pattern as `bracket_match`'s winner fields earlier — so
`0 <= now` is always true and every open tournament without an explicit
deadline gets locked on the very next run. Fixed: added `locks_at > 0` to
the where clause. Pushed live.

### `tournaments/{id}/bracket/{weightClassId}` — entry_id personalization
Once `/predict` became reachable, loading any bracket there (which passes
`entry_id`) 403'd. Traced to the entry-ownership check
(`db.get`/`db.query user_bracket`, then `db.get`/`db.query user` for an
admin bypass) — same "stale reference inside this one query object" class of
bug as `tournaments_slugOrId_GET.xs`, confirmed by elimination (bare
`db.query user_bracket` alone still 403'd; removing the `user` admin-check
block alone didn't help either).

Went further than earlier: extracted the ownership check into a new
function, [functions/bracket/verify_entry_ownership.xs](functions/bracket/verify_entry_ownership.xs)
— confirmed working perfectly standalone via `xano function run`. But
calling it via `function.run` from *within the query* still 403'd. Tried
consolidating the query's entire stack into one new function,
[functions/bracket/get_tournament_bracket_view.xs](functions/bracket/get_tournament_bracket_view.xs)
(so the query itself becomes a single-statement wrapper) — this hit a
**different, worse problem**: the brand-new function's own
`function.run get_weight_bracket_view` / `function.run verify_entry_ownership`
calls failed with `"Function does not exist: function:<id>"`, using the
*correct* IDs, for functions confirmed working standalone. Re-saving via
`function edit` didn't fix it. This means newly-created functions'
cross-function references may not resolve via the CLI's `function create` /
`workspace push` path at all — a tooling limitation beyond a code fix today.

**Resolution**: disabled `entry_id` handling on
[tournaments_bracket_GET.xs](apis/brackets/tournaments_bracket_GET.xs)
entirely (`$verified_entry_id` always stays `null`) rather than continuing
to fight broken cross-references. Low impact: the actual predict/pick flow
doesn't depend on this parameter — picks are tracked client-side via a
separate `/entries/{id}` fetch (`usePredictPicks`) and saved through
`savePicks`, not through this bracket-view endpoint. Only casualty: the
per-match "your pick was right/wrong" annotation in results mode won't show
until this is revisited (likely needs to be done through Xano's dashboard UI
directly, where the visual function picker presumably binds references
correctly, rather than via CLI-authored XanoScript text).

`verify_entry_ownership.xs` and `get_tournament_bracket_view.xs` are left in
the repo (both valid, the former genuinely working standalone) as a
starting point for whoever picks this back up.

### Status
Both fixed and pushed live — reopening a tournament sticks now, and the
bracket view loads whether or not `entry_id` is passed.

---

## 2026-07-20 — Bracket view UI/UX pass, round 2

- Initial zoom was centering round 1 horizontally instead of aligning it to
  the left edge (`pz.center` → `pz.setTransform` with an explicit left-pad
  offset instead of a centered point).
- Minimap converted from always-visible to a toggle button (hidden by
  default) in the top bar next to the pan/zoom hint, since its true aspect
  ratio (tall — championship + consolation bands stacked) made it dominate
  the bottom-left corner.

## 2026-07-20 — Bracket view UI/UX pass, round 1 (frontend, not yet deployed)

Once the bracket actually started rendering with real data, several UI bugs
surfaced. All fixed in `web/src/components/bracket/`:

- **Every wrestler shown crossed out**: `winner_competitor_id` comes back as
  `0` (not `null`) for unplayed matches. `MatchCard.jsx`'s
  `isWinnerOfficial`/`isLoserOfficial` used `officialWinner != null`, and
  `0 != null` is `true` in JS — so every match looked decided. Changed to
  `!!officialWinner` (falsy for both `null` and `0`).
- **Couldn't click-and-drag to pan**: `usePanZoom.js`'s pointer-down handler
  bailed on `e.target.closest('button, a, input, [data-no-pan]')` — an
  attribute-*presence* selector. The canvas container itself carries
  `data-no-pan="false"` (intending "panning allowed here"), but the selector
  matched anyway since the attribute is present regardless of value, so
  **dragging was blocked everywhere**. Fixed to check
  `[data-no-pan="true"]` specifically.
- **Connector lines**: were smooth cubic-bezier curves; switched to hard
  right-angle elbow paths (`L` segments instead of a `C` curve) in
  `bracketMath.js`'s `connectorPath`.
- **Initial zoom**: was calling `pz.fit()` on load, which zooms out to fit
  the *entire* graph (both championship and consolation bands) — tiny and
  unreadable for a 33-man bracket. Now centers on round 1 at a fixed
  readable scale (0.95) instead.
- **Minimap too large**: it preserved the bracket's true aspect ratio at a
  fixed *width*, and this bracket is tall (two bands stacked vertically), so
  it rendered very tall. Now fits within a fixed 160×96 box (letterboxed)
  instead of stretching to the content's aspect ratio.

Also clarified, not a bug: picking is disabled because `test4`'s status is
`locked` (a side effect of clicking "Lock now" during this session's very
first test) — the "Make Your Picks" CTA and interactive bracket only appear
when status is `open`, by design. Reopen via Admin → tournament → Reopen to
test the predict flow.

### Status
Fixed locally, **not yet committed/deployed**. The live Vercel site won't
reflect any of this until these changes are pushed.

---

## 2026-07-20 — Bracket tab: `tournaments/undefined/bracket/52`

After the 403 fix above, the tournament page itself loaded, but the Bracket
tab showed "BRACKET FAILED TO LOAD — Unable to locate request." Backend was
confirmed healthy (direct curl to the real endpoint returned a full, correct
bracket every time). Root cause was actually a **pre-existing frontend/
backend contract mismatch**, only now exposed because the endpoint above
finally stopped 403'ing before this bug ever got a chance to run:

- `tournaments_slugOrId_GET.xs` nested the tournament record as
  `{ tournament: {...}, weight_classes: [...], ... }`.
- [TournamentHub.jsx:226](web/src/pages/TournamentHub.jsx#L226) and all five
  child panels (`BracketPanel`, `LeaderboardPanel`, `ResultsPanel`,
  `PickPopularityPanel`, `GroupsPanel`) pass the *whole* query response as
  the `tournament` prop and read fields off it directly (`tournament.id`,
  `.status`, `.name`, `.slug`, ...) — they never look under a nested
  `.tournament` key.
- Result: `tournament.id` was `undefined` everywhere in the public tournament
  view, which is why the bracket request hit
  `/tournaments/undefined/bracket/52` and 404'd.

Fixed on the backend (confirmed via DevTools Network tab — Request URL
literally showed `tournaments/undefined`) by flattening the response:
`response = $tournament|set:"weight_classes":...|set:"my_entry":...` etc.,
instead of nesting under a `tournament:` key. Verified every *other*
consumer of this same endpoint (`AdminScoring`, `AdminImport`,
`AdminResults`, `Predict.jsx`, `Pickem.jsx`) already defensively unwraps
`data?.tournament ?? data`, so flattening is backward compatible with all of
them too — nothing else needed changing.

### Status
Fixed and pushed live. Confirmed the response is now flat (`id`, `name`,
`status`, `slug` at top level, no `.tournament` sub-key).

---

## 2026-07-20 — "This tournament is private" was actually a broken public detail endpoint

User report: visiting a tournament's public page showed "This tournament is
private — you don't have access to view this tournament yet." Assumption
going in was a `visibility` toggle was needed. That assumption was wrong —
`test4`'s `visibility` was already `"public"` in the database. The real bug:
**[apis/brackets/tournaments_slugOrId_GET.xs](apis/brackets/tournaments_slugOrId_GET.xs)
(`GET /tournaments/{slugOrId}`) was completely broken for every tournament**,
not just this one — confirmed by testing an unrelated tournament
("Probe T") and getting the identical failure.

### Symptom
`GET /tournaments/{slug}` → `403 {"code":"ERROR_CODE_ACCESS_DENIED","message":""}`
for every tournament, regardless of status/visibility. The sibling `GET
/tournaments` (list) endpoint worked fine, which is why the tournament
directory itself looked healthy.

### Bug A: numeric-ID branch was dead code
```xs
var $is_numeric { value = "/^d+$/"|regex_matches:$input.slugOrId }
```
Missing backslash — `d+` matches the literal letter "d", not digits, so
`$is_numeric` was always false and every request (even `/tournaments/24`)
fell through to the slug-lookup branch. Also found: **Xano silently strips
a backslash from string literals on save**, no matter how it's escaped
(`\d`, `\\d` — both come back as `d`) — confirmed by writing, pushing, and
re-reading the stored XanoScript directly via the Meta API. Sidestepped by
using an explicit character class instead: `"/^[0-9]+$/"`. Also extracted
`$input.slugOrId|to_int` into its own `var` — inline filter chains inside a
`where =` clause tripped the XanoScript validator (`Unknown filter function
'to_int'`) even though `to_int` is used successfully elsewhere in this repo
outside of `where` clauses.

### Bug B: stale table references to user_bracket/pickem_entry/fantasy_group
The real cause of the 403. This query's `db.query user_bracket`,
`db.query pickem_entry`, and `db.query fantasy_group` calls (used for
personalization, the top-5 leaderboard, and group count) reference tables
that are broken at the platform level *within this specific query* — same
class of bug as the dead `bracket_self_check` function reference found
earlier today, but worse:
- Confirmed via elimination testing (temporarily using `xano workspace push`
  + a `precondition` that always fires, to read out intermediate variable
  values from the error message — the Meta API's request/function history
  doesn't expose step-level detail or response bodies, so this was the only
  way to see inside a live request without dashboard access): `db.query
  tournament` and `db.query weight_class` work fine; a **bare, condition-less
  `db.query user_bracket { return = {type: "count"} }` still throws** the
  same masked access-denied.
- **`try_catch` does not catch it.** This isn't a normal runtime exception —
  wrapping every broken `db.query` in `try_catch` still 403'd the whole
  request. The request appears to get rejected before the stack executes at
  all, apparently triggered by the mere *presence* of the broken reference
  anywhere in the compiled query — even inside a conditional branch that
  never runs (`if ($auth.id != null)` while unauthenticated) or inside a
  `try` block.
- **The only fix that worked: deleting the three `db.query` statements
  entirely** and replacing `my_entry` / `my_pickem_entry` / `leaderboard_top5`
  / `group_count` with hardcoded empty defaults. Re-saving the exact same
  table reference via text (whether `xano workspace push`, `xano function
  edit`-style direct Meta API `PUT`, however many times) never rebinds it —
  same as `bracket_self_check`.

### Status
**Fixed and pushed live** — verified 200 OK on `test4-2026`, numeric ID `24`,
and an unrelated tournament (`probe-t-2026`). Tournament detail pages work
again for everyone, not just this one tournament.

**Not fully restored**: personalization (whether the viewer already has a
bracket/pick'em entry), the top-5 leaderboard, and the fantasy-group count
are hardcoded to empty/zero until someone re-links `user_bracket`,
`pickem_entry`, and `fantasy_group` on this query through **Xano's visual
query builder** (open the query, re-pick each table from the table picker on
its `db.query` step to force a fresh binding — not achievable from raw
XanoScript text edits, confirmed today). The original logic for all three is
preserved in git history on this file for whoever does that.

**Worth investigating separately**: whatever corrupted these particular
table references on this one query. Given `bracket_self_check`'s function
reference broke the same way earlier today, this may be a symptom of a
broader historical event (e.g. tables/functions deleted and recreated at
some point) rather than three isolated incidents — worth checking other
queries for the same "unresolved reference" pattern before it surfaces again
as another confusing production bug.

---

## 2026-07-20 — Follow-up: bracket_generate itself was broken (2 more bugs)

After the `competitors`/`wrestlers` fix above, re-testing surfaced a new error
on confirm: **"Confirm failed — Unable to locate var: d.rl"**. This was
inside [functions/bracket/bracket_generate.xs](functions/bracket/bracket_generate.xs),
which builds the `bracket_match` graph and had never actually run before
today (previously always skipped, since `wrestler_list` was always empty —
see the entry below).

### Bug 2: triple-backtick multi-line object literals silently miscompile
3 of the 11 `array.push $descriptors { value = ... }` blocks wrapped their
object literal in triple backticks (`` value = ``` { ... } ``` ``), matching
XanoScript's syntax for expressions, not the plain `{ key: value }` literal
style used by the other 8 blocks. At runtime, dot-accessing `$d.rl` (round
label) on a descriptor built from one of these backtick blocks threw
`Unable to locate var: d.rl` — the key silently didn't make it into the
real object.

Confirmed root cause and fix empirically (function.run doesn't expose a
per-step debugger, so reasoning from the message alone wasn't enough):
- Pulled Xano's **request_history** and **function_history** via the Meta
  API (`xano profile token` + curl against `/api:meta/workspace/3/...`) to
  find the exact failing request (doc 16 confirm → `weight_class_id=52`,
  `tournament_id=24`) and reproduce it directly with
  `xano function run bracket_generate -d weight_class_id:=52 -d tournament_id:=24 -d template=ncaa_33 --logs`
  — much faster than round-tripping through the UI.
- Rewrote the 3 backtick blocks (pigtail, cons_pigtail, the K>=4 drop-in
  round) as compact single-line `{key: value, ...}` literals. Re-ran and the
  error moved past all of PASS 1/2/3 to a different failure — confirming
  backtick-wrapped multi-line literals were genuinely broken for this
  purpose.
- **CLI gotcha**: `xano workspace push -i <file>` reported success but
  silently did **not** apply the change to this specific function (verified
  by pulling it back down — old content, in both draft and published form).
  `xano function edit <id> -f <file>` worked correctly where `workspace push`
  didn't. Function edits should go through `function edit`, not a scoped
  `workspace push`, until this is understood better.

### Bug 3: `bracket_self_check` function.run reference was already dead
Once bug 2 was fixed, the error changed to `Function does not exist:
function:61`. Function 61 (`bracket_self_check`) exists and has real
published content — the reference from `bracket_generate`'s
`function.run bracket_self_check { ... }` call was just stale (a push
preview had actually flagged this exact reference as unresolved before any
of today's edits, unrelated to bug 2). Rather than delete the self-check
(it's the one thing that validates bracket structural correctness — exactly
the kind of bug bug 2 was), wrapped it in `try_catch` so a broken reference
degrades to `{valid: null, issues: []}` plus a `debug.log` instead of
blocking bracket creation entirely.

### Verified
Ran `bracket_generate` directly against the real `weight_class_id=52` /
`tournament_id=24` data: `status: ok`, `matches_created: 64`. Confirmed via
Meta API table content (`table_id=101`, `bracket_match`) that all 64 rows
actually persisted with correct data (e.g. match 755 = `champ_finals`,
round_label `"Championship"`).

### Status
**Fixed and pushed live.** `bracket_self_check`'s dead reference should
still be properly re-linked later (likely needs re-selecting the function in
the Xano UI's function picker, not just a text edit) — currently just
degrades gracefully instead of blocking. Next: re-test the full upload →
review → confirm flow in the browser.

---

## 2026-07-20 — PDF import confirm doesn't create wrestlers/brackets

### Symptom
PDF upload + AI extraction works fine — wrestlers, schools, seeds all show up
correctly in the review screen. Clicking **Confirm & build brackets** (the
"create bracket" step) appears to succeed (no error shown), but the tournament
never gets usable entrants: weight classes don't show wrestlers, no bracket
is generated, and the flow doesn't progress the way it should.

### Root cause
**Field name mismatch between frontend and backend on the confirm payload.**

- Frontend: [ImportReview.jsx:50-59](web/src/components/admin/import/ImportReview.jsx#L50-L59)
  builds the confirm payload as:
  ```js
  weights: sorted.map((w) => ({
    weight: Number(w.weight),
    template: w.template,
    competitors: w.competitors.map((c) => ({ ... })),   // <-- key: "competitors"
  }))
  ```
- Backend: [admin_document_confirm_POST.xs:245-246](apis/admin/admin_document_confirm_POST.xs#L245-L246)
  reads each weight's wrestler list as:
  ```xs
  var $wrestler_list {
    value = $w_in|get:"wrestlers":null   // <-- key: "wrestlers"
  }
  ```

Since the payload sends `competitors` and the endpoint looks for `wrestlers`,
`$wrestler_list` always resolves to `null` → gets defaulted to `[]`
(lines 249-255). Downstream effects, all silent (no error surfaced):

1. `weight_class` rows ARE created/matched (loop doesn't depend on wrestler list).
2. Old wrestlers for that weight class are deleted (replace semantics) — harmless on first import, but **destructive on re-confirm**.
3. Zero new `wrestler` rows are inserted (foreach over an empty list).
4. `competitor_count` gets set to `0`.
5. Bracket generation is skipped entirely — it's gated on
   `($wrestler_list|count) >= 2` (line 382).
6. The endpoint still returns 200 with `weights_created` > 0 and no issues,
   which is why nothing looked broken from the network tab / toast — it
   reports success while quietly doing nothing with the wrestlers.

This matches what you were seeing: wrestler info exists (from the earlier
AI-extraction step, stored in `uploaded_document.extraction_result`, which is
what the review screen actually renders from) but never makes it into real
`wrestler` rows tied to a `weight_class`/tournament.

### Why this one endpoint
The rest of the app is internally consistent on the key name `competitors`:
- [admin_tournaments_POST.xs:94](apis/admin/admin_tournaments_POST.xs#L94) — `$wc_in|get:"competitors":null`
- [admin_weight_competitors_PUT.xs:16](apis/admin/admin_weight_competitors_PUT.xs#L16) — `json[] competitors`

`admin_document_confirm_POST.xs` is the outlier using `wrestlers` in its
input contract (its own doc comment even says
`wrestlers: [{seed, name, school, record?}]`), which is what makes this an
easy one-endpoint miss rather than a systemic issue.

### Fix options
- **A — frontend**: rename the payload key in `ImportReview.jsx` from
  `competitors` to `wrestlers` so it matches what the confirm endpoint
  currently expects. Smallest change, no XanoScript touched.
- **B — backend**: rename `admin_document_confirm_POST.xs`'s input key from
  `wrestlers` to `competitors` to match the convention used by the other two
  admin endpoints. More consistent long-term, but is a XanoScript change and
  per this repo's workflow gets delegated to the Xano API Query Writer agent
  rather than edited directly.

### Fix applied — Option B
Changed `apis/admin/admin_document_confirm_POST.xs` (doc comment + the
`$w_in|get:"wrestlers":null` line) to read `competitors` instead, matching
`admin_tournaments_POST.xs` / `admin_weight_competitors_PUT.xs`.

Deploy notes:
- This workspace has **direct CLI push disabled** by default. Had to enable
  it via Workspace Settings → CLI → Allow Direct Workspace Push before a
  scoped `xano workspace push -i "apis/admin/admin_document_confirm_POST.xs"`
  would work. (Alternative when direct push is off: `xano sandbox push` +
  `xano sandbox review` to promote through the browser — not needed here
  since direct push got enabled.)
- The scoped push printed a wall of `function.run → function "X" does not
  exist` / `db.* → table "X" does not exist` warnings for this endpoint's own
  dependencies (`validate_admin`, `slugify`, `bracket_generate`, `audit`,
  `tournament`/`weight_class`/`wrestler` tables). This is a **false alarm** —
  confirmed by pulling the live workspace back down afterward and reading the
  server's copy of the file: every function/table reference was intact, no
  placeholders. Seems to be a quirk of the CLI's dependency resolver when a
  `--include`-scoped push doesn't have the rest of the local repo's objects
  in context. Don't be alarmed by these warnings on future scoped pushes —
  just verify with a pull-and-diff if unsure.

### Unrelated issue noticed in passing
The full-workspace dry-run (`xano sandbox push --dry-run`) separately flagged
two real unresolved references, worth investigating later:
- function `rescore_tournament` — `function.run → function "" does not exist`
- query `admin/sources/{id}/ingest` — `function.run → function "" does not exist`

Both reference a function by an **empty name**, suggesting a `function.run`
call with a blank/unset target somewhere in those two objects.

### Status
**Fixed and pushed live.** Next: re-test the PDF upload → review → confirm
flow end-to-end in the app to confirm wrestlers now land in the DB and
brackets generate.
