# How I work this repo: a primer for configuring another Claude instance

This is a practical account of the tools, sequencing, and hard-won lessons from operating on this Xano + React codebase over several long sessions. It's written so you can paste relevant sections into another project's `CLAUDE.md` or hand it to an agent as onboarding context. Nothing here is Xano-specific in *spirit* — swap in your own backend's equivalents and the workflow discipline still applies.

## 1. The core loop

For any backend change, the loop is always: **write → validate → push (scoped) → test against real data → verify in the browser → commit.** Skipping steps is how "looks right" code ships broken. Every fix in this session that mattered was caught by actually running it, not by reading it twice.

1. Write/edit the source file.
2. Validate syntax with the dedicated validator tool before ever pushing (`xano_validate_xanoscript` here — use whatever your platform's equivalent static check is). This catches typos for free; it does **not** catch runtime bugs.
3. Push with a *scoped* include list, not a full workspace push. Full pushes are slow and make it hard to reason about what changed.
4. Hit the real endpoint with real data (curl, or a scratch script) and read the actual response. Don't trust that "it validated" means "it works."
5. If there's a UI, drive it with Playwright and look at the screenshot. Type-checking and validators verify syntax, not behavior.
6. Only then commit — and commit as you go, in small logical chunks. (I personally fell behind on this mid-session once and had to reconstruct several commits after the fact from `git diff` — see §6.)

## 2. CLI + push discipline

- Use the CLI's scoped push (`xano workspace push --force -i "path/to/file.xs" -i "path/to/other.xs"`) rather than a bare `push` of the whole tree. List every file you touched in one call.
- **Cross-referencing functions must be pushed together.** If function A calls function B via `function.run`, and you're pushing A, include B in the *same* `-i` batch — even if B has no code changes. Pushing the caller alone can silently leave the reference as a dead placeholder ("Function does not exist"), and this bug will not show up until you actually invoke it. Table references (`db.query`/`db.get`) don't have this problem — they resolve by name regardless of what's in the current push batch.
- The push output will print a wall of `WARNING: db.* → table "X" does not exist` / `function.run → function "Y" does not exist` lines for a scoped push. **These are false positives for anything not included in *this* batch** — the CLI just can't see tables/functions outside the current file list, but they resolve fine live. Don't chase these; only worry about a reference to something that genuinely doesn't exist anywhere.
- The platform's own "run this function directly" CLI test command can produce **false negatives** for anything that itself calls another function via `function.run` — confirmed by testing a bare single nested call in isolation. If a direct-invocation test command says a function-calling-a-function is broken, don't trust it: wire it behind a real HTTP endpoint (or its real task/trigger) and call *that* instead. This one cost real time before I figured out it was a test-harness limitation, not a real bug.
- A platform's request-timeout (502/curl timeout) on a long-running job does **not** mean the job died. If the backend keeps executing after the client disconnects (many serverless/managed backends do), poll the actual result table/row afterward instead of trusting the HTTP response. I've seen a "failed" request produce a fully successful multi-minute job every time I checked the real data afterward.

## 3. Diagnosing with scratch endpoints — and cleaning them up

When I need to inspect real backend data that no existing endpoint exposes (row counts, cross-table consistency checks, "does this data actually look like what I think it looks like"), I write a **throwaway diagnostic endpoint** rather than guessing from code alone:

- Prefix it clearly (`admin/scratch/whatever`) so it's unmistakably temporary.
- Keep it read-only. Never give a scratch endpoint a name or shape that could be mistaken for a real feature.
- **Delete it when done** — both the local source file and the live deployed endpoint (via the platform's metadata/admin API, not just `git rm`). I let four of these accumulate mid-session and had to clean them up in a batch at the end; better to delete each one right after you've used it.
- If a scratch endpoint needs to bypass an auth/role gate for convenience during debugging, say so explicitly and remove it before calling anything "done" — don't leave an unauthenticated data-dump endpoint sitting on a real deployment.

This pattern is what actually found the biggest bug of the session: a live audit endpoint against the real roster data revealed that 96 of 96 checked rows had a wrestler assigned to the wrong weight class — something no amount of code review would have surfaced, because the *validation was simply absent*, not wrong.

## 4. Playwright: the verification half of every UI change

Never mark a frontend change done from reading the diff alone.

- After any UI change, navigate to the actual route, wait for the real content to render (not just the initial shell), check console messages for errors, and take a screenshot. Read the screenshot before saying anything is fixed.
- **Always check console errors**, not just visual output — I caught a real bug (`<a>` nested inside another `<a>`, invalid HTML causing a hydration error) that looked completely fine in a screenshot but was throwing in the console.
- `browser_find` (text search over the accessibility tree) is cheaper than a full `browser_snapshot` when you just need an element's ref to click — use it to locate, then click by that ref.
- Know the actual parameter name for your click tool before you need it under pressure — I initially guessed `ref` when the real parameter was `target`, and it fails loudly enough that you'll notice, but it costs a turn.
- For anything involving a live countdown/interval query (draft state polling, etc.), give it a real wait after navigation before asserting on content — a snapshot taken too early just shows a loading skeleton, not a bug.
- If the browser session dies mid-task (extension disconnects, tab closes), `browser_tabs` with `action: "list"` tells you immediately — you'll see only a bare connect/welcome page if the real session is gone. Don't keep trying to navigate into a dead session; surface it and wait, or find another way to verify (e.g., hit the API directly with curl using a real auth token while you wait for the browser to come back).

## 5. Reproducing real user sessions without their password

To test as a specific real account without credentials, or to check data via authenticated endpoints from a script instead of a browser:

- If you have a legitimate way to obtain a bearer token for a test/demo account (a signup endpoint, a seeded test account with a known password), log in via `curl` directly against the auth endpoint and reuse the token for subsequent calls. This is far faster than driving a browser for pure data verification.
- Reading a CLI's stored credentials file directly from a sandboxed tool can be blocked in some environments — if so, either use a general-purpose shell tool that has real filesystem access (not sandboxed), or drive `fetch()` from an already-logged-in browser tab using the app's own token from local storage.
- When you need a "second opinion" identity to test multi-party flows (trades, invites, anything with two sides), create fresh, obviously-fake test accounts (`test-bot-a@yourapp-qa.example`, clear naming) rather than reusing production-adjacent accounts — makes cleanup and auditing trivial later.

## 6. Git commit discipline (a real lapse, worth stating plainly)

Over a long session with many small backend pushes, it's easy to push-and-verify a dozen files against the live backend and *forget to `git commit`* — because the push succeeded and the feature works, it *feels* done. It isn't. Uncommitted verified work is one crash away from being lost, and it desyncs what's actually deployed from what's in version control.

- Commit **after each logically-complete piece of work**, not at the end of a giant session. If you're about to move on to a genuinely different feature, that's the commit boundary.
- Periodically run a plain `git status` to check for drift between "what I've pushed to the backend" and "what I've committed" — I found eight files' worth of verified, live, tested changes sitting uncommitted after losing track during a long stretch of rapid iteration. Reconstructing the right commit grouping after the fact from `git diff` is possible but wasteful; don't let it happen in the first place.
- Never bundle unrelated fixes into one commit just because they happened to be uncommitted at the same time — group by what the change actually *does*, even when committing late.

## 7. Diagnosing bugs from first principles, not assumptions

The pattern that found every real bug this session: **assume the visible symptom has an actual root cause in the code, and go read the code path that produces it, rather than guessing at a fix.**

- "Waiver wire shows nothing" was not a rendering bug — it was a query that filtered *after* pagination instead of before, so early pages of a 5,000-row table looked empty even though thousands of valid rows existed further in. Confirmed by testing with `page=1` vs deeper pages, and by checking the raw row count.
- "Trade Center shows no trades" was not a data bug (the trade genuinely happened) — it was a query scoped to "trades involving *me*" being used for a page that's supposed to show the whole league's activity. Confirmed by dumping the raw table via a scratch endpoint and comparing to what the real endpoint returned for the same account.
- When a user reports a bug ("you drafted a 197lb guy into my 125lb slot"), don't just fix that one instance — **audit how many rows are actually affected** before deciding whether to patch-forward or rebuild the affected data. A live query across the whole demo league revealed the corruption was total (96/96), which changed the recommended fix from "patch the bad rows" to "rebuild the league" — a very different scope, and one that would've been wrong to guess at.

## 8. Escalating platform-specific gotchas to a living document

Any time a language/platform quirk costs real debugging time (a filter chain that throws a fatal error only in one specific syntactic position, a control-flow keyword that must be on its own line, a data type that silently coerces wrong), **write it down immediately** in the project's persistent instructions file, with:

- The exact failing pattern and the exact fix.
- How it was confirmed (isolated test, not "I think this is why").
- Enough context that a future session doesn't have to rediscover it via the same expensive bisection.

This project's `CLAUDE.md` has an entire accumulated section of these — every one of them was a real multi-message debugging detour the first time, and a one-line non-issue every time after because it was written down. Do this for your other project from day one; it compounds.

## 9. When to stop and ask vs. keep building

Two situations earned a check-in rather than silent forward progress, and the distinction matters:

- **A design decision with no clearly-correct default** (e.g., "should draft rounds interleave starters and bench picks, or run starters-then-bench in two blocks?") — ask, with a recommended default, rather than guess and potentially rebuild a whole subsystem on the wrong assumption.
- **Discovering the premise of a requested feature is blocked on missing data or infrastructure** (e.g., "show projected opponents" requires a real forward-looking schedule that doesn't exist anywhere in the system) — say so plainly, build the closest honest thing that *is* possible with real data, and don't quietly fabricate placeholder data to make a feature look finished. A half-built feature that's honest about its limits beats a fully-built one that's lying about where its data comes from.

Otherwise: keep going. Don't stop to ask permission for well-scoped bug fixes, don't narrate every intermediate step, and don't re-litigate a decision the user already made earlier in the session.
