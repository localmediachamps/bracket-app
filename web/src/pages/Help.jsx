import React, { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { motion } from 'framer-motion'
import {
  LifeBuoy,
  Rocket,
  GitBranch,
  Scale,
  Trophy,
  Users,
  Swords,
  Eye,
  CreditCard,
  HelpCircle,
  ChevronDown,
  Crown,
  Medal,
  ArrowRight,
} from 'lucide-react'
import { Card, Badge } from '../components/ui'
import { cn } from '../lib/utils'

const SECTIONS = [
  { key: 'getting-started', label: 'Getting Started', icon: Rocket },
  { key: 'bracket', label: 'Bracket Challenge', icon: GitBranch },
  { key: 'pickem', label: "Pick'em Showdown", icon: Scale },
  { key: 'leaderboard', label: 'Master Leaderboard', icon: Trophy },
  { key: 'groups', label: 'Groups', icon: Users },
  { key: 'leagues', label: 'Fantasy Draft Leagues', icon: Swords },
  { key: 'privacy', label: 'Privacy & Visibility', icon: Eye },
  { key: 'pricing', label: 'Pricing & Plans', icon: CreditCard },
  { key: 'faq', label: 'FAQ', icon: HelpCircle },
]

function ScoreTable({ rows, cols = ['Result', 'Points'] }) {
  return (
    <div className="overflow-hidden rounded-xl border border-mat-700">
      <table className="w-full text-sm">
        <thead>
          <tr className="bg-mat-850 text-left text-[10px] font-bold uppercase tracking-[0.14em] text-ink-500">
            {cols.map((c) => (
              <th key={c} className={cn('px-4 py-2.5', c !== cols[0] && 'text-right')}>
                {c}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((r, i) => (
            <tr key={i} className="border-t border-mat-700/60">
              {r.map((cell, j) => (
                <td key={j} className={cn('px-4 py-2.5', j === 0 ? 'font-semibold text-ink-100' : 'text-right font-mono font-bold text-gold-400')}>
                  {cell}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

function Section({ id, icon: Icon, title, children }) {
  return (
    <section id={id} className="scroll-mt-24 border-b border-mat-800 py-10 first:pt-0 last:border-b-0">
      <div className="mb-5 flex items-center gap-3">
        <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-gold-500/12 text-gold-400">
          <Icon size={18} />
        </span>
        <h2 className="font-display text-xl uppercase tracking-wide text-ink-100">{title}</h2>
      </div>
      <div className="space-y-4 text-sm leading-relaxed text-ink-300 [&_h3]:mb-2 [&_h3]:mt-6 [&_h3]:font-display [&_h3]:text-sm [&_h3]:uppercase [&_h3]:tracking-wide [&_h3]:text-ink-100 [&_ol]:list-decimal [&_ol]:space-y-1.5 [&_ol]:pl-5 [&_ul]:list-disc [&_ul]:space-y-1.5 [&_ul]:pl-5 [&_strong]:font-bold [&_strong]:text-ink-100">
        {children}
      </div>
    </section>
  )
}

function FaqItem({ q, children }) {
  const [open, setOpen] = useState(false)
  return (
    <Card className="overflow-hidden p-0">
      <button
        onClick={() => setOpen((o) => !o)}
        className="flex w-full items-center justify-between gap-4 px-5 py-4 text-left text-sm font-semibold text-ink-100 hover:text-gold-300"
        aria-expanded={open}
      >
        {q}
        <ChevronDown size={16} className={cn('shrink-0 text-ink-500 transition-transform', open && 'rotate-180 text-gold-400')} />
      </button>
      {open && <div className="border-t border-mat-700/60 px-5 py-4 text-sm leading-relaxed text-ink-400">{children}</div>}
    </Card>
  )
}

export default function Help() {
  const [active, setActive] = useState(SECTIONS[0].key)

  // Client-side navigation (<Link to="/help#leagues">) doesn't get the
  // browser's native hash-scroll behavior since the page never reloads -
  // scroll to the target section manually once it's actually in the DOM.
  useEffect(() => {
    const hash = window.location.hash.replace('#', '')
    if (!hash) return
    const el = document.getElementById(hash)
    if (el) {
      el.scrollIntoView({ block: 'start' })
      setActive(hash)
    }
  }, [])

  useEffect(() => {
    const onScroll = () => {
      const offsets = SECTIONS.map((s) => {
        const el = document.getElementById(s.key)
        return { key: s.key, top: el ? el.getBoundingClientRect().top : Infinity }
      })
      const current = offsets.filter((o) => o.top <= 140).pop() ?? offsets[0]
      setActive(current.key)
    }
    window.addEventListener('scroll', onScroll, { passive: true })
    onScroll()
    return () => window.removeEventListener('scroll', onScroll)
  }, [])

  const jump = (key) => (e) => {
    e.preventDefault()
    document.getElementById(key)?.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }

  return (
    <div>
      <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.4 }} className="mb-8">
        <span className="mb-3 inline-flex items-center gap-2 rounded-full border border-gold-500/30 bg-gold-500/10 px-3 py-1 text-[10px] font-bold uppercase tracking-[0.16em] text-gold-400">
          <LifeBuoy size={12} /> Help Center
        </span>
        <h1 className="font-display text-2xl uppercase tracking-wide text-ink-100 sm:text-3xl">Everything about how Mat Savvy works</h1>
        <p className="mt-2 max-w-2xl text-sm text-ink-500">
          Every rule, every scoring formula, every setting — in one place. Use the menu to jump to a section.
        </p>
      </motion.div>

      <div className="grid gap-8 lg:grid-cols-[220px_1fr]">
        {/* ── Section nav ─────────────────────────────────── */}
        <nav className="lg:sticky lg:top-20 lg:self-start">
          <div className="flex gap-1 overflow-x-auto no-scrollbar pb-2 lg:flex-col lg:overflow-visible lg:pb-0">
            {SECTIONS.map((s) => (
              <a
                key={s.key}
                href={`#${s.key}`}
                onClick={jump(s.key)}
                className={cn(
                  'flex shrink-0 items-center gap-2.5 whitespace-nowrap rounded-lg px-3 py-2 text-sm font-semibold transition-colors lg:whitespace-normal',
                  active === s.key ? 'bg-gold-500/12 text-gold-400' : 'text-ink-500 hover:bg-mat-800 hover:text-ink-200'
                )}
              >
                <s.icon size={15} className="shrink-0" /> {s.label}
              </a>
            ))}
          </div>
        </nav>

        {/* ── Content ──────────────────────────────────────── */}
        <div>
          <Section id="getting-started" icon={Rocket} title="Getting Started">
            <p>
              Mat Savvy is a wrestling fantasy platform built around real NCAA results. Create a free account, browse{' '}
              <Link to="/tournaments" className="font-semibold text-gold-400 hover:text-gold-300">
                open tournaments
              </Link>
              , and enter a <strong>Bracket Challenge</strong>, a <strong>Pick'em Showdown</strong>, or both — they score
              independently, so doing well in one doesn't cost you anything in the other.
            </p>
            <p>
              Once a tournament <strong>locks</strong> (picks close), real results start flowing in and your entry scores
              live as matches are decided. When the event finishes, final ranks and leaderboard placement are locked in.
            </p>
            <h3>The four ways to play</h3>
            <ul>
              <li><strong>Bracket Challenge</strong> — predict every match in a single tournament's bracket.</li>
              <li><strong>Pick'em Showdown</strong> — build a salary-cap roster of one wrestler per weight class.</li>
              <li><strong>Groups</strong> — a private pool with friends inside one tournament's bracket/pick'em.</li>
              <li><strong>Fantasy Draft Leagues</strong> — a season-long, draft-based game across many events (Annual plan).</li>
            </ul>
            <img
              src="/help/tournament-hub-guide.png"
              alt="A tournament page showing the Make Your Picks and Pick'em buttons, the tab bar, and the weight-class selector, each labeled"
              className="mt-2 w-full rounded-xl border border-mat-700"
            />
          </Section>

          <Section id="bracket" icon={GitBranch} title="Bracket Challenge">
            <p>
              Fill out a full prediction for every weight class — championship side, the entire consolation/wrestleback
              gauntlet, and placement matches (3rd, 5th, 7th) — before the tournament locks. Points are awarded round by
              round as real results come in, so you're scoring throughout the event, not just at the end.
            </p>
            <h3>Round-by-round points</h3>
            <p>Each correct pick is worth more the deeper into the bracket it is — a first-round upset call is worth far less than nailing the champion.</p>
            <ScoreTable
              cols={['Championship round', 'Points']}
              rows={[
                ['Round 1', '1'],
                ['Round 2', '2'],
                ['Round 3 (quarterfinal)', '4'],
                ['Round 4 (semifinal)', '8'],
                ['Round 5 (final)', '16'],
                ['Round 6', '32'],
              ]}
            />
            <p className="text-ink-500">
              The consolation bracket scores too — every correct consolation pick is worth exactly <strong>half</strong> of
              the championship round at the same depth (Round 1 = 0.5, up through Round 6 = 16, plus two extra early
              wrestleback rounds for larger brackets). A pigtail (play-in) match is worth a flat 1 point.
            </p>
            <h3>Placement bonus</h3>
            <p>Correctly calling who wins the 3rd, 5th, and 7th place matches adds a flat bonus on top of the round points above:</p>
            <ScoreTable rows={[['3rd place match', '+4'], ['5th place match', '+2'], ['7th place match', '+2']]} />
            <h3>How they win matters too</h3>
            <p>
              On top of the round points, every correct pick adds a bonus based on the actual victory type — dual-meet
              style, so a decisive win is worth more than a decision:
            </p>
            <ScoreTable rows={[['Decision', '+3'], ['Major decision', '+4'], ['Technical fall', '+5'], ['Fall / forfeit / DQ', '+6'], ['Medical forfeit / injury default', '+3']]} />
            <h3>Opponent-quality multiplier</h3>
            <p>
              Once a wrestler's beaten opponent carries a real national composite ranking, correctly predicting a win over
              a highly-ranked opponent multiplies that pick's round points: <strong>1.5×</strong> vs. a top-4 ranked
              opponent, <strong>1.3×</strong> vs. rank 5–8, <strong>1.15×</strong> vs. rank 9–12. This only applies to
              round points, never to the victory-type bonus or placement bonus.
            </p>
            <h3>Breaking ties</h3>
            <p>
              Ties are broken, in order, by: total points → correct champion picks → correct finalist picks → whoever
              submitted their entry earliest.
            </p>
          </Section>

          <Section id="pickem" icon={Scale} title="Pick'em Showdown">
            <p>
              Draft one wrestler per weight class into a <strong>1,000-point salary cap</strong> roster. Every wrestler's
              cost is set by their tournament seed — the higher the seed, the more expensive — so you can't just stack
              every favorite; the budget forces real tradeoffs.
            </p>
            <h3>Seed pricing</h3>
            <ScoreTable
              cols={['Seed', 'Cost']}
              rows={[
                ['1', '200'], ['2', '160'], ['3', '140'], ['4', '120'], ['5', '100'], ['6', '90'], ['7', '80'], ['8', '70'],
                ['9', '60'], ['10', '50'], ['11', '40'], ['12', '30'], ['13–16', '20'], ['Unseeded', '10'],
              ]}
            />
            <h3>How your team scores</h3>
            <p>Each wrestler on your roster earns points independently — there's no opposing team, just your own roster's total.</p>
            <ul>
              <li><strong>Per win:</strong> +1 point for a championship-bracket win, +0.5 for a consolation-bracket win.</li>
              <li>
                <strong>Victory-type bonus:</strong> on top of the win point — fall <span className="font-mono text-gold-400">+2</span>,
                technical fall <span className="font-mono text-gold-400">+1.5</span>, major decision <span className="font-mono text-gold-400">+1</span>.
              </li>
              <li><strong>Final placement:</strong> a flat bonus based on how each wrestler finishes the tournament:</li>
            </ul>
            <ScoreTable
              cols={['Final placement', 'Points']}
              rows={[['1st', '16'], ['2nd', '12'], ['3rd', '10'], ['4th', '9'], ['5th', '8'], ['6th', '7'], ['7th', '6'], ['8th', '5']]}
            />
            <h3>Tiebreaker</h3>
            <p>If two teams finish level, the entry that most closely predicted the total combined points scored by all ten of your wrestlers wins the tiebreak.</p>
          </Section>

          <Section id="leaderboard" icon={Trophy} title="Master Leaderboard">
            <p>
              Every tournament's leaderboard only tells you how you did in <em>that</em> event. The{' '}
              <Link to="/leaderboard" className="font-semibold text-gold-400 hover:text-gold-300">
                Master Leaderboard
              </Link>{' '}
              combines your performance across <strong>every</strong> tournament you enter, all season, into one ranking.
            </p>
            <h3>How points are calculated</h3>
            <p>
              Every Bracket Challenge and Pick'em Showdown entry that gets ranked earns master-leaderboard points based on
              where you finished relative to everyone else in that specific tournament — a <strong>percentile</strong>,
              not a fixed points table. That's what makes it fair whether an event has 8 entrants or 8,000:
            </p>
            <ScoreTable
              cols={['Formula', 'Meaning']}
              rows={[
                ['percentile = (entrants − rank + 1) ÷ entrants', 'Finishing in the top half of a field of any size still earns real points'],
                ['points = percentile × 100', 'A field-topping finish is worth 100; the very last place still earns just above 0'],
              ]}
            />
            <p>
              <strong>Bracket and Pick'em entries in the same tournament score independently and add together</strong> —
              enter both and do well in both, you get both. Points from every tournament <strong>sum</strong> across the
              season rather than averaging, so continuing to play is the only way to keep climbing — winning once early
              and stopping won't hold your spot against someone who keeps competing.
            </p>
            <h3>Public profiles</h3>
            <p>
              Click any name on the leaderboard to see that player's public profile — a list of every bracket/pick'em
              entry they've made public, and how many points each one earned toward the master leaderboard. From there
              you can click through to see the actual picks (an account is required to view submission detail).
            </p>
            <img
              src="/help/profile-submissions-guide.png"
              alt="A user's profile page showing a public submission row and the points it earned toward the Master Leaderboard, labeled"
              className="mt-2 w-full rounded-xl border border-mat-700"
            />
          </Section>

          <Section id="groups" icon={Users} title="Groups">
            <p>
              A Group is a private pool inside a single tournament — invite friends with a code and compete on your own
              leaderboard, separate from the public one. Great for office pools or a friend group that wants bragging
              rights without the whole platform watching.
            </p>
            <ul>
              <li>Create a group from a tournament page, or from <Link to="/groups/new" className="font-semibold text-gold-400 hover:text-gold-300">My Groups</Link>.</li>
              <li>Share the invite code — anyone with the code and a Mat Savvy account can join.</li>
              <li>A group's leaderboard is visible only to its members, scored with the exact same rules as the public bracket/pick'em leaderboard for that tournament.</li>
              <li>Leaving a group drops you off its leaderboard — rejoin any time with the same code.</li>
            </ul>
          </Section>

          <Section id="leagues" icon={Swords} title="Fantasy Draft Leagues">
            <Badge color="gold" className="mb-2">Annual plan</Badge>
            <p>
              The deep game: form a private league with friends, snake-draft the entire D1 wrestler pool, and manage a
              roster all season — weekly lineups, waivers, trades, and a real season-long championship.
            </p>
            <h3>Draft & roster</h3>
            <p>
              Commissioners set up the league and invite members (see <strong>Commissioner Settings</strong> from any
              league you own or co-run — league info, roster size, season-week scoring, and invites all live there). A
              snake draft fills every team with <strong>10 starters (one per weight class) plus 1 alternate per weight
              class</strong> — 20 roster spots total. The draft runs starters-first, then alternates, but you choose
              which open weight to fill in any order within each phase. Once drafted, a wrestler is exclusive to your
              league — no one else can draft them.
            </p>
            <h3>Weekly lineups & waivers</h3>
            <p>
              Each week, set your active 10 from your full 20-man roster. If a starter isn't competing that week —
              or you'd simply rather start your alternate because of who they're facing — swap in the alternate at
              that weight. If a weight class has no one available at all, you'll need to drop someone to the waiver
              wire to make room — a dropped wrestler becomes claimable by any other league member. The waiver wire and
              trade center both let you filter by weight/team and see a wrestler's record and notable results before
              you act.
            </p>
            <h3>Trades</h3>
            <p>
              Propose a trade with any other member — pick what you're offering and what you want from their roster.
              The receiving side can <strong>accept</strong>, <strong>reject</strong>, or send back a{' '}
              <strong>counter-offer</strong> with different wrestlers (pre-filled from the original offer, fully
              editable) — a real back-and-forth negotiation, not an instant swap. A countered trade keeps its own
              history; the original offer is marked "countered" once a counter goes out. All trade activity in a
              league is visible to every member, not just the two sides involved.
            </p>
            <h3>Head-to-head scoring</h3>
            <p>Each week you're paired against one other league member. Every one of your 10 starters scores from their real matches that week:</p>
            <ScoreTable cols={['Victory type', 'Base points/match']} rows={[['Decision', '3'], ['Major decision', '4'], ['Technical fall', '5'], ['Fall / forfeit / DQ', '6'], ['Medical forfeit / injury default', '3']]} />
            <p>
              A wrestler's score for the week is the <strong>average</strong> points-per-match (not a sum) — so lineup
              value comes from match <em>quality</em>, not just piling up matches. On top of the average, a flat{' '}
              <strong>medal bonus</strong> is added if a wrestler placed at a tournament that week (1st = +6, down to
              8th = +0.5), rewarding a deep tournament run beyond just per-match quality. An opponent-quality multiplier
              (same 1.5× / 1.3× / 1.15× tiers as Bracket Challenge) applies per match once Mat Savvy Rankings are live.
              Higher combined roster score wins the week; a win is worth 2 season-standings points, a tie 1, a loss 0.
            </p>
            <h3>Marquee tournament weeks</h3>
            <p>
              For select big events during the season (commissioner's choice — think major regular-season invitationals),
              the roster/lineup engine steps aside entirely for that week. Instead, the commissioner runs it as its own
              standalone Bracket Challenge and/or Pick'em Showdown contest against that event's full field, with a
              per-tournament placement-to-points table deciding how many season-standings points each league member earns.
            </p>
            <h3>Conference & Nationals</h3>
            <p>
              Your roster, waivers, and trades all keep running straight through conference week and the NCAA
              tournament — if your guy didn't qualify, waiver in someone who did. These two weeks aren't head-to-head:
              every member scores their own full roster independently (same averaging as a normal week, but every match
              counts, not just one opponent's), everyone is then ranked against each other, and points are awarded by
              placement from a commissioner-configurable table. These weeks are intentionally worth more than a normal
              week — nationals' 1st-place value is over 3× a normal marquee week's — so a strong postseason can move you
              up the final standings.
            </p>
            <h3>Standings & weekly results</h3>
            <p>
              The league dashboard shows the full season standings for every member, plus a week-by-week scoreboard of
              every matchup in the league that week (not just your own) — expand any week to see how everyone did.
            </p>
            <h3>The champion</h3>
            <p>
              There's one combined, weighted standings ledger — head-to-head results, marquee-week contest points, and
              conference/nationals placement points all feed the same running total. Most cumulative points after
              Nationals wins the league. No separate bracket/playoff — one continuous season, one champion.
            </p>
          </Section>

          <Section id="privacy" icon={Eye} title="Privacy & Visibility">
            <p>Mat Savvy gives you layered control over what other people can see:</p>
            <ul>
              <li>
                <strong>Per-entry public/private toggle</strong> — every bracket and pick'em entry has its own switch
                (default private). Turning it on lets other logged-in users view that specific entry's actual picks from
                the tournament leaderboard or your profile.
              </li>
              <li>
                <strong>Show up on public leaderboards</strong> (Profile settings) — turn this off to keep yourself out of
                any tournament's public leaderboard entirely. Private group leaderboards aren't affected.
              </li>
              <li>
                <strong>Leaderboard name</strong> — when visible, choose whether your display name or your @username is
                what other people see.
              </li>
              <li>
                <strong>Show public submissions on my profile</strong> (Profile settings, default on) — controls whether
                your profile page shows the combined list of your public entries and the points each one earned. Turn
                this off to keep that summary private even if individual entries are still marked public.
              </li>
            </ul>
            <p className="text-ink-500">Viewing anyone's submission detail — public or not — requires being logged in.</p>
          </Section>

          <Section id="pricing" icon={CreditCard} title="Pricing & Plans">
            <div className="grid gap-4 sm:grid-cols-2">
              <Card className="p-5">
                <h3 className="!mt-0 flex items-center gap-2">Free</h3>
                <ul>
                  <li>Browse and predict any open tournament</li>
                  <li>Up to 3 submitted entries, ever (any mix of bracket + pick'em)</li>
                  <li>Create private groups and run your own pool</li>
                  <li>Full access to the Results Library</li>
                  <li>View any public submission (account required)</li>
                </ul>
              </Card>
              <Card className="border-gold-500/40 p-5 shadow-glow-sm">
                <h3 className="!mt-0 flex items-center gap-2"><Crown size={15} className="text-gold-400" /> Annual — $29.99/yr</h3>
                <ul>
                  <li>Unlimited entries, every event</li>
                  <li>Create and commission season-long fantasy leagues</li>
                  <li>Everything in the Free plan</li>
                </ul>
              </Card>
            </div>
            <p>
              <Link to="/pricing" className="inline-flex items-center gap-1.5 font-semibold text-gold-400 hover:text-gold-300">
                See full pricing details <ArrowRight size={14} />
              </Link>
            </p>
          </Section>

          <Section id="faq" icon={HelpCircle} title="Frequently Asked Questions">
            <div className="space-y-3">
              <FaqItem q="Is this gambling? Can I win money?">
                No. Mat Savvy is purely for fun and bragging rights — there's no real-money wagering, payouts, or prizes
                tied to your rank anywhere on the platform.
              </FaqItem>
              <FaqItem q="What happens if a match I predicted never happens (bye, injury default, etc.)?">
                Only matches that actually occur are scored. A pick tied to a match that never happens is excluded
                entirely rather than counted as a miss.
              </FaqItem>
              <FaqItem q="Can I edit my picks after submitting?">
                Yes, up until the tournament locks. Once locked, entries are final and scoring begins as results come in.
              </FaqItem>
              <FaqItem q="Why does the Master Leaderboard look empty even though I have entries?">
                It's scoped to the current season/year. If your entries are from a prior season, or the tournament
                hasn't finished being scored yet, they won't show up in this year's totals until then.
              </FaqItem>
              <FaqItem q="Can I enter both a Bracket Challenge and a Pick'em Showdown for the same tournament?">
                Yes — they're scored completely independently, and if you don't already have a pick'em entry for a
                tournament you've bracket-predicted, you'll see an "Add Pick'em" button on your entry page.
              </FaqItem>
              <FaqItem q="Do I need an Annual plan to view other people's picks?">
                No — viewing any public submission just requires a free account. The Annual plan is about unlimited
                entries and fantasy leagues, not viewing.
              </FaqItem>
            </div>
          </Section>
        </div>
      </div>
    </div>
  )
}
