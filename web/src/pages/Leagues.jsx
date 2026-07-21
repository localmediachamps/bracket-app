import React from 'react'
import { Link } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { AlertTriangle, Plus, RefreshCw, Swords } from 'lucide-react'
import { api } from '../lib/api'
import { Button, CardSkeleton, EmptyState } from '../components/ui'
import LeagueCard from '../components/league/LeagueCard'

const rise = {
  hidden: { opacity: 0, y: 14 },
  show: { opacity: 1, y: 0, transition: { duration: 0.35, ease: [0.22, 1, 0.36, 1] } },
}
const stagger = { hidden: {}, show: { transition: { staggerChildren: 0.06 } } }

export default function Leagues() {
  const { data, isLoading, isError, error, refetch, isRefetching } = useQuery({
    queryKey: ['my-leagues'],
    queryFn: api.myLeagues,
  })

  const rows = data ?? []

  return (
    <motion.div variants={stagger} initial="hidden" animate="show" className="space-y-8 py-6">
      <motion.header variants={rise} className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="font-display text-3xl uppercase tracking-tight text-ink-100 sm:text-4xl">
            My <span className="text-gold-400">Leagues</span>
          </h1>
          <p className="mt-1.5 text-sm text-ink-500">Draft a roster, run your lineup, chase the belt all season.</p>
        </div>
        <Link to="/leagues/new">
          <Button>
            <Plus size={16} /> Create league
          </Button>
        </Link>
      </motion.header>

      {isLoading ? (
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {Array.from({ length: 3 }).map((_, i) => (
            <CardSkeleton key={i} />
          ))}
        </div>
      ) : isError ? (
        <EmptyState
          icon={<AlertTriangle size={26} />}
          title="Leagues failed to load"
          body={error?.message}
          action={
            <Button onClick={() => refetch()} loading={isRefetching}>
              <RefreshCw size={15} /> Try again
            </Button>
          }
        />
      ) : rows.length === 0 ? (
        <EmptyState
          icon={<Swords size={26} />}
          title="You're not in any leagues yet"
          body="Create a private league, invite your crew, and draft the full D1 field."
          action={
            <Link to="/leagues/new">
              <Button>
                <Plus size={16} /> Create your first league
              </Button>
            </Link>
          }
        />
      ) : (
        <motion.div variants={stagger} className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {rows.map((row) => (
            <motion.div key={(row.league ?? row).id} variants={rise}>
              <LeagueCard row={row} />
            </motion.div>
          ))}
        </motion.div>
      )}
    </motion.div>
  )
}
