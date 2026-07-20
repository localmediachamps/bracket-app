import React, { useEffect, useRef, useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { X, Check, AlertTriangle, Info, Loader2, ChevronDown } from 'lucide-react'
import { cn, initials } from '../../lib/utils'
import { useToastStore } from '../../lib/store'

/* ── Button ───────────────────────────────────────────── */
export function Button({ variant = 'primary', size = 'md', loading, className, children, disabled, ...props }) {
  const variants = {
    primary: 'bg-gold-500 text-mat-950 font-bold hover:bg-gold-400 active:bg-gold-600 shadow-glow-sm disabled:bg-mat-600 disabled:text-ink-500 disabled:shadow-none',
    secondary: 'border border-mat-600 bg-mat-800 text-ink-100 font-semibold hover:border-gold-500/50 hover:bg-mat-750 disabled:opacity-50',
    ghost: 'text-ink-300 font-semibold hover:text-ink-100 hover:bg-mat-800 disabled:opacity-50',
    danger: 'bg-blood-500/15 text-blood-400 border border-blood-500/40 font-semibold hover:bg-blood-500/25 disabled:opacity-50',
    success: 'bg-pin-500/15 text-pin-400 border border-pin-500/40 font-semibold hover:bg-pin-500/25 disabled:opacity-50',
  }
  const sizes = {
    xs: 'h-7 px-2.5 text-xs rounded-lg gap-1',
    sm: 'h-8 px-3 text-sm rounded-lg gap-1.5',
    md: 'h-10 px-4 text-sm rounded-xl gap-2',
    lg: 'h-12 px-6 text-base rounded-xl gap-2',
    xl: 'h-14 px-8 text-lg rounded-2xl gap-2.5',
  }
  return (
    <button
      className={cn('inline-flex items-center justify-center transition-all duration-150 select-none disabled:cursor-not-allowed', variants[variant], sizes[size], className)}
      disabled={disabled || loading}
      {...props}
    >
      {loading && <Loader2 size={16} className="animate-spin" />}
      {children}
    </button>
  )
}

/* ── Card ─────────────────────────────────────────────── */
export function Card({ className, children, hover, ...props }) {
  return (
    <div
      className={cn(
        // min-w-0 keeps this safe as a flex/grid item: without it, a long
        // unbreakable string in a truncated descendant can force this card
        // (and its grid track) wider than the viewport even though the
        // descendant itself renders truncated — flex/grid items default to
        // min-width:auto (content-based), not min-width:0.
        'min-w-0 rounded-xl border border-mat-700 bg-mat-850 shadow-card',
        hover && 'transition-all duration-200 hover:border-gold-500/40 hover:-translate-y-0.5 hover:shadow-glow',
        className
      )}
      {...props}
    >
      {children}
    </div>
  )
}

/* ── Badge / StatusPill ───────────────────────────────── */
export function Badge({ color = 'ink', pulse, className, children }) {
  const colors = {
    gold: 'bg-gold-500/12 text-gold-400 border-gold-500/30',
    blood: 'bg-blood-500/12 text-blood-400 border-blood-500/30',
    pin: 'bg-pin-500/12 text-pin-400 border-pin-500/30',
    ink: 'bg-mat-700/60 text-ink-300 border-mat-600',
  }
  return (
    <span className={cn('inline-flex items-center gap-1.5 rounded-full border px-2.5 py-0.5 text-[11px] font-bold uppercase tracking-wider', colors[color], className)}>
      {pulse && <span className={cn('h-1.5 w-1.5 rounded-full animate-pulse-dot', color === 'blood' ? 'bg-blood-400' : color === 'pin' ? 'bg-pin-400' : 'bg-gold-400')} />}
      {children}
    </span>
  )
}

export function StatusPill({ status, className }) {
  const map = {
    draft: { color: 'ink', label: 'Draft' },
    importing: { color: 'ink', label: 'Importing' },
    needs_review: { color: 'gold', label: 'Needs Review' },
    open: { color: 'pin', label: 'Open' },
    locked: { color: 'gold', label: 'Locked' },
    live: { color: 'blood', label: 'Live', pulse: true },
    completed: { color: 'ink', label: 'Completed' },
    archived: { color: 'ink', label: 'Archived' },
    cancelled: { color: 'blood', label: 'Cancelled' },
    pending: { color: 'ink', label: 'Pending' },
    in_progress: { color: 'blood', label: 'In Progress', pulse: true },
    complete: { color: 'pin', label: 'Final' },
    corrected: { color: 'gold', label: 'Corrected' },
    submitted: { color: 'pin', label: 'Submitted' },
    active: { color: 'pin', label: 'Active' },
  }
  const s = map[status] || { color: 'ink', label: status }
  return <Badge color={s.color} pulse={s.pulse} className={className}>{s.label}</Badge>
}

/* ── Inputs ───────────────────────────────────────────── */
export function Input({ label, error, hint, className, ...props }) {
  return (
    <label className="block">
      {label && <span className="mb-1.5 block text-xs font-bold uppercase tracking-wider text-ink-500">{label}</span>}
      <input
        className={cn(
          'w-full rounded-xl border bg-mat-800 px-3.5 h-11 text-sm text-ink-100 placeholder:text-ink-600 transition-colors',
          'border-mat-600 hover:border-mat-500 focus:border-gold-500 focus:outline-none focus:ring-2 focus:ring-gold-500/25',
          error && 'border-blood-500 focus:border-blood-500 focus:ring-blood-500/25',
          className
        )}
        {...props}
      />
      {hint && !error && <span className="mt-1 block text-xs text-ink-500">{hint}</span>}
      {error && <span className="mt-1 block text-xs font-semibold text-blood-400">{error}</span>}
    </label>
  )
}

export function Textarea({ label, error, className, ...props }) {
  return (
    <label className="block">
      {label && <span className="mb-1.5 block text-xs font-bold uppercase tracking-wider text-ink-500">{label}</span>}
      <textarea
        className={cn(
          'w-full rounded-xl border border-mat-600 bg-mat-800 px-3.5 py-3 text-sm text-ink-100 placeholder:text-ink-600 transition-colors',
          'hover:border-mat-500 focus:border-gold-500 focus:outline-none focus:ring-2 focus:ring-gold-500/25',
          error && 'border-blood-500',
          className
        )}
        {...props}
      />
      {error && <span className="mt-1 block text-xs font-semibold text-blood-400">{error}</span>}
    </label>
  )
}

export function Select({ label, error, className, children, ...props }) {
  return (
    <label className="block">
      {label && <span className="mb-1.5 block text-xs font-bold uppercase tracking-wider text-ink-500">{label}</span>}
      <div className="relative">
        <select
          className={cn(
            'w-full appearance-none rounded-xl border border-mat-600 bg-mat-800 px-3.5 h-11 pr-10 text-sm text-ink-100 transition-colors',
            'hover:border-mat-500 focus:border-gold-500 focus:outline-none focus:ring-2 focus:ring-gold-500/25',
            error && 'border-blood-500',
            className
          )}
          {...props}
        >
          {children}
        </select>
        <ChevronDown size={16} className="pointer-events-none absolute right-3.5 top-1/2 -translate-y-1/2 text-ink-500" />
      </div>
      {error && <span className="mt-1 block text-xs font-semibold text-blood-400">{error}</span>}
    </label>
  )
}

export function Switch({ checked, onChange, label, description }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      onClick={() => onChange(!checked)}
      className="flex w-full items-center justify-between gap-4 rounded-xl border border-mat-700 bg-mat-800 px-4 py-3 text-left transition-colors hover:border-mat-500"
    >
      <span>
        <span className="block text-sm font-semibold text-ink-100">{label}</span>
        {description && <span className="mt-0.5 block text-xs text-ink-500">{description}</span>}
      </span>
      <span className={cn('relative h-6 w-11 shrink-0 rounded-full transition-colors', checked ? 'bg-gold-500' : 'bg-mat-600')}>
        <span className={cn('absolute top-0.5 h-5 w-5 rounded-full bg-white transition-transform', checked ? 'translate-x-[22px]' : 'translate-x-0.5')} />
      </span>
    </button>
  )
}

/* ── Tabs ─────────────────────────────────────────────── */
export function Tabs({ tabs, active, onChange, className }) {
  return (
    <div className={cn('flex gap-1 overflow-x-auto no-scrollbar border-b border-mat-700', className)} role="tablist">
      {tabs.map((t) => (
        <button
          key={t.key}
          role="tab"
          aria-selected={active === t.key}
          onClick={() => onChange(t.key)}
          className={cn(
            'relative whitespace-nowrap px-4 py-2.5 text-sm font-semibold transition-colors',
            active === t.key ? 'text-gold-400' : 'text-ink-500 hover:text-ink-200'
          )}
        >
          <span className="inline-flex items-center gap-2">
            {t.icon}
            {t.label}
            {t.count !== undefined && (
              <span className={cn('rounded-full px-1.5 py-0.5 text-[10px] font-bold', active === t.key ? 'bg-gold-500/20 text-gold-400' : 'bg-mat-700 text-ink-500')}>
                {t.count}
              </span>
            )}
          </span>
          {active === t.key && <motion.span layoutId="tab-underline" className="absolute inset-x-2 -bottom-px h-0.5 rounded-full bg-gold-500" />}
        </button>
      ))}
    </div>
  )
}

/* ── Modal ────────────────────────────────────────────── */
export function Modal({ open, onClose, title, children, wide }) {
  useEffect(() => {
    if (!open) return
    const fn = (e) => e.key === 'Escape' && onClose?.()
    window.addEventListener('keydown', fn)
    return () => window.removeEventListener('keydown', fn)
  }, [open, onClose])
  return (
    <AnimatePresence>
      {open && (
        <motion.div
          className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-6"
          initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
        >
          <div className="absolute inset-0 bg-mat-950/80 backdrop-blur-sm" onClick={onClose} />
          <motion.div
            role="dialog" aria-modal="true"
            className={cn('relative w-full rounded-t-2xl sm:rounded-2xl border border-mat-600 bg-mat-850 shadow-card max-h-[92vh] overflow-y-auto', wide ? 'sm:max-w-4xl' : 'sm:max-w-lg')}
            initial={{ y: 40, opacity: 0, scale: 0.98 }}
            animate={{ y: 0, opacity: 1, scale: 1 }}
            exit={{ y: 30, opacity: 0, scale: 0.98 }}
            transition={{ type: 'spring', damping: 28, stiffness: 380 }}
          >
            <div className="sticky top-0 z-10 flex items-center justify-between border-b border-mat-700 bg-mat-850/95 px-5 py-4 backdrop-blur">
              <h3 className="font-display text-sm uppercase tracking-wide text-ink-100">{title}</h3>
              <button onClick={onClose} className="rounded-lg p-1.5 text-ink-500 hover:bg-mat-700 hover:text-ink-100" aria-label="Close">
                <X size={18} />
              </button>
            </div>
            <div className="p-5">{children}</div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  )
}

/* ── Toasts ───────────────────────────────────────────── */
export function Toaster() {
  const { toasts, dismiss } = useToastStore()
  const icons = { success: <Check size={15} />, error: <AlertTriangle size={15} />, info: <Info size={15} />, default: <Info size={15} /> }
  const colors = {
    success: 'border-pin-500/50 text-pin-400',
    error: 'border-blood-500/50 text-blood-400',
    info: 'border-gold-500/50 text-gold-400',
    default: 'border-mat-600 text-ink-200',
  }
  return (
    <div className="pointer-events-none fixed right-4 top-4 z-[100] flex w-[calc(100vw-2rem)] max-w-sm flex-col gap-2">
      <AnimatePresence>
        {toasts.map((t) => (
          <motion.div
            key={t.id}
            layout
            initial={{ opacity: 0, x: 60, scale: 0.95 }}
            animate={{ opacity: 1, x: 0, scale: 1 }}
            exit={{ opacity: 0, x: 40, scale: 0.95 }}
            className={cn('pointer-events-auto flex items-start gap-3 rounded-xl border bg-mat-850/95 px-4 py-3 shadow-card backdrop-blur', colors[t.variant])}
          >
            <span className="mt-0.5 shrink-0">{icons[t.variant]}</span>
            <div className="min-w-0 flex-1">
              <p className="text-sm font-semibold text-ink-100">{t.title}</p>
              {t.body && <p className="mt-0.5 text-xs text-ink-400">{t.body}</p>}
            </div>
            <button onClick={() => dismiss(t.id)} className="shrink-0 text-ink-600 hover:text-ink-200" aria-label="Dismiss">
              <X size={14} />
            </button>
          </motion.div>
        ))}
      </AnimatePresence>
    </div>
  )
}

/* ── Skeleton ─────────────────────────────────────────── */
export function Skeleton({ className }) {
  return <div className={cn('animate-pulse rounded-lg bg-mat-800', className)} />
}

export function CardSkeleton() {
  return (
    <Card className="p-5">
      <Skeleton className="h-5 w-2/3" />
      <Skeleton className="mt-3 h-4 w-1/3" />
      <div className="mt-4 flex gap-2">
        <Skeleton className="h-6 w-16" />
        <Skeleton className="h-6 w-16" />
        <Skeleton className="h-6 w-16" />
      </div>
    </Card>
  )
}

/* ── EmptyState ───────────────────────────────────────── */
export function EmptyState({ icon, title, body, action, className }) {
  return (
    <div className={cn('flex flex-col items-center justify-center rounded-xl border border-dashed border-mat-600 bg-mat-900/50 px-6 py-14 text-center', className)}>
      <div className="mb-4 flex h-14 w-14 items-center justify-center rounded-2xl bg-mat-800 text-gold-500">{icon}</div>
      <h3 className="font-display text-sm uppercase tracking-wide text-ink-200">{title}</h3>
      {body && <p className="mt-2 max-w-sm text-sm text-ink-500">{body}</p>}
      {action && <div className="mt-5">{action}</div>}
    </div>
  )
}

/* ── Avatar ───────────────────────────────────────────── */
export function Avatar({ user, size = 'md', ring, className }) {
  const sizes = { xs: 'h-6 w-6 text-[9px]', sm: 'h-8 w-8 text-[11px]', md: 'h-10 w-10 text-sm', lg: 'h-14 w-14 text-lg', xl: 'h-20 w-20 text-2xl' }
  const name = user?.display_name || user?.name || user?.username || '?'
  return user?.avatar_url ? (
    <img src={user.avatar_url} alt={name} className={cn('shrink-0 rounded-full object-cover', sizes[size], ring && 'ring-2 ring-gold-500/60', className)} />
  ) : (
    <span className={cn('inline-flex shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-mat-600 to-mat-800 font-bold text-gold-400', sizes[size], ring && 'ring-2 ring-gold-500/60', className)}>
      {initials(name)}
    </span>
  )
}

/* ── ProgressRing ─────────────────────────────────────── */
export function ProgressRing({ value, size = 36, stroke = 3.5, className, children }) {
  const r = (size - stroke) / 2
  const c = 2 * Math.PI * r
  const v = Math.max(0, Math.min(1, value ?? 0))
  return (
    <span className={cn('relative inline-flex items-center justify-center', className)} style={{ width: size, height: size }}>
      <svg width={size} height={size} className="-rotate-90">
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="var(--color-mat-700)" strokeWidth={stroke} />
        <circle
          cx={size / 2} cy={size / 2} r={r} fill="none"
          stroke={v >= 1 ? 'var(--color-pin-400)' : 'var(--color-gold-500)'}
          strokeWidth={stroke} strokeLinecap="round"
          strokeDasharray={c} strokeDashoffset={c * (1 - v)}
          style={{ transition: 'stroke-dashoffset 0.5s cubic-bezier(0.22,1,0.36,1)' }}
        />
      </svg>
      <span className="absolute inset-0 flex items-center justify-center text-[9px] font-bold text-ink-300">
        {children ?? `${Math.round(v * 100)}%`}
      </span>
    </span>
  )
}

/* ── Stat ─────────────────────────────────────────────── */
export function Stat({ label, value, sub, icon, className, mono = true }) {
  return (
    <div className={cn('rounded-xl border border-mat-700 bg-mat-850 px-4 py-3.5', className)}>
      <div className="flex items-center justify-between">
        <span className="text-[10px] font-bold uppercase tracking-[0.12em] text-ink-500">{label}</span>
        {icon && <span className="text-gold-500/70">{icon}</span>}
      </div>
      <div className={cn('mt-1.5 text-2xl font-bold text-ink-100', mono && 'font-mono tracking-tight')}>{value}</div>
      {sub && <div className="mt-0.5 text-xs text-ink-500">{sub}</div>}
    </div>
  )
}

/* ── Countdown ────────────────────────────────────────── */
export function Countdown({ to, className, doneLabel = 'Locked' }) {
  const [, tick] = useState(0)
  useEffect(() => {
    const t = setInterval(() => tick((n) => n + 1), 30000)
    return () => clearInterval(t)
  }, [])
  const diff = new Date(to).getTime() - Date.now()
  if (!to || diff <= 0) {
    return <span className={cn('font-mono text-sm font-bold text-blood-400', className)}>{doneLabel}</span>
  }
  const d = Math.floor(diff / 86400000)
  const h = Math.floor((diff % 86400000) / 3600000)
  const m = Math.floor((diff % 3600000) / 60000)
  const urgent = diff < 3600000 * 6
  return (
    <span className={cn('inline-flex items-center gap-1 font-mono text-sm font-bold', urgent ? 'text-blood-400' : 'text-gold-400', className)}>
      {d > 0 && <span>{d}d</span>}
      <span>{String(h).padStart(2, '0')}h</span>
      <span>{String(m).padStart(2, '0')}m</span>
    </span>
  )
}

/* ── RankChange arrow ─────────────────────────────────── */
export function RankChange({ value }) {
  if (!value) return <span className="text-ink-600">—</span>
  if (value > 0) return <span className="font-mono text-xs font-bold text-pin-400">▲{value}</span>
  return <span className="font-mono text-xs font-bold text-blood-400">▼{Math.abs(value)}</span>
}

/* ── SectionHeading ───────────────────────────────────── */
export function SectionHeading({ children, sub, className }) {
  return (
    <div className={cn('mb-4', className)}>
      <h2 className="font-display text-lg uppercase tracking-wide text-ink-100">{children}</h2>
      {sub && <p className="mt-1 text-sm text-ink-500">{sub}</p>}
    </div>
  )
}
