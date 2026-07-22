import React, { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { Search, GraduationCap, ChevronLeft, ChevronRight } from 'lucide-react'
import { api } from '../lib/api'
import { Card, CardSkeleton, EmptyState, Select } from '../components/ui'
import { ErrorState } from '../components/tournament/Feedback'
import { cn } from '../lib/utils'

const WEIGHTS = ['125', '133', '141', '149', '157', '165', '174', '184', '197', '285']
const PER_PAGE = 24

// Some display_name values in the historical import carry raw HTML entities
// (e.g. "Ramon &quot;MyKey&quot; Ramos") - decode via the browser's own
// parser rather than hardcoding a handful of entity names.
function decodeHtml(str) {
  if (!str) return str
  const el = document.createElement('textarea')
  el.innerHTML = str
  return el.value
}

export default function Wrestlers() {
  const [q, setQ] = useState('')
  const [qDebounced, setQDebounced] = useState('')
  const [teamId, setTeamId] = useState('')
  const [weight, setWeight] = useState('')
  const [sort, setSort] = useState('name')
  const [page, setPage] = useState(1)

  useEffect(() => {
    const t = setTimeout(() => setQDebounced(q.trim()), 300)
    return () => clearTimeout(t)
  }, [q])

  useEffect(() => {
    setPage(1)
  }, [qDebounced, teamId, weight, sort])

  const { data: teamsData } = useQuery({ queryKey: ['teams'], queryFn: api.teams })
  const teams = teamsData?.teams ?? []

  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['wrestlerLibrary', qDebounced, teamId, weight, sort, page],
    queryFn: () =>
      api.wrestlerLibrary({
        q: qDebounced || undefined,
        team_id: teamId || undefined,
        weight_class: weight || undefined,
        sort,
        page,
        per: PER_PAGE,
      }),
    keepPreviousData: true,
  })

  const items = data?.items ?? []
  const total = data?.total ?? 0
  const totalPages = Math.max(1, Math.ceil(total / PER_PAGE))
  const activeFilterCount = (teamId ? 1 : 0) + (weight ? 1 : 0)

  return (
    <div className="mx-auto max-w-5xl px-4 py-8">
      <h1 className="font-display text-2xl text-ink-50">Wrestler Library</h1>
      <p className="mt-1 text-sm text-ink-400">Search every wrestler in the system — filter by school and weight class.</p>

      <div className="mt-5 flex flex-col gap-3 sm:flex-row sm:flex-wrap sm:items-center">
        <div className="relative max-w-sm flex-1">
          <Search size={16} className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-ink-500" />
          <input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Search wrestlers…"
            className="w-full rounded-lg border border-mat-700 bg-mat-850 py-2 pl-9 pr-3 text-sm text-ink-100 placeholder:text-ink-600 focus:border-gold-500/50 focus:outline-none"
          />
        </div>

        <Select value={teamId} onChange={(e) => setTeamId(e.target.value)} className="sm:w-52">
          <option value="">All schools</option>
          {teams.map((t) => (
            <option key={t.id} value={t.id}>{t.name}</option>
          ))}
        </Select>

        <Select value={weight} onChange={(e) => setWeight(e.target.value)} className="sm:w-36">
          <option value="">All weights</option>
          {WEIGHTS.map((w) => (
            <option key={w} value={w}>{w} lbs</option>
          ))}
        </Select>

        <Select value={sort} onChange={(e) => setSort(e.target.value)} className="sm:w-40">
          <option value="name">Sort: Name</option>
          <option value="weight">Sort: Weight</option>
        </Select>

        {activeFilterCount > 0 && (
          <button
            onClick={() => { setTeamId(''); setWeight('') }}
            className="text-xs font-semibold text-ink-500 hover:text-ink-200"
          >
            Clear filters ({activeFilterCount})
          </button>
        )}
      </div>

      <div className="mt-5">
        {isLoading ? (
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {Array.from({ length: 9 }).map((_, i) => <CardSkeleton key={i} />)}
          </div>
        ) : isError ? (
          <ErrorState error={error} onRetry={refetch} title="Couldn't load wrestlers" />
        ) : items.length === 0 ? (
          <EmptyState icon={<GraduationCap size={22} />} title="No wrestlers found" body="Try a different search or filter." />
        ) : (
          <>
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
              {items.map((w) => (
                <Link key={w.id} to={`/wrestlers/${w.id}`}>
                  <Card hover className="p-4">
                    <div className="flex items-center gap-3">
                      <span className={cn('flex h-10 w-10 shrink-0 items-center justify-center rounded-xl', w.current_team?.logo_url ? 'bg-white p-1.5' : 'bg-mat-800 text-gold-500')}>
                        {w.current_team?.logo_url ? (
                          <img src={w.current_team.logo_url} alt="" className="h-full w-full object-contain" loading="lazy" />
                        ) : (
                          <GraduationCap size={18} />
                        )}
                      </span>
                      <div className="min-w-0">
                        <p className="truncate font-bold text-ink-100">{decodeHtml(w.display_name)}</p>
                        <p className="truncate text-xs text-ink-500">
                          {w.current_team?.name ?? 'Unknown school'}
                          {w.current_weight_class ? ` · ${w.current_weight_class} lbs` : ''}
                        </p>
                      </div>
                    </div>
                  </Card>
                </Link>
              ))}
            </div>

            {totalPages > 1 && (
              <div className="mt-6 flex items-center justify-center gap-3">
                <button
                  onClick={() => setPage((p) => Math.max(1, p - 1))}
                  disabled={page <= 1}
                  className="flex h-8 w-8 items-center justify-center rounded-lg border border-mat-700 text-ink-300 hover:bg-mat-850 disabled:opacity-40"
                >
                  <ChevronLeft size={15} />
                </button>
                <span className="text-xs font-semibold text-ink-500">Page {page} of {totalPages}</span>
                <button
                  onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                  disabled={page >= totalPages}
                  className="flex h-8 w-8 items-center justify-center rounded-lg border border-mat-700 text-ink-300 hover:bg-mat-850 disabled:opacity-40"
                >
                  <ChevronRight size={15} />
                </button>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  )
}
