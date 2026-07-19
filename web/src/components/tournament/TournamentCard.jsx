import React from 'react'
import { Link } from 'react-router-dom'
import { motion } from 'framer-motion'
import { MapPin, Calendar, Layers, Swords, Users, ArrowRight, Clock } from 'lucide-react'
import { Card, StatusPill, Countdown } from '../ui'
import { formatDate } from '../../lib/utils'

function MiniStat({ icon: Icon, value, label }) {
  return (
    <div className="flex flex-col items-center gap-0.5">
      <span className="inline-flex items-center gap-1 font-mono text-sm font-bold text-ink-100">
        <Icon size={12} className="text-gold-500/70" />
        {value ?? '—'}
      </span>
      <span className="text-[9px] font-bold uppercase tracking-[0.12em] text-ink-600">{label}</span>
    </div>
  )
}

/**
 * TournamentCard — shared directory/landing card.
 * Consumes the /tournaments card shape (ARCHITECTURE.md §6).
 */
export default function TournamentCard({ tournament: t, index = 0 }) {
  const href = `/tournaments/${t.slug ?? t.id}`
  return (
    <motion.div
      initial={{ opacity: 0, y: 18 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: '-40px' }}
      transition={{ duration: 0.4, delay: Math.min(index * 0.06, 0.36), ease: [0.22, 1, 0.36, 1] }}
      className="h-full"
    >
      <Link to={href} className="group block h-full" aria-label={`View ${t.name}`}>
        <Card hover className="flex h-full flex-col p-5">
          <div className="flex items-start justify-between gap-3">
            <h3 className="font-display text-base uppercase leading-tight tracking-wide text-ink-100 transition-colors group-hover:text-gold-300">
              {t.name}
            </h3>
            <StatusPill status={t.status} className="shrink-0" />
          </div>

          <div className="mt-2 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-ink-500">
            {t.year && <span className="font-mono">{t.year}</span>}
            {(t.start_date || t.end_date) && (
              <span className="inline-flex items-center gap-1">
                <Calendar size={12} />
                {formatDate(t.start_date, { year: undefined })} – {formatDate(t.end_date, { year: undefined })}
              </span>
            )}
            {t.location && (
              <span className="inline-flex items-center gap-1">
                <MapPin size={12} />
                {t.location}
              </span>
            )}
          </div>

          <div className="mt-4 grid grid-cols-3 gap-2 border-t border-mat-700/80 pt-3">
            <MiniStat icon={Layers} value={t.weight_class_count} label="Weights" />
            <MiniStat icon={Swords} value={t.competitor_count} label="Athletes" />
            <MiniStat icon={Users} value={t.entry_count} label="Players" />
          </div>

          <div className="mt-auto flex items-center justify-between pt-4">
            {t.status === 'open' && t.locks_at ? (
              <span className="inline-flex items-center gap-1.5 text-xs text-ink-500">
                <Clock size={13} className="text-gold-500/80" />
                Locks in <Countdown to={t.locks_at} className="text-xs" />
              </span>
            ) : (
              <span />
            )}
            <span className="inline-flex items-center gap-1 text-xs font-bold text-gold-500 opacity-0 transition-all duration-200 group-hover:translate-x-0.5 group-hover:opacity-100">
              View <ArrowRight size={13} />
            </span>
          </div>
        </Card>
      </Link>
    </motion.div>
  )
}
