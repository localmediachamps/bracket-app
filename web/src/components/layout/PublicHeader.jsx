import React, { useEffect, useRef, useState } from 'react'
import { NavLink, useNavigate } from 'react-router-dom'
import { Menu, Trophy, Swords, Crown, ScrollText, GraduationCap, LifeBuoy, UserRound } from 'lucide-react'
import { Button } from '../ui'
import { cn } from '../../lib/utils'
import { Logo } from './Logo'

// The public marketing/browse experience (logged out) - a hamburger-driven
// nav (even on desktop, per Garrett: too many links crowding the top row),
// no app-only items (Dashboard/Groups/Leagues/notifications/account) since
// none of that is relevant until someone actually signs in. Sign
// in/Get Savvy/Pricing stay outside the hamburger, always visible - those
// are the primary calls to action, not just navigation. Once authenticated,
// AppShell swaps to the left Sidebar instead - see the token-based branch
// in AppShell.jsx.
const PUBLIC_NAV = [
  { to: '/tournaments', label: 'Tournaments', icon: Trophy },
  { to: '/dual-meets', label: 'Dual Meets', icon: Swords },
  { to: '/leaderboard', label: 'Leaderboard', icon: Crown },
  { to: '/results', label: 'Results', icon: ScrollText },
  { to: '/teams', label: 'Teams', icon: GraduationCap },
  { to: '/wrestlers', label: 'Wrestlers', icon: UserRound },
  { to: '/help', label: 'Help', icon: LifeBuoy },
]

export default function PublicHeader() {
  const navigate = useNavigate()
  const [menuOpen, setMenuOpen] = useState(false)
  const menuRef = useRef(null)

  useEffect(() => {
    if (!menuOpen) return
    function onDocClick(e) {
      if (menuRef.current && !menuRef.current.contains(e.target)) setMenuOpen(false)
    }
    document.addEventListener('mousedown', onDocClick)
    return () => document.removeEventListener('mousedown', onDocClick)
  }, [menuOpen])

  return (
    <header className="sticky top-0 z-40 hidden border-b border-mat-800 bg-mat-950/85 backdrop-blur-md md:block">
      <div className="mx-auto flex h-16 max-w-7xl items-center justify-between gap-4 px-4">
        <div className="flex items-center gap-2">
          <Logo />
          <div className="relative" ref={menuRef}>
            <button
              onClick={() => setMenuOpen((o) => !o)}
              className={cn(
                'ml-2 flex items-center gap-2 rounded-lg px-3 py-2 text-sm font-semibold transition-colors',
                menuOpen ? 'bg-mat-800 text-gold-400' : 'text-ink-400 hover:bg-mat-850 hover:text-ink-100'
              )}
              aria-label="Browse menu"
              aria-expanded={menuOpen}
            >
              <Menu size={17} />
              Browse
            </button>

            {menuOpen && (
              <div className="absolute left-0 top-full z-20 mt-2 w-56 overflow-hidden rounded-xl border border-mat-700 bg-mat-850 py-1.5 shadow-card">
                {PUBLIC_NAV.map((n) => (
                  <NavLink
                    key={n.to}
                    to={n.to}
                    onClick={() => setMenuOpen(false)}
                    className={({ isActive }) =>
                      cn(
                        'flex items-center gap-2.5 px-4 py-2.5 text-sm font-semibold transition-colors',
                        isActive ? 'text-gold-400' : 'text-ink-300 hover:bg-mat-750 hover:text-ink-100'
                      )
                    }
                  >
                    <n.icon size={16} />
                    {n.label}
                  </NavLink>
                ))}
              </div>
            )}
          </div>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="ghost" size="sm" onClick={() => navigate('/pricing')}>Pricing</Button>
          <Button variant="ghost" size="sm" onClick={() => navigate('/login')}>Sign in</Button>
          <Button size="sm" onClick={() => navigate('/register')}>Get Savvy</Button>
        </div>
      </div>
    </header>
  )
}
