import React from 'react'
import { NavLink, Outlet, useParams } from 'react-router-dom'
import { LayoutDashboard, Trophy, FileUp, ListChecks, SlidersHorizontal, BarChart3, ScrollText, Hammer, Satellite, Crown, ShieldAlert } from 'lucide-react'
import { cn } from '../../lib/utils'

/**
 * Admin shell — left rail inside the content area.
 * When inside a tournament (:id present in route), shows tournament sub-nav.
 */
export default function AdminShell() {
  const { id } = useParams()
  const items = [
    { to: '/admin', label: 'Dashboard', icon: LayoutDashboard, end: true },
    { to: '/admin/tournaments/new', label: 'New Tournament', icon: Trophy },
    { to: '/admin/rankings', label: 'Rankings', icon: Crown },
    ...(id
      ? [
          { to: `/admin/tournaments/${id}`, label: 'Overview', icon: Trophy, end: true },
          { to: `/admin/tournaments/${id}/builder`, label: 'Builder', icon: Hammer },
          { to: `/admin/tournaments/${id}/import`, label: 'PDF Import', icon: FileUp },
          { to: `/admin/tournaments/${id}/results`, label: 'Results', icon: ListChecks },
          { to: `/admin/tournaments/${id}/ingestion`, label: 'Ingestion', icon: Satellite },
          { to: `/admin/tournaments/${id}/scoring`, label: 'Scoring', icon: SlidersHorizontal },
          { to: `/admin/tournaments/${id}/analytics`, label: 'Analytics', icon: BarChart3 },
        ]
      : []),
    { to: '/admin/board', label: 'Message Board', icon: ShieldAlert },
    { to: '/admin/audit', label: 'Audit Log', icon: ScrollText },
  ]
  return (
    <div className="flex flex-col gap-6 lg:flex-row">
      <aside className="shrink-0 lg:w-52">
        <nav className="flex gap-1 overflow-x-auto no-scrollbar lg:sticky lg:top-20 lg:flex-col">
          {items.map((n) => (
            <NavLink
              key={n.to}
              to={n.to}
              end={n.end}
              className={({ isActive }) =>
                cn(
                  'flex items-center gap-2.5 whitespace-nowrap rounded-lg px-3.5 py-2.5 text-sm font-semibold transition-colors',
                  isActive ? 'bg-mat-800 text-gold-400' : 'text-ink-400 hover:bg-mat-850 hover:text-ink-100'
                )
              }
            >
              <n.icon size={16} />
              {n.label}
            </NavLink>
          ))}
        </nav>
      </aside>
      <div className="min-w-0 flex-1">
        <Outlet />
      </div>
    </div>
  )
}
