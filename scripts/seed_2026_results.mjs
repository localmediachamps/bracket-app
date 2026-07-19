/**
 * Loads real 2026 NCAA results (extracted from the completed official bracket)
 * into a tournament via the admin result-entry API.
 *
 * Prereq: the tournament exists with 10 weight classes, 33 seeds each, and
 * brackets generated (run scripts/seed_2026.mjs first if needed).
 *
 * Usage:
 *   ADMIN_EMAIL=you@x.com ADMIN_PASSWORD=secret node scripts/seed_2026_results.mjs [tournamentId]
 *
 * Skips the 30 placement bouts (601/611/621 per weight index) whose results
 * are not present in the source PDF text — enter those in the admin UI as a
 * test of the fast result-entry flow.
 */
import { readFileSync } from 'node:fs'

const AUTH = 'https://xhuf-7flt-jytp.n7d.xano.io/api:47V6PWBN'
const APP = 'https://xhuf-7flt-jytp.n7d.xano.io/api:17Ryya5W'
const ADMIN = 'https://xhuf-7flt-jytp.n7d.xano.io/api:PBpa1T2y'

const email = process.env.ADMIN_EMAIL
const password = process.env.ADMIN_PASSWORD
if (!email || !password) {
  console.error('Set ADMIN_EMAIL and ADMIN_PASSWORD (account must be is_admin).')
  process.exit(1)
}

const WEIGHTS = [125, 133, 141, 149, 157, 165, 174, 184, 197, 285]

/** PDF bout number for weight index w, round_code, match_number (1-based) */
function pdfBout(w, roundCode, matchNumber) {
  switch (roundCode) {
    case 'pigtail': return 1 + w
    case 'champ_r1': return 11 + 16 * w + (matchNumber - 1)
    case 'champ_r2': return 171 + 8 * w + (matchNumber - 1)
    case 'champ_qf': return 341 + 4 * w + (matchNumber - 1)
    case 'champ_sf': return 501 + 2 * w + (matchNumber - 1)
    case 'champ_finals': return 631 + w
    case 'cons_pigtail': return 251 + w
    case 'cons_r1': return 261 + 8 * w + (matchNumber - 1)
    case 'cons_r2': return 381 + 8 * w + (matchNumber - 1)
    case 'cons_r3': return 461 + 4 * w + (matchNumber - 1)
    case 'cons_r4': return 521 + 4 * w + (matchNumber - 1)
    case 'cons_r5': return 561 + 2 * w + (matchNumber - 1)
    case 'cons_r6': return 581 + 2 * w + (matchNumber - 1)
    case 'place_7': return 601 + w
    case 'place_5': return 611 + w
    case 'place_3': return 621 + w
    default: return null
  }
}

const results = JSON.parse(readFileSync(new URL('../docs/build/results_2026_ncaa.json', import.meta.url)))

const login = await fetch(`${AUTH}/auth/login`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ email, password }),
}).then((r) => r.json())
if (!login.authToken) {
  console.error('Login failed:', login)
  process.exit(1)
}
const headers = { 'Content-Type': 'application/json', Authorization: `Bearer ${login.authToken}` }
console.log('Logged in.')

// find the tournament
let tournamentId = process.argv[2] ? Number(process.argv[2]) : null
if (!tournamentId) {
  const list = await fetch(`${ADMIN}/admin/tournaments?per=50`, { headers }).then((r) => r.json())
  const items = list.items ?? list
  const t = items.find((x) => (x.slug || '').includes('2026') || (x.name || '').includes('2026'))
  if (!t) {
    console.error('No 2026 tournament found. Run scripts/seed_2026.mjs first (or pass a tournament id).')
    process.exit(1)
  }
  tournamentId = t.id
}
console.log('Tournament:', tournamentId)

const overview = await fetch(`${APP}/tournaments/${tournamentId}`, { headers }).then((r) => r.json())
const weightClasses = (overview.weight_classes ?? []).sort((a, b) => a.weight - b.weight)
if (weightClasses.length !== 10) {
  console.error(`Expected 10 weight classes, found ${weightClasses.length}. Seed the tournament first.`)
  process.exit(1)
}

let entered = 0
let skipped = 0
const failures = []

for (let w = 0; w < 10; w++) {
  const wc = weightClasses[w]
  const weight = wc.weight
  const view = await fetch(`${ADMIN}/admin/tournaments/${tournamentId}/bracket/${wc.id}`, { headers }).then((r) => r.json())
  const matches = view.matches ?? []
  const wrestlers = view.competitors ?? []
  const bySeed = new Map(wrestlers.map((x) => [x.seed, x]))
  const byBout = new Map()
  for (const m of matches) {
    const bout = pdfBout(w, m.round_code, m.match_number)
    if (bout) byBout.set(bout, m)
  }

  const extracted = results[String(weight)] ?? {}
  const bouts = Object.keys(extracted).map(Number).sort((a, b) => a - b)

  for (const bout of bouts) {
    const res = extracted[String(bout)]
    if (!res.winner) {
      skipped++
      continue
    }
    const match = byBout.get(bout)
    if (!match) {
      failures.push(`${weight} bout ${bout}: no bracket match (${res.round_code})`)
      continue
    }
    // winner by seed, fallback to name match
    let winner = res.winner_seed != null ? bySeed.get(res.winner_seed) : null
    if (!winner) {
      const wname = (res.winner || '').toLowerCase().replace(/[^a-z]/g, '')
      winner = wrestlers.find((x) => {
        const xn = (x.name || '').toLowerCase().replace(/[^a-z]/g, '')
        return xn && (xn === wname || xn.endsWith(wname) || wname.endsWith(xn))
      })
    }
    if (!winner) {
      failures.push(`${weight} bout ${bout}: winner '${res.winner}' not found`)
      continue
    }
    if (match.winner_competitor_id) {
      skipped++ // already has a result
      continue
    }
    const resp = await fetch(`${ADMIN}/admin/matches/${match.id}/result`, {
      method: 'PUT',
      headers,
      body: JSON.stringify({
        winner_wrestler_id: winner.id,
        victory_type: res.victory_type ?? undefined,
        score: res.score ?? undefined,
        notes: 'Seeded from official 2026 bracket PDF',
      }),
    })
    if (resp.status >= 400) {
      const body = await resp.text()
      failures.push(`${weight} bout ${bout} (match ${match.id}): HTTP ${resp.status} ${body.slice(0, 140)}`)
    } else {
      entered++
      if (entered % 50 === 0) console.log(`  ${entered} results entered…`)
    }
  }
  console.log(`${weight}: done (${entered} total)`)
}

console.log(`\nEntered: ${entered} | Skipped (no data/existing): ${skipped} | Failures: ${failures.length}`)
failures.slice(0, 20).forEach((f) => console.log('  !!', f))
console.log('\nNote: placement bouts (3rd/5th/7th) were skipped — their results are not in the source PDF text. Enter them in Admin → Results as a test of the fast-entry flow.')
