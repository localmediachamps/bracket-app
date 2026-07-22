import React, { useState, useMemo } from 'react'
import { Link } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { Search, Building2 } from 'lucide-react'
import { api } from '../lib/api'
import { Card, CardSkeleton, EmptyState } from '../components/ui'
import { ErrorState } from '../components/tournament/Feedback'
import { cn } from '../lib/utils'

export default function Teams() {
  const [q, setQ] = useState('')

  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['teams'],
    queryFn: api.teams,
  })

  const teams = data?.teams ?? []
  const filtered = useMemo(() => {
    const s = q.trim().toLowerCase()
    if (!s) return teams
    return teams.filter((t) => t.name.toLowerCase().includes(s))
  }, [teams, q])

  return (
    <div className="mx-auto max-w-5xl px-4 py-8">
      <h1 className="font-display text-2xl text-ink-50">Teams</h1>
      <p className="mt-1 text-sm text-ink-400">Browse every D1 program's roster and history.</p>

      <div className="relative mt-5 max-w-sm">
        <Search size={16} className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-ink-500" />
        <input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Search teams..."
          className="w-full rounded-lg border border-mat-700 bg-mat-850 py-2 pl-9 pr-3 text-sm text-ink-100 placeholder:text-ink-600 focus:border-gold-500/50 focus:outline-none"
        />
      </div>

      <div className="mt-5">
        {isLoading ? (
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {Array.from({ length: 9 }).map((_, i) => <CardSkeleton key={i} />)}
          </div>
        ) : isError ? (
          <ErrorState error={error} onRetry={refetch} title="Couldn't load teams" />
        ) : filtered.length === 0 ? (
          <EmptyState icon={<Building2 size={22} />} title="No teams found" body="Try a different search." />
        ) : (
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {filtered.map((t) => (
              <Link key={t.id} to={`/teams/${t.id}`}>
                <Card hover className="p-4">
                  <div className="flex items-center gap-3">
                    <span className={cn('flex h-10 w-10 shrink-0 items-center justify-center rounded-xl', t.logo_url ? 'bg-white p-1.5' : 'bg-mat-800 text-gold-500')}>
                      {t.logo_url ? (
                        <img src={t.logo_url} alt="" className="h-full w-full object-contain" loading="lazy" />
                      ) : (
                        <Building2 size={18} />
                      )}
                    </span>
                    <div className="min-w-0">
                      <p className="truncate font-bold text-ink-100">{t.name}</p>
                      <p className="text-xs text-ink-500">{t.roster_count} on roster</p>
                    </div>
                  </div>
                </Card>
              </Link>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
