import React from 'react'
import { NavLink, useNavigate } from 'react-router-dom'
import { Trophy, Swords, Crown, ScrollText, GraduationCap, LifeBuoy } from 'lucide-react'
import { Button } from '../ui'
import { cn } from '../../lib/utils'
import { Logo } from './Logo'

// The public marketing/browse experience (logged out) - a classic horizontal
// nav, no app-only items (Dashboard/Groups/Leagues/notifications/account),
// since none of that is relevant until someone actually signs in. Once
// authenticated, AppShell swaps to the left Sidebar instead - see the
// token-based branch in AppShell.jsx.
const PUBLIC_NAV = [
  { to: '/tournaments', label: 'Tournaments', icon: Trophy },
  { to: '/dual-meets', label: 'Dual Meets', icon: Swords },
  { to: '/leaderboard', label: 'Leaderboard', icon: Crown },
  { to: '/results', label: 'Results', icon: ScrollText },
  { to: '/teams', label: 'Teams', icon: GraduationCap },
]

export default function PublicHeader() {
  const navigate = useNavigate()

  return (
    <header className="sticky top-0 z-40 hidden border-b border-mat-800 bg-mat-950/85 backdrop-blur-md md:block">
      <div className="mx-auto flex h-16 max-w-7xl items-center justify-between gap-4 px-4">
        <Logo />
        <nav className="flex items-center gap-1">
          {PUBLIC_NAV.map((n) => (
            <NavLink
              key={n.to}
              to={n.to}
              className={({ isActive }) =>
                cn(
                  'flex items-center gap-2 rounded-lg px-3.5 py-2 text-sm font-semibold transition-colors',
                  isActive ? 'bg-mat-800 text-gold-400' : 'text-ink-400 hover:bg-mat-850 hover:text-ink-100'
                )
              }
            >
              <n.icon size={16} />
              {n.label}
            </NavLink>
          ))}
          <NavLink
            to="/help"
            className={({ isActive }) =>
              cn(
                'flex items-center gap-2 rounded-lg px-3.5 py-2 text-sm font-semibold transition-colors',
                isActive ? 'bg-mat-800 text-gold-400' : 'text-ink-400 hover:bg-mat-850 hover:text-ink-100'
              )
            }
          >
            <LifeBuoy size={16} />
            Help
          </NavLink>
        </nav>
        <div className="flex items-center gap-2">
          <Button variant="ghost" size="sm" onClick={() => navigate('/pricing')}>Pricing</Button>
          <Button variant="ghost" size="sm" onClick={() => navigate('/login')}>Sign in</Button>
          <Button size="sm" onClick={() => navigate('/register')}>Get Savvy</Button>
        </div>
      </div>
    </header>
  )
}
