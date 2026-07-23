import React, { useEffect, useRef, useState } from 'react'
import { Link, NavLink, useNavigate } from 'react-router-dom'
import {
  Bell, Trophy, Users, LayoutDashboard, LogOut, Shield, User as UserIcon,
  ScrollText, Swords, Crown, GraduationCap, CalendarRange, CalendarDays, LifeBuoy,
  ChevronLeft, ChevronRight, ChevronsUpDown, Star, CreditCard, UserRound, ListOrdered,
} from 'lucide-react'
import { useAuthStore } from '../../lib/store'
import { Avatar } from '../ui'
import { cn } from '../../lib/utils'

export const SIDEBAR_NAV = [
  { to: '/dashboard', label: 'Dashboard', icon: LayoutDashboard, auth: true },
  { to: '/leaderboard', label: 'Leaderboard', icon: Crown },
  { to: '/rankings', label: 'Rankings', icon: ListOrdered },
  { to: '/tournaments', label: 'Tournaments', icon: Trophy },
  { to: '/dual-meets', label: 'Dual Meets', icon: Swords },
  { to: '/calendar', label: 'Calendar', icon: CalendarDays },
  { to: '/groups', label: 'Groups', icon: Users, auth: true },
  { to: '/leagues', label: 'Leagues', icon: CalendarRange, auth: true },
  { to: '/teams', label: 'Teams', icon: GraduationCap },
  { to: '/wrestlers', label: 'Wrestlers', icon: UserRound },
  { to: '/results', label: 'Results', icon: ScrollText },
]

const COLLAPSE_KEY = 'matSavvy.sidebarCollapsed'
const PINNED_KEY = 'matSavvy.sidebarPinned'

function readPinned() {
  try {
    const raw = localStorage.getItem(PINNED_KEY)
    return raw ? JSON.parse(raw) : []
  } catch {
    return []
  }
}

export default function Sidebar({ unread = 0 }) {
  const { token, user, logout } = useAuthStore()
  const navigate = useNavigate()
  const [collapsed, setCollapsed] = useState(() => localStorage.getItem(COLLAPSE_KEY) === '1')
  const [pinned, setPinned] = useState(readPinned)
  const [accountOpen, setAccountOpen] = useState(false)
  const accountRef = useRef(null)

  useEffect(() => {
    localStorage.setItem(COLLAPSE_KEY, collapsed ? '1' : '0')
  }, [collapsed])

  useEffect(() => {
    localStorage.setItem(PINNED_KEY, JSON.stringify(pinned))
  }, [pinned])

  useEffect(() => {
    if (!accountOpen) return
    function onDocClick(e) {
      if (accountRef.current && !accountRef.current.contains(e.target)) setAccountOpen(false)
    }
    document.addEventListener('mousedown', onDocClick)
    return () => document.removeEventListener('mousedown', onDocClick)
  }, [accountOpen])

  function togglePin(to) {
    setPinned((prev) => (prev.includes(to) ? prev.filter((p) => p !== to) : [...prev, to]))
  }

  const items = SIDEBAR_NAV.filter((n) => !n.auth || token)
  const pinnedItems = items.filter((n) => pinned.includes(n.to))
  const restItems = items.filter((n) => !pinned.includes(n.to))

  return (
    <aside
      className={cn(
        'sticky top-0 z-30 hidden h-screen shrink-0 flex-col border-r border-mat-800 bg-mat-950 transition-[width] duration-200 md:flex',
        collapsed ? 'w-[76px]' : 'w-[252px]'
      )}
    >
      {/* Floating collapse/expand toggle - always in the same spot, on the
          seam of the sidebar, so it doesn't jump between two different
          buttons/positions depending on state. */}
      <button
        onClick={() => setCollapsed((c) => !c)}
        className="absolute -right-3 top-[26px] z-10 flex h-6 w-6 items-center justify-center rounded-full border border-mat-700 bg-mat-850 text-ink-400 shadow-md transition-colors hover:border-gold-500/50 hover:text-gold-400"
        aria-label={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
        title={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
      >
        {collapsed ? <ChevronRight size={13} /> : <ChevronLeft size={13} />}
      </button>

      <div className={cn('flex h-16 shrink-0 items-center border-b border-mat-800', collapsed ? 'justify-center px-0' : 'px-4')}>
        <Link to="/" className="flex items-center gap-2 overflow-hidden">
          {collapsed ? (
            <img src="/branding/mat_savvy_icon_dark.svg" alt="Mat Savvy" className="h-8 w-8 shrink-0" />
          ) : (
            <img src="/branding/mat_savvy_logo_dark_landscape.svg" alt="Mat Savvy" className="h-8 w-auto" />
          )}
        </Link>
      </div>

      <div className="flex-1 space-y-5 overflow-y-auto overflow-x-hidden px-2.5 py-4 [scrollbar-width:thin]">
        {pinnedItems.length > 0 && (
          <NavSection
            label={collapsed ? null : 'Pinned'}
            items={pinnedItems}
            collapsed={collapsed}
            pinned={pinned}
            onTogglePin={togglePin}
          />
        )}

        <NavSection
          label={collapsed ? null : pinnedItems.length ? 'Explore' : null}
          items={restItems}
          collapsed={collapsed}
          pinned={pinned}
          onTogglePin={togglePin}
        />

        <div className="space-y-0.5 border-t border-mat-800/80 pt-3">
          <SidebarLink to="/help" icon={LifeBuoy} label="Help Center" collapsed={collapsed} />
          <SidebarLink to="/pricing" icon={CreditCard} label="Pricing" collapsed={collapsed} />
          {user?.is_admin && <SidebarLink to="/admin" icon={Shield} label="Admin" collapsed={collapsed} />}
        </div>
      </div>

      <div className="shrink-0 space-y-1 border-t border-mat-800 px-2.5 py-3">
        {token ? (
          <>
            <SidebarLink to="/notifications" icon={Bell} label="Notifications" collapsed={collapsed} badge={unread} />

            <div className="relative" ref={accountRef}>
              {accountOpen && (
                <div
                  className={cn(
                    'absolute bottom-full z-20 mb-2 w-56 overflow-hidden rounded-xl border border-mat-700 bg-mat-850 shadow-card',
                    collapsed ? 'left-0' : 'left-0 right-0'
                  )}
                >
                  <div className="border-b border-mat-700 px-3.5 py-3">
                    <p className="truncate text-sm font-bold text-ink-100">{user?.display_name || user?.name}</p>
                    <p className="truncate text-xs text-ink-500">@{user?.username || user?.email}</p>
                  </div>
                  <Link
                    to="/profile"
                    onClick={() => setAccountOpen(false)}
                    className="flex items-center gap-2.5 px-3.5 py-2.5 text-sm font-semibold text-ink-300 hover:bg-mat-750 hover:text-ink-100"
                  >
                    <UserIcon size={15} /> Profile
                  </Link>
                  <button
                    onClick={() => { setAccountOpen(false); logout(); navigate('/') }}
                    className="flex w-full items-center gap-2.5 px-3.5 py-2.5 text-left text-sm font-semibold text-blood-400 hover:bg-mat-750"
                  >
                    <LogOut size={15} /> Sign out
                  </button>
                </div>
              )}

              <button
                onClick={() => setAccountOpen((o) => !o)}
                className={cn(
                  'flex w-full items-center gap-2.5 rounded-lg px-2 py-2 text-left transition-colors hover:bg-mat-850',
                  collapsed && 'justify-center px-0'
                )}
                title={collapsed ? (user?.display_name || user?.name) : undefined}
              >
                <Avatar user={user} size="sm" />
                {!collapsed && (
                  <>
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-xs font-bold text-ink-100">{user?.display_name || user?.name}</p>
                      <p className="truncate text-[11px] text-ink-500">@{user?.username || user?.email}</p>
                    </div>
                    <ChevronsUpDown size={14} className="shrink-0 text-ink-600" />
                  </>
                )}
              </button>
            </div>
          </>
        ) : (
          <div className="flex flex-col gap-2">
            <button
              onClick={() => navigate('/login')}
              className="w-full rounded-lg border border-mat-700 px-3 py-2 text-sm font-semibold text-ink-200 hover:bg-mat-850"
            >
              {collapsed ? <UserIcon size={16} className="mx-auto" /> : 'Sign in'}
            </button>
            {!collapsed && (
              <button
                onClick={() => navigate('/register')}
                className="w-full rounded-lg bg-gold-500 px-3 py-2 text-sm font-bold text-mat-950 hover:bg-gold-400"
              >
                Get Savvy
              </button>
            )}
          </div>
        )}
      </div>
    </aside>
  )
}

function NavSection({ label, items, collapsed, pinned, onTogglePin }) {
  if (items.length === 0) return null
  return (
    <div>
      {label && <p className="mb-1.5 px-2.5 text-[10px] font-bold uppercase tracking-wider text-ink-600">{label}</p>}
      <div className="space-y-0.5">
        {items.map((n) => (
          <SidebarLink
            key={n.to}
            to={n.to}
            icon={n.icon}
            label={n.label}
            collapsed={collapsed}
            pinnable
            pinned={pinned.includes(n.to)}
            onTogglePin={() => onTogglePin(n.to)}
          />
        ))}
      </div>
    </div>
  )
}

function SidebarLink({ to, icon: Icon, label, collapsed, badge, pinnable, pinned, onTogglePin }) {
  return (
    <div className="group/item relative">
      <NavLink
        to={to}
        className={({ isActive }) =>
          cn(
            'relative flex items-center gap-2.5 rounded-lg py-2 pl-2.5 pr-2 text-sm font-semibold transition-colors',
            collapsed && 'justify-center px-0',
            isActive ? 'bg-mat-800/80 text-gold-400' : 'text-ink-300 hover:bg-mat-850 hover:text-ink-100'
          )
        }
      >
        {({ isActive }) => (
          <>
            {isActive && !collapsed && (
              <span className="absolute inset-y-1.5 left-0 w-[3px] rounded-r-full bg-gold-400" />
            )}
            <Icon size={17} className="shrink-0" />
            {!collapsed && <span className="truncate">{label}</span>}
            {!collapsed && badge > 0 && (
              <span className="ml-auto flex h-5 min-w-5 items-center justify-center rounded-full bg-blood-500 px-1.5 text-[10px] font-bold text-white">
                {badge > 9 ? '9+' : badge}
              </span>
            )}
            {collapsed && badge > 0 && (
              <span className="absolute right-2 top-1.5 h-2 w-2 rounded-full bg-blood-500" />
            )}
          </>
        )}
      </NavLink>

      {collapsed && (
        <span className="pointer-events-none absolute left-full top-1/2 z-20 ml-2 -translate-y-1/2 whitespace-nowrap rounded-md border border-mat-700 bg-mat-850 px-2.5 py-1.5 text-xs font-semibold text-ink-100 opacity-0 shadow-card transition-opacity duration-100 group-hover/item:opacity-100">
          {label}
        </span>
      )}

      {pinnable && !collapsed && (
        <button
          onClick={onTogglePin}
          className={cn(
            'absolute right-1.5 top-1/2 -translate-y-1/2 rounded-md p-1 text-ink-600 transition-opacity hover:text-gold-400',
            pinned ? 'opacity-100' : 'opacity-0 group-hover/item:opacity-100'
          )}
          title={pinned ? 'Unpin from quick access' : 'Pin to quick access'}
          aria-label={pinned ? 'Unpin from quick access' : 'Pin to quick access'}
        >
          <Star size={13} className={pinned ? 'fill-gold-400 text-gold-400' : ''} />
        </button>
      )}
    </div>
  )
}
