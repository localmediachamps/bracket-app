/**
 * Seeds the 2026 NCAA DI Championships demo tournament via the admin API.
 *
 * Usage:
 *   ADMIN_EMAIL=you@x.com ADMIN_PASSWORD=secret node scripts/seed_2026.mjs [--publish]
 *
 * Requires the backend to be pushed to Xano first.
 */
import { readFileSync } from 'node:fs'

const AUTH = 'https://xhuf-7flt-jytp.n7d.xano.io/api:47V6PWBN'
const ADMIN = 'https://xhuf-7flt-jytp.n7d.xano.io/api:PBpa1T2y'

const email = process.env.ADMIN_EMAIL
const password = process.env.ADMIN_PASSWORD
const publish = process.argv.includes('--publish')

if (!email || !password) {
  console.error('Set ADMIN_EMAIL and ADMIN_PASSWORD env vars (account must have is_admin).')
  process.exit(1)
}

const login = await fetch(`${AUTH}/auth/login`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ email, password }),
}).then((r) => r.json())

if (!login.authToken) {
  console.error('Login failed:', login)
  process.exit(1)
}
console.log('Logged in as', login.user?.email ?? email)

const headers = {
  'Content-Type': 'application/json',
  Authorization: `Bearer ${login.authToken}`,
}

const payload = JSON.parse(readFileSync(new URL('../docs/build/seed_2026_payload.json', import.meta.url)))

// allow overriding deadline from CLI: LOCKS_AT=2026-03-19T12:00:00Z
if (process.env.LOCKS_AT) payload.locks_at = process.env.LOCKS_AT

const created = await fetch(`${ADMIN}/admin/tournaments`, {
  method: 'POST',
  headers,
  body: JSON.stringify(payload),
}).then(async (r) => ({ status: r.status, body: await r.json() }))

if (created.status >= 400) {
  console.error('Create failed:', created.status, JSON.stringify(created.body).slice(0, 800))
  process.exit(1)
}

const tournament = created.body.tournament ?? created.body
console.log(`Created tournament #${tournament.id}: ${tournament.name} [${tournament.status}]`)
const issues = created.body.issues ?? []
if (issues.length) console.log('Self-check issues:', JSON.stringify(issues, null, 1))
else console.log('Bracket self-check: clean (61 matches x 10 weights expected)')

if (publish && tournament.id) {
  const pub = await fetch(`${ADMIN}/admin/tournaments/${tournament.id}/publish`, {
    method: 'POST',
    headers,
    body: '{}',
  }).then(async (r) => ({ status: r.status, body: await r.json() }))
  console.log('Publish:', pub.status >= 400 ? `FAILED ${JSON.stringify(pub.body).slice(0, 400)}` : 'OK — tournament is open for picks')
}
