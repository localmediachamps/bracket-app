import React, { useState } from 'react'
import { Link, NavLink, Outlet, useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { Bell, Trophy, LayoutDashboard, LogOut, Shield, User as UserIcon, Swords, Menu, Crown, LifeBuoy } from 'lucide-react'
import { useAuthStore } from '../../lib/store'
import { api } from '../../lib/api'
import { Avatar, Button, Modal } from '../ui'
import { cn } from '../../lib/utils'
import { ResultsAnalystWidget } from '../ai/ResultsAnalystWidget'
import Sidebar, { SIDEBAR_NAV } from './Sidebar'
import PublicHeader from './PublicHeader'
import { Logo } from './Logo'

export { Logo }

export default function AppShell() {
  const { token, user, logout } = useAuthStore()
  const navigate = useNavigate()
  const [menuOpen, setMenuOpen] = useState(false)
  const { data: notifData } = useQuery({
    queryKey: ['notifications', 'peek'],
    queryFn: () => api.notifications({ per: 1 }),
    enabled: !!token,
    refetchInterval: 60000,
    retry: false,
  })
  const unread = notifData?.unread_count ?? 0

  // Everything a signed-in user can reach (Dashboard/Groups/Leagues/Admin/
  // notifications/account) lives behind the left Sidebar - the "app" nav.
  // A logged-out visitor is browsing the public marketing/info site instead,
  // so they get a classic top nav (PublicHeader) with just the public-facing
  // sections - none of that app-only surface is pertinent to them yet.
  const mobileTabs = token
    ? [
        { to: '/dashboard', label: 'Home', icon: LayoutDashboard },
        { to: '/tournaments', label: 'Events', icon: Trophy },
        { to: '/leagues', label: 'Leagues', icon: Swords },
        { to: '/leaderboard', label: 'Ranks', icon: Crown },
        { to: '/profile', label: 'Profile', icon: UserIcon },
      ]
    : [
        { to: '/tournaments', label: 'Events', icon: Trophy },
        { to: '/dual-meets', label: 'Duals', icon: Swords },
        { to: '/leaderboard', label: 'Ranks', icon: Crown },
        { to: '/help', label: 'Help', icon: LifeBuoy },
        { to: '/login', label: 'Sign in', icon: UserIcon },
      ]

  return (
    <div className="flex min-h-screen">
      {token && <Sidebar unread={unread} />}
      <div className="flex min-w-0 flex-1 flex-col">
      {token ? null : <PublicHeader />}

      {/* Mobile-only top bar (both logged-in and logged-out). Desktop
          nav/account access lives in the left Sidebar (signed in) or
          PublicHeader (signed out) instead - this bar is just the logo +
          hamburger overflow menu at narrow widths, plus the bottom tab bar
          below. */}
      <header className="sticky top-0 z-40 border-b border-mat-800 bg-mat-950/85 backdrop-blur-md md:hidden">
        <div className="flex h-16 items-center justify-between gap-4 px-4">
          <Logo />
          <button
            onClick={() => setMenuOpen(true)}
            className="relative rounded-lg p-2 text-ink-300 hover:bg-mat-850 hover:text-ink-100"
            aria-label="Open menu"
          >
            <Menu size={22} />
            {token && unread > 0 && (
              <span className="absolute right-0.5 top-0.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-blood-500 px-1 text-[9px] font-bold text-white">
                {unread > 9 ? '9+' : unread}
              </span>
            )}
          </button>
        </div>
      </header>

      <Modal open={menuOpen} onClose={() => setMenuOpen(false)} title="Menu">
        <div className="space-y-4">
          {token && (
            <div className="flex items-center gap-3 border-b border-mat-700 pb-4">
              <Avatar user={user} size="md" />
              <div className="min-w-0">
                <p className="truncate text-sm font-bold text-ink-100">{user?.display_name || user?.name}</p>
                <p className="truncate text-xs text-ink-500">@{user?.username || user?.email}</p>
              </div>
            </div>
          )}

          <div className="space-y-1">
            {SIDEBAR_NAV.filter((n) => !n.auth || token).map((n) => (
              <NavLink
                key={n.to}
                to={n.to}
                onClick={() => setMenuOpen(false)}
                className={({ isActive }) =>
                  cn(
                    'flex items-center gap-2.5 rounded-xl px-3.5 py-3 text-sm font-semibold transition-colors',
                    isActive ? 'bg-mat-800 text-gold-400' : 'text-ink-300 hover:bg-mat-800 hover:text-ink-100'
                  )
                }
              >
                <n.icon size={17} />
                {n.label}
              </NavLink>
            ))}
            {token && (
              <NavLink
                to="/notifications"
                onClick={() => setMenuOpen(false)}
                className={({ isActive }) =>
                  cn(
                    'flex items-center gap-2.5 rounded-xl px-3.5 py-3 text-sm font-semibold transition-colors',
                    isActive ? 'bg-mat-800 text-gold-400' : 'text-ink-300 hover:bg-mat-800 hover:text-ink-100'
                  )
                }
              >
                <Bell size={17} />
                Notifications
                {unread > 0 && (
                  <span className="ml-auto flex h-5 min-w-5 items-center justify-center rounded-full bg-blood-500 px-1.5 text-[10px] font-bold text-white">
                    {unread > 9 ? '9+' : unread}
                  </span>
                )}
              </NavLink>
            )}
            {token && (
              <NavLink
                to="/profile"
                onClick={() => setMenuOpen(false)}
                className={({ isActive }) =>
                  cn(
                    'flex items-center gap-2.5 rounded-xl px-3.5 py-3 text-sm font-semibold transition-colors',
                    isActive ? 'bg-mat-800 text-gold-400' : 'text-ink-300 hover:bg-mat-800 hover:text-ink-100'
                  )
                }
              >
                <UserIcon size={17} />
                Profile
              </NavLink>
            )}
            <NavLink
              to="/pricing"
              onClick={() => setMenuOpen(false)}
              className={({ isActive }) =>
                cn(
                  'flex items-center gap-2.5 rounded-xl px-3.5 py-3 text-sm font-semibold transition-colors',
                  isActive ? 'bg-mat-800 text-gold-400' : 'text-ink-300 hover:bg-mat-800 hover:text-ink-100'
                )
              }
            >
              <Crown size={17} />
              Pricing
            </NavLink>
            <NavLink
              to="/help"
              onClick={() => setMenuOpen(false)}
              className={({ isActive }) =>
                cn(
                  'flex items-center gap-2.5 rounded-xl px-3.5 py-3 text-sm font-semibold transition-colors',
                  isActive ? 'bg-mat-800 text-gold-400' : 'text-ink-300 hover:bg-mat-800 hover:text-ink-100'
                )
              }
            >
              <LifeBuoy size={17} />
              Help Center
            </NavLink>
            {user?.is_admin && (
              <NavLink
                to="/admin"
                onClick={() => setMenuOpen(false)}
                className={({ isActive }) =>
                  cn(
                    'flex items-center gap-2.5 rounded-xl px-3.5 py-3 text-sm font-semibold transition-colors',
                    isActive ? 'bg-mat-800 text-gold-400' : 'text-ink-300 hover:bg-mat-800 hover:text-ink-100'
                  )
                }
              >
                <Shield size={17} />
                Admin
              </NavLink>
            )}
          </div>

          {token ? (
            <Button
              variant="danger"
              className="w-full"
              onClick={() => { setMenuOpen(false); logout(); navigate('/') }}
            >
              <LogOut size={15} /> Sign out
            </Button>
          ) : (
            <div className="flex items-center gap-3 border-t border-mat-700 pt-4">
              <Button variant="secondary" className="flex-1" onClick={() => { setMenuOpen(false); navigate('/login') }}>Sign in</Button>
              <Button className="flex-1" onClick={() => { setMenuOpen(false); navigate('/register') }}>Get Savvy</Button>
            </div>
          )}
        </div>
      </Modal>

      <main className="mx-auto w-full max-w-7xl flex-1 px-4 pb-24 pt-6 md:pb-12">
        <Outlet />
      </main>

      {/* Mobile bottom tabs */}
      <nav className="fixed inset-x-0 bottom-0 z-40 border-t border-mat-800 bg-mat-950/92 backdrop-blur-md md:hidden" style={{ paddingBottom: 'env(safe-area-inset-bottom)' }}>
        <div className="grid grid-cols-5">
          {mobileTabs.map((n) => (
            <NavLink
              key={n.to}
              to={n.to}
              className={({ isActive }) =>
                cn('flex flex-col items-center gap-1 py-2.5 text-[10px] font-bold uppercase tracking-wide', isActive ? 'text-gold-400' : 'text-ink-500')
              }
            >
              <n.icon size={19} />
              {n.label}
            </NavLink>
          ))}
        </div>
      </nav>

      <footer className="hidden border-t border-mat-800 py-6 md:block">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-4 text-xs text-ink-600">
          <span className="font-display uppercase tracking-wide">Mat Savvy</span>
          <div className="flex items-center gap-5">
            <Link to="/help" className="hover:text-ink-300">Help Center</Link>
            <Link to="/terms" className="hover:text-ink-300">Terms</Link>
            <Link to="/privacy" className="hover:text-ink-300">Privacy</Link>
            <span>Built for wrestling fans · {new Date().getFullYear()}</span>
          </div>
        </div>
      </footer>
      </div>

      {user?.is_admin && <ResultsAnalystWidget />}
    </div>
  )
}
