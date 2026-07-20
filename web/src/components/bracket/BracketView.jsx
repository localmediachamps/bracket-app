import React, { useMemo, useState, useCallback, useEffect } from 'react'
import { ZoomIn, ZoomOut, Maximize, List, GitBranch } from 'lucide-react'
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

  const layout = useMemo(() => layoutBracket(matches), [matches])

  // resolve picks through the graph (predict mode)
  const resolution = useMemo(() => {
    if (mode !== 'predict' || !picks) return null
    return resolvePicks(matches, picks, competitorsById)
  }, [matches, picks, competitorsById, mode])

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
      {/* view toggle + zoom controls */}
      <div className="mb-3 flex items-center justify-between gap-2">
        <div className="flex items-center gap-1 rounded-lg border border-mat-700 bg-mat-850 p-1">
          <ViewButton active={view === 'canvas'} onClick={() => setViewOverride('canvas')} icon={GitBranch} label="Bracket" />
          <ViewButton active={view === 'list'} onClick={() => setViewOverride('list')} icon={List} label="List" />
        </div>
      </div>

      {view === 'canvas' ? (
        <CanvasView
          matches={matches}
          layout={layout}
          mode={mode}
          resolution={resolution}
          picks={picks}
          onPick={onPick}
          competitorsById={competitorsById}
          data={data}
        />
      ) : (
        <ListView matches={matches} mode={mode} resolution={resolution} picks={picks} onPick={onPick} data={data} />
      )}
    </div>
  )
}

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

  // Focus round 1 at a readable scale on load/reflow instead of zooming out
  // to fit the entire graph (which makes cards too small to read or click).
  useEffect(() => {
    const t = setTimeout(() => {
      const firstCol = [...layout.pos.values()].filter((p) => p.col === 0 && p.band === 'championship')
      if (!firstCol.length) {
        pz.fit()
        return
      }
      const minY = Math.min(...firstCol.map((p) => p.y))
      const maxY = Math.max(...firstCol.map((p) => p.y + METRICS.MATCH_H))
      pz.center(firstCol[0].x + METRICS.MATCH_W / 2, (minY + maxY) / 2, 0.95)
    }, 60)
    return () => clearTimeout(t)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [layout.width, layout.height])

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

          {/* consolation band label */}
          {layout.consBandTop != null && (
            <div
              className="absolute flex items-center gap-3"
              style={{ left: 0, top: layout.consBandTop - 44, width: layout.width }}
            >
              <span className="h-px flex-1 bg-mat-700" />
              <span className="text-[10px] font-bold uppercase tracking-[0.2em] text-ink-500">Consolation</span>
              <span className="h-px flex-1 bg-mat-700" />
            </div>
          )}

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

        {/* minimap (desktop) */}
        <div className="absolute bottom-3 left-3 z-10 hidden md:block">
          <Minimap layout={layout} matches={matches} panZoom={pz} />
        </div>

        <div className="pointer-events-none absolute left-3 top-3 z-10 hidden rounded bg-mat-850/80 px-2 py-1 text-[10px] font-semibold text-ink-500 md:block">
          Drag to pan · Ctrl+scroll to zoom
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
  const MAX_W = 160
  const MAX_H = 96
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
