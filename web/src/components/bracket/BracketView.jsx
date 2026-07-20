import React, { useMemo, useState, useCallback, useEffect } from 'react'
import { ZoomIn, ZoomOut, Maximize, List, GitBranch, Map as MapIcon, Check } from 'lucide-react'
import { cn } from '../../lib/utils'
import { layoutBracket, connectorPath, resolvePicks, METRICS } from './bracketMath'
import MatchCard from './MatchCard'
import usePanZoom from './usePanZoom'

/**
 * BracketView — reusable interactive bracket.
 *
 * props:
 *  data        — bracket view response {matches, competitors, rounds, weight_class}
 *  mode        — predict | results | readonly | compare | admin
 *  picks       — Map(matchId → wrestlerId)  (predict mode; controlled)
 *  onPick(match, wrestlerId|null)           (predict mode)
 *  onPicksCleared(matchIds)                 (predict mode — cascade info)
 *  view        — 'canvas' | 'list' (undefined → auto by screen size)
 */
export default function BracketView({ data, mode = 'readonly', picks, onPick, onPicksCleared, view: forcedView, className }) {
  const matches = data?.matches ?? []
  const competitorsById = useMemo(
    () => new Map((data?.competitors ?? []).map((c) => [c.id, c])),
    [data?.competitors]
  )

  // resolve picks through the graph (predict mode) — over ALL matches, not
  // just the active section, since consolation/placement resolution depends
  // on championship picks cascading through
  const resolution = useMemo(() => {
    if (mode !== 'predict' || !picks) return null
    return resolvePicks(matches, picks, competitorsById)
  }, [matches, picks, competitorsById, mode])

  // Section tabs: championship / consolation / placement, each its own
  // focused close-up view rather than one long horizontal scroll. Only show
  // tabs for sections that actually have matches (some templates skip
  // consolation/placement entirely).
  const sectionCounts = useMemo(() => {
    const counts = { championship: 0, consolation: 0, placement: 0 }
    for (const m of matches) {
      if (counts[m.section] != null) counts[m.section]++
    }
    return counts
  }, [matches])
  const availableSections = SECTIONS.filter((s) => sectionCounts[s.key] > 0)
  const [activeSection, setActiveSection] = useState('championship')
  useEffect(() => {
    if (sectionCounts[activeSection] > 0) return
    const first = availableSections[0]?.key
    if (first) setActiveSection(first)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sectionCounts])

  const sectionMatches = useMemo(() => matches.filter((m) => m.section === activeSection), [matches, activeSection])
  const layout = useMemo(() => layoutBracket(sectionMatches), [sectionMatches])

  const sectionProgress = useMemo(() => {
    if (mode !== 'predict' || !picks) return null
    const out = {}
    for (const s of SECTIONS) out[s.key] = { picked: 0, total: 0 }
    for (const m of matches) {
      if (m.is_bye) continue
      const bucket = out[m.section]
      if (!bucket) continue
      bucket.total++
      if (picks.has(m.id)) bucket.picked++
    }
    return out
  }, [matches, picks, mode])

  // notify parent when picks were auto-cleared (stale downstream picks)
  useEffect(() => {
    if (resolution && resolution.cleared.length && onPicksCleared) {
      onPicksCleared(resolution.cleared)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [resolution?.cleared.join(',')])

  const [isNarrow, setIsNarrow] = useState(false)
  useEffect(() => {
    const mq = window.matchMedia('(max-width: 768px)')
    const fn = () => setIsNarrow(mq.matches)
    fn()
    mq.addEventListener('change', fn)
    return () => mq.removeEventListener('change', fn)
  }, [])
  const [viewOverride, setViewOverride] = useState(null)
  const view = forcedView ?? viewOverride ?? (isNarrow ? 'list' : 'canvas')

  if (!matches.length) {
    return (
      <div className="flex h-48 items-center justify-center rounded-xl border border-dashed border-mat-600 text-sm text-ink-500">
        Bracket not generated yet.
      </div>
    )
  }

  return (
    <div className={cn('relative', className)}>
      {/* section tabs + view toggle */}
      <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
        {availableSections.length > 1 ? (
          <div className="flex items-center gap-1 rounded-lg border border-mat-700 bg-mat-850 p-1">
            {availableSections.map((s) => {
              const prog = sectionProgress?.[s.key]
              const complete = prog && prog.total > 0 && prog.picked >= prog.total
              return (
                <button
                  key={s.key}
                  type="button"
                  onClick={() => setActiveSection(s.key)}
                  className={cn(
                    'flex items-center gap-1.5 rounded-md px-3 py-1.5 text-xs font-bold uppercase tracking-wide transition-colors',
                    activeSection === s.key ? 'bg-mat-700 text-gold-400' : 'text-ink-500 hover:text-ink-200'
                  )}
                >
                  {s.label}
                  {prog && (
                    <span className={cn('font-mono text-[10px] font-normal', complete ? 'text-pin-400' : 'text-ink-600')}>
                      {complete ? <Check size={11} className="inline" /> : `${prog.picked}/${prog.total}`}
                    </span>
                  )}
                </button>
              )
            })}
          </div>
        ) : (
          <span />
        )}
        <div className="flex items-center gap-1 rounded-lg border border-mat-700 bg-mat-850 p-1">
          <ViewButton active={view === 'canvas'} onClick={() => setViewOverride('canvas')} icon={GitBranch} label="Bracket" />
          <ViewButton active={view === 'list'} onClick={() => setViewOverride('list')} icon={List} label="List" />
        </div>
      </div>

      {view === 'canvas' ? (
        <CanvasView
          matches={sectionMatches}
          layout={layout}
          mode={mode}
          resolution={resolution}
          picks={picks}
          onPick={onPick}
          competitorsById={competitorsById}
          data={data}
        />
      ) : (
        <ListView matches={sectionMatches} mode={mode} resolution={resolution} picks={picks} onPick={onPick} data={data} />
      )}
    </div>
  )
}

const SECTIONS = [
  { key: 'championship', label: 'Championship' },
  { key: 'consolation', label: 'Consolation' },
  { key: 'placement', label: 'Placement' },
]

function ViewButton({ active, onClick, icon: Icon, label }) {
  return (
    <button
      onClick={onClick}
      className={cn(
        'flex items-center gap-1.5 rounded-md px-2.5 py-1.5 text-xs font-bold transition-colors',
        active ? 'bg-mat-700 text-gold-400' : 'text-ink-500 hover:text-ink-200'
      )}
    >
      <Icon size={13} /> {label}
    </button>
  )
}

/* ── Canvas (pan/zoom graph view) ─────────────────────── */
function CanvasView({ matches, layout, mode, resolution, picks, onPick, data }) {
  const pz = usePanZoom()
  const [showMinimap, setShowMinimap] = useState(false)

  // Focus round 1 at a readable scale on load/reflow instead of zooming out
  // to fit the entire graph (which makes cards too small to read or click).
  // Anchored to the top-left corner (not centered) — round 1 is usually
  // taller than the viewport, and vertically centering it leaves a large
  // empty gap above the first visible match.
  useEffect(() => {
    const t = setTimeout(() => {
      // matches passed in are already scoped to one section (tab), so any
      // col===0 entry is the right one regardless of which band it is
      const firstCol = [...layout.pos.values()].filter((p) => p.col === 0)
      if (!firstCol.length) {
        pz.fit()
        return
      }
      const scale = 0.95
      const pad = 24
      pz.setTransform({
        scale,
        x: pad - firstCol[0].x * scale,
        // anchor to content y=0 (the column header), not the first match —
        // otherwise the round labels render above the visible viewport
        y: pad,
      })
    }, 60)
    return () => clearTimeout(t)
    // layout is a new object on every tab switch (sectionMatches changes),
    // so this re-focuses correctly when moving between championship/
    // consolation/placement instead of keeping the old tab's transform
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [layout])

  const connectors = useMemo(() => {
    const out = []
    for (const m of matches) {
      const src = layout.pos.get(m.id)
      if (!src) continue
      if (m.winner_dest?.match_id && layout.pos.get(m.winner_dest.match_id)) {
        out.push({
          key: `w${m.id}`,
          ...connectorPath(src, layout.pos.get(m.winner_dest.match_id), m.winner_dest.slot),
          kind: 'winner',
          srcId: m.id,
        })
      }
      if (m.loser_dest?.match_id && layout.pos.get(m.loser_dest.match_id)) {
        out.push({
          key: `l${m.id}`,
          ...connectorPath(src, layout.pos.get(m.loser_dest.match_id), m.loser_dest.slot),
          kind: 'loser',
          srcId: m.id,
        })
      }
    }
    return out
  }, [matches, layout])

  // which connectors are "hot" (picked path in predict mode / winner path in results)
  const hotEdges = useMemo(() => {
    const hot = new Set()
    for (const m of matches) {
      const picked = mode === 'predict' ? picks?.get(m.id) : m.winner_competitor_id
      if (picked && m.winner_dest?.match_id) hot.add(`w${m.id}`)
      if (picked && mode !== 'predict' && m.loser_dest?.match_id && m.loser_competitor_id) hot.add(`l${m.id}`)
    }
    return hot
  }, [matches, picks, mode])

  const rounds = data?.rounds ?? []
  const roundForColumn = (col) => rounds.find((r) => r.section === (col.band === 'championship' ? 'championship' : 'consolation') && r.number === col.round)

  return (
    <div className="relative">
      <div
        ref={pz.containerRef}
        className="relative h-[68vh] min-h-[440px] touch-none overflow-hidden rounded-xl border border-mat-700 bg-mat-900/60"
        data-no-pan="false"
      >
        <div
          ref={pz.contentRef}
          className="absolute left-0 top-0 origin-top-left"
          style={{
            width: layout.width,
            height: layout.height,
            transform: `translate(${pz.transform.x}px, ${pz.transform.y}px) scale(${pz.transform.scale})`,
          }}
        >
          {/* column headers */}
          {layout.columns.map((col) => {
            const r = roundForColumn(col)
            const label = col.band === 'placement' ? 'Placement' : r?.label ?? `Round ${col.round}`
            return (
              <div
                key={col.key}
                className="absolute flex items-center gap-2"
                style={{ left: col.x, top: col.band === 'consolation' ? (layout.consBandTop ?? 0) : 0, width: METRICS.MATCH_W }}
              >
                <span className={cn(
                  'text-[10px] font-bold uppercase tracking-[0.14em]',
                  col.band === 'placement' ? 'text-gold-500' : col.band === 'consolation' ? 'text-ink-500' : 'text-gold-400'
                )}>
                  {label}
                </span>
                <span className="font-mono text-[9px] text-ink-600">{col.matches}</span>
              </div>
            )
          })}

          {/* SVG connectors */}
          <svg className="absolute left-0 top-0 pointer-events-none" width={layout.width} height={layout.height}>
            {connectors.map((c) => (
              <path
                key={c.key}
                d={c.d}
                fill="none"
                stroke={
                  hotEdges.has(c.key)
                    ? mode === 'predict' ? 'var(--color-gold-500)' : 'var(--color-pin-500)'
                    : c.kind === 'loser' ? 'var(--color-mat-600)' : 'var(--color-mat-500)'
                }
                strokeWidth={hotEdges.has(c.key) ? 2 : 1.25}
                strokeDasharray={c.kind === 'loser' ? '5 4' : undefined}
                strokeOpacity={c.kind === 'loser' && !hotEdges.has(c.key) ? 0.55 : 1}
              />
            )
            )}
          </svg>

          {/* match cards */}
          {matches.map((m) => {
            const p = layout.pos.get(m.id)
            if (!p) return null
            const resolved = resolution?.resolved.get(m.id)
            const pickedId = mode === 'predict' ? picks?.get(m.id) : undefined
            return (
              <div key={m.id} className="absolute" style={{ left: p.x, top: p.y }}>
                <MatchCard match={m} mode={mode} resolved={resolved} pickedId={pickedId} onPick={onPick} />
              </div>
            )
          })}
        </div>

        {/* zoom controls */}
        <div className="absolute bottom-3 right-3 z-10 flex flex-col gap-1 rounded-lg border border-mat-700 bg-mat-850/95 p-1 shadow-card">
          <IconBtn onClick={() => pz.zoomBy(1.22)} label="Zoom in"><ZoomIn size={15} /></IconBtn>
          <IconBtn onClick={() => pz.zoomBy(0.82)} label="Zoom out"><ZoomOut size={15} /></IconBtn>
          <IconBtn onClick={() => pz.fit()} label="Fit to screen"><Maximize size={15} /></IconBtn>
        </div>

        {/* minimap (desktop) — hidden by default, toggled from the top bar */}
        {showMinimap && (
          <div className="absolute right-3 top-3 z-10 hidden md:block">
            <Minimap layout={layout} matches={matches} panZoom={pz} />
          </div>
        )}

        {/* top bar: pan hint + minimap toggle */}
        <div className="pointer-events-none absolute left-3 top-3 z-10 hidden items-center gap-2 md:flex">
          <span className="rounded bg-mat-850/80 px-2 py-1 text-[10px] font-semibold text-ink-500">
            Drag to pan · Ctrl+scroll to zoom
          </span>
          <button
            type="button"
            data-no-pan="true"
            onClick={() => setShowMinimap((v) => !v)}
            className={cn(
              'pointer-events-auto flex items-center gap-1 rounded px-2 py-1 text-[10px] font-semibold transition-colors',
              showMinimap ? 'bg-gold-500/20 text-gold-400' : 'bg-mat-850/80 text-ink-500 hover:text-ink-200'
            )}
          >
            <MapIcon size={11} /> Map
          </button>
        </div>
      </div>
    </div>
  )
}

function IconBtn({ onClick, children, label }) {
  return (
    <button onClick={onClick} aria-label={label} className="rounded-md p-1.5 text-ink-400 transition-colors hover:bg-mat-700 hover:text-gold-400">
      {children}
    </button>
  )
}

function Minimap({ layout, matches, panZoom }) {
  // Fit within a fixed compact box (letterboxed) instead of a fixed width
  // stretched to the bracket's true aspect ratio — a tall bracket (championship
  // + consolation bands stacked) would otherwise blow up the minimap's height.
  // Sized generously since it's opt-in (hidden unless toggled on).
  const MAX_W = 280
  const MAX_H = 200
  const scale = Math.min(MAX_W / layout.width, MAX_H / layout.height)
  const W = Math.max(48, layout.width * scale)
  const H = Math.max(32, layout.height * scale)
  const [view, setView] = useState({ x: 0, y: 0, w: 60, h: 40 })

  useEffect(() => {
    const c = panZoom.containerRef.current
    if (!c) return
    const update = () => {
      const { x, y, scale: s } = panZoom.transform
      setView({
        x: (-x / s) * scale,
        y: (-y / s) * scale,
        w: (c.clientWidth / s) * scale,
        h: (c.clientHeight / s) * scale,
      })
    }
    update()
    const t = setInterval(update, 200)
    return () => clearInterval(t)
  }, [panZoom, scale])

  return (
    <div
      className="relative cursor-pointer overflow-hidden rounded-lg border border-mat-700 bg-mat-900/90"
      style={{ width: W, height: H }}
      onClick={(e) => {
        const rect = e.currentTarget.getBoundingClientRect()
        const px = (e.clientX - rect.left) / scale
        const py = (e.clientY - rect.top) / scale
        panZoom.center(px, py)
      }}
    >
      {matches.map((m) => {
        const p = layout.pos.get(m.id)
        if (!p) return null
        return (
          <span
            key={m.id}
            className={cn(
              'absolute rounded-[1px]',
              m.section === 'championship' ? 'bg-gold-500/50' : m.section === 'placement' ? 'bg-gold-300/40' : 'bg-ink-600/50'
            )}
            style={{
              left: p.x * scale,
              top: p.y * scale,
              width: Math.max(2, METRICS.MATCH_W * scale),
              height: Math.max(1.5, METRICS.MATCH_H * scale),
            }}
          />
        )
      })}
      <span
        className="absolute border border-gold-400 bg-gold-400/10"
        style={{ left: view.x, top: view.y, width: view.w, height: view.h }}
      />
    </div>
  )
}

/* ── List view (mobile default + a11y) ────────────────── */
function ListView({ matches, mode, resolution, picks, onPick, data }) {
  const groups = useMemo(() => {
    const order = { championship: 0, placement: 1, consolation: 2 }
    const sorted = [...matches].sort(
      (a, b) => order[a.section] - order[b.section] || (a.round_number ?? 0) - (b.round_number ?? 0) || a.match_number - b.match_number
    )
    const out = []
    let cur = null
    for (const m of sorted) {
      const key = `${m.section}-${m.round_number}`
      if (!cur || cur.key !== key) {
        cur = { key, label: m.round_label, section: m.section, matches: [] }
        out.push(cur)
      }
      cur.matches.push(m)
    }
    return out
  }, [matches])

  return (
    <div className="space-y-5">
      {groups.map((g) => (
        <section key={g.key}>
          <h3 className={cn(
            'mb-2 text-[11px] font-bold uppercase tracking-[0.14em]',
            g.section === 'championship' ? 'text-gold-400' : g.section === 'placement' ? 'text-gold-500' : 'text-ink-500'
          )}>
            {g.label}
            <span className="ml-2 font-mono text-[9px] font-normal text-ink-600">{g.matches.length}</span>
          </h3>
          <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
            {g.matches.map((m) => (
              <MatchCard
                key={m.id}
                match={m}
                mode={mode}
                resolved={resolution?.resolved.get(m.id)}
                pickedId={mode === 'predict' ? picks?.get(m.id) : undefined}
                onPick={onPick}
                fluid
              />
            ))}
          </div>
        </section>
      ))}
    </div>
  )
}
