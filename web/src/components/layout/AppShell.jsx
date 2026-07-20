import React from 'react'
import { Link, NavLink, Outlet, useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { Bell, Trophy, Users, LayoutDashboard, LogOut, Shield, User as UserIcon } from 'lucide-react'
import { useAuthStore } from '../../lib/store'
import { api } from '../../lib/api'
import { Avatar, Button } from '../ui'
import { cn } from '../../lib/utils'

export function Logo({ className }) {
  return (
    <Link to="/" className={cn('group inline-flex items-center', className)}>
      <img
        src="/branding/mat_savvy_logo_dark_landscape.svg"
        alt="Mat Savvy"
        className="h-8 w-auto transition-transform group-hover:scale-[1.02]"
      />
    </Link>
  )
}

const NAV = [
  { to: '/tournaments', label: 'Tournaments', icon: Trophy },
  { to: '/dashboard', label: 'Dashboard', icon: LayoutDashboard, auth: true },
  { to: '/groups', label: 'Groups', icon: Users, auth: true },
]

export default function AppShell() {
  const { token, user, logout } = useAuthStore()
  const navigate = useNavigate()
  const { data: notifData } = useQuery({
    queryKey: ['notifications', 'peek'],
    queryFn: () => api.notifications({ per: 1 }),
    enabled: !!token,
    refetchInterval: 60000,
    retry: false,
  })
  const unread = notifData?.unread_count ?? 0

  return (
    <div className="flex min-h-screen flex-col">
      <header className="sticky top-0 z-40 border-b border-mat-800 bg-mat-950/85 backdrop-blur-md">
        <div className="mx-auto flex h-16 max-w-7xl items-center justify-between gap-4 px-4">
          <Logo />
          <nav className="hidden items-center gap-1 md:flex">
            {NAV.filter((n) => !n.auth || token).map((n) => (
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
            {user?.is_admin && (
              <NavLink
                to="/admin"
                className={({ isActive }) =>
                  cn(
                    'flex items-center gap-2 rounded-lg px-3.5 py-2 text-sm font-semibold transition-colors',
                    isActive ? 'bg-mat-800 text-gold-400' : 'text-ink-400 hover:bg-mat-850 hover:text-ink-100'
                  )
                }
              >
                <Shield size={16} />
                Admin
              </NavLink>
            )}
          </nav>
          <div className="flex items-center gap-2">
            {token ? (
              <>
                <button
                  onClick={() => navigate('/notifications')}
                  className="relative rounded-lg p-2 text-ink-400 hover:bg-mat-850 hover:text-ink-100"
                  aria-label="Notifications"
                >
                  <Bell size={19} />
                  {unread > 0 && (
                    <span className="absolute -right-0.5 -top-0.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-blood-500 px-1 text-[9px] font-bold text-white">
                      {unread > 9 ? '9+' : unread}
                    </span>
                  )}
                </button>
                <div className="group relative">
                  <button className="flex items-center gap-2 rounded-lg p-1.5 hover:bg-mat-850">
                    <Avatar user={user} size="sm" />
                  </button>
                  <div className="invisible absolute right-0 top-full w-52 pt-1 opacity-0 transition-all group-hover:visible group-hover:opacity-100">
                    <div className="overflow-hidden rounded-xl border border-mat-600 bg-mat-850 shadow-card">
                      <div className="border-b border-mat-700 px-4 py-3">
                        <p className="truncate text-sm font-bold text-ink-100">{user?.display_name || user?.name}</p>
                        <p className="truncate text-xs text-ink-500">@{user?.username || user?.email}</p>
                      </div>
                      <MenuLink to="/profile" icon={UserIcon}>Profile</MenuLink>
                      {user?.is_admin && <MenuLink to="/admin" icon={Shield}>Admin</MenuLink>}
                      <button
                        onClick={() => { logout(); navigate('/') }}
                        className="flex w-full items-center gap-2.5 px-4 py-2.5 text-sm font-semibold text-blood-400 hover:bg-mat-750"
                      >
                        <LogOut size={15} /> Sign out
                      </button>
                    </div>
                  </div>
                </div>
              </>
            ) : (
              <>
                <Button variant="ghost" size="sm" onClick={() => navigate('/login')}>Sign in</Button>
                <Button size="sm" onClick={() => navigate('/register')}>Join the mat</Button>
              </>
            )}
          </div>
        </div>
      </header>

      <main className="mx-auto w-full max-w-7xl flex-1 px-4 pb-24 pt-6 md:pb-12">
        <Outlet />
      </main>

      {/* Mobile bottom tabs */}
      <nav className="fixed inset-x-0 bottom-0 z-40 border-t border-mat-800 bg-mat-950/92 backdrop-blur-md md:hidden" style={{ paddingBottom: 'env(safe-area-inset-bottom)' }}>
        <div className="grid grid-cols-4">
          {[
            { to: '/tournaments', label: 'Events', icon: Trophy },
            { to: '/dashboard', label: 'Home', icon: LayoutDashboard },
            { to: '/groups', label: 'Groups', icon: Users },
            { to: token ? '/profile' : '/login', label: token ? 'Profile' : 'Sign in', icon: UserIcon },
          ].map((n) => (
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
          <span>Built for wrestling fans · {new Date().getFullYear()}</span>
        </div>
      </footer>
    </div>
  )
}

function MenuLink({ to, icon: Icon, children }) {
  return (
    <Link to={to} className="flex items-center gap-2.5 px-4 py-2.5 text-sm font-semibold text-ink-300 hover:bg-mat-750 hover:text-ink-100">
      <Icon size={15} /> {children}
    </Link>
  )
}
