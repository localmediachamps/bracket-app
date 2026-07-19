/* Authed route probe: injects a live auth token, then walks player routes. */
import puppeteer from 'puppeteer-core'

const BASE = process.argv[2] || 'http://localhost:4173'
const TOKEN = process.argv[3]
const USER = process.argv[4] || '{}'
const ROUTES = ['/dashboard', '/groups', '/groups/new', '/profile', '/notifications', '/tournaments']

const browser = await puppeteer.launch({
  executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe',
  headless: 'new',
  args: ['--no-sandbox', '--disable-gpu'],
})

let failures = 0
for (const route of ROUTES) {
  const page = await browser.newPage()
  await page.evaluateOnNewDocument((token, user) => {
    localStorage.setItem('takedown-auth', JSON.stringify({ state: { token, user: JSON.parse(user) }, version: 0 }))
  }, TOKEN, USER)
  const errors = []
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text().slice(0, 300)) })
  page.on('pageerror', (e) => errors.push(`PAGEERROR: ${String(e).slice(0, 400)}`))
  try {
    await page.goto(BASE + route, { waitUntil: 'networkidle2', timeout: 25000 })
    await new Promise((r) => setTimeout(r, 2000))
    const text = await page.evaluate(() => document.body.innerText.replace(/\s+/g, ' ').slice(0, 140))
    const jsErrors = errors.filter((e) => !/Failed to fetch|net::|CORS|401|403|404|status of/i.test(e))
    if (jsErrors.length) failures++
    console.log(`${jsErrors.length ? 'FAIL' : 'ok  '} ${route}  | ${text.slice(0, 80)}`)
    jsErrors.slice(0, 4).forEach((e) => console.log('      ' + e))
  } catch (e) {
    failures++
    console.log(`FAIL ${route} — ${String(e).slice(0, 160)}`)
  }
  await page.close()
}
await browser.close()
console.log(failures ? `\n${failures} route(s) with JS errors` : '\nAll authed routes clean')
process.exit(failures ? 1 : 0)
