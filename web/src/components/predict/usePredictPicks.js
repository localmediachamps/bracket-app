import { useCallback, useMemo, useRef, useState } from 'react'
import { resolvePicks } from '../bracket/bracketMath'

/**
 * usePredictPicks — owns the global picks Map(matchId → wrestlerId) spanning ALL
 * weight classes of a tournament, plus server-merge semantics and progress math.
 *
 * Merge rule: the server value wins for a match until the user edits that match
 * (tracked per-match in `dirtyRef`); local edits win afterwards. `dirtyCount` is
 * the reactive signal that there are unsaved changes (drives autosave).
 *
 * Progress = server-reported progress (latest bracketView `entry.progress`,
 * tournament-wide) + the delta of dirty matches vs their last-known server value.
 */
export default function usePredictPicks() {
  const [picks, setPicks] = useState(() => new Map())
  const picksRef = useRef(picks)
  const serverRef = useRef(new Map()) // matchId → last-known server wrestler_id (or null)
  const dirtyRef = useRef(new Set()) // matchIds edited locally since last successful save
  const [dirtyCount, setDirtyCount] = useState(0)
  const [base, setBase] = useState({ picked: 0, total: 0 }) // server-reported progress

  const reset = useCallback(() => {
    picksRef.current = new Map()
    serverRef.current = new Map()
    dirtyRef.current = new Set()
    setPicks(picksRef.current)
    setDirtyCount(0)
    setBase({ picked: 0, total: 0 })
  }, [])

  const hasUnsaved = useCallback(() => dirtyRef.current.size > 0, [])

  /** Merge one weight's bracketView response (matches[].user_pick + entry.progress). */
  const mergeWeight = useCallback((data) => {
    if (!data) return
    const next = new Map(picksRef.current)
    let changed = false
    for (const m of data.matches ?? []) {
      const wid = m.is_bye ? null : (m.user_pick?.wrestler_id ?? null)
      serverRef.current.set(m.id, wid)
      if (dirtyRef.current.has(m.id)) continue
      if (wid == null) {
        if (next.delete(m.id)) changed = true
      } else if (next.get(m.id) !== wid) {
        next.set(m.id, wid)
        changed = true
      }
    }
    if (data.entry?.progress) setBase(data.entry.progress)
    if (changed) {
      picksRef.current = next
      setPicks(next)
    }
  }, [])

  /** Merge the full pick list from GET /entries/{id} (covers unloaded weights). */
  const mergePickList = useCallback((list) => {
    if (!Array.isArray(list)) return
    const next = new Map(picksRef.current)
    let changed = false
    for (const p of list) {
      const mid = p?.bracket_match_id ?? p?.match_id
      if (mid == null) continue
      if (p?.outcome === 'void') continue
      const wid = p?.wrestler_id ?? p?.picked_wrestler_id ?? null
      serverRef.current.set(mid, wid)
      if (dirtyRef.current.has(mid)) continue
      if (wid == null) {
        if (next.delete(mid)) changed = true
      } else if (next.get(mid) !== wid) {
        next.set(mid, wid)
        changed = true
      }
    }
    if (changed) {
      picksRef.current = next
      setPicks(next)
    }
  }, [])

  /**
   * Apply a user pick/unpick on a match in the ACTIVE weight. Computes the
   * downstream cascade locally (resolvePicks) and drops invalidated picks.
   * Returns how many downstream picks were cleared (for the toast).
   */
  const applyPick = useCallback((match, wrestlerId, matches, competitorsById) => {
    const next = new Map(picksRef.current)
    if (wrestlerId == null) next.delete(match.id)
    else next.set(match.id, wrestlerId)
    const inWeight = new Set(matches.map((m) => m.id))
    const weightPicks = new Map()
    for (const [id, wid] of next) if (inWeight.has(id)) weightPicks.set(id, wid)
    const { cleared } = resolvePicks(matches, weightPicks, competitorsById)
    let cascaded = 0
    for (const id of cleared) {
      if (next.has(id)) {
        next.delete(id)
        dirtyRef.current.add(id)
        if (id !== match.id) cascaded++
      }
    }
    dirtyRef.current.add(match.id)
    picksRef.current = next
    setPicks(next)
    setDirtyCount(dirtyRef.current.size)
    return cascaded
  }, [])

  /** Silently drop picks BracketView reports as invalid (e.g. after a data refresh). */
  const removeInvalid = useCallback((ids) => {
    if (!ids?.length) return
    const next = new Map(picksRef.current)
    let changed = false
    for (const id of ids) {
      if (next.delete(id)) {
        dirtyRef.current.add(id)
        changed = true
      }
    }
    if (changed) {
      picksRef.current = next
      setPicks(next)
      setDirtyCount(dirtyRef.current.size)
    }
  }, [])

  /** Server cleared picks in the save response — drop locally, mark clean. */
  const applyServerCleared = useCallback((ids) => {
    if (!ids?.length) return
    const next = new Map(picksRef.current)
    let changed = false
    for (const id of ids) {
      if (next.delete(id)) changed = true
      serverRef.current.set(id, null)
      dirtyRef.current.delete(id)
    }
    if (changed) {
      picksRef.current = next
      setPicks(next)
    }
    setDirtyCount(dirtyRef.current.size)
  }, [])

  /**
   * After a successful save of `snapshot`: dirty matches whose current value is
   * unchanged since the snapshot are now clean (server state = snapshot value).
   */
  const markSaved = useCallback((snapshot, progress) => {
    for (const id of [...dirtyRef.current]) {
      const cur = picksRef.current.get(id) ?? null
      const snap = snapshot?.get(id) ?? null
      if (cur === snap) {
        serverRef.current.set(id, snap)
        dirtyRef.current.delete(id)
      }
    }
    if (progress) setBase(progress)
    setDirtyCount(dirtyRef.current.size)
  }, [])

  const snapshot = useCallback(() => new Map(picksRef.current), [])

  const progress = useMemo(() => {
    let delta = 0
    for (const id of dirtyRef.current) {
      const local = picksRef.current.get(id) ? 1 : 0
      const server = serverRef.current.get(id) ? 1 : 0
      delta += local - server
    }
    const picked = Math.max(0, (base.picked ?? 0) + delta)
    const total = base.total ?? 0
    return { picked, total, complete: total > 0 && picked >= total }
    // dirtyCount is the invalidation signal for ref mutations
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [base, dirtyCount, picks])

  return {
    picks,
    progress,
    dirtyCount,
    reset,
    hasUnsaved,
    mergeWeight,
    mergePickList,
    applyPick,
    removeInvalid,
    applyServerCleared,
    markSaved,
    snapshot,
  }
}
