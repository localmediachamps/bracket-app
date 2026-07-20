import { useCallback, useEffect, useRef, useState } from 'react'

/**
 * usePanZoom — pan (drag / touch) + zoom (buttons, ctrl+wheel, pinch) for a
 * scrollable canvas. Returns containerRef + transform state + controls.
 */
export default function usePanZoom({ min = 0.3, max = 1.7 } = {}) {
  const containerRef = useRef(null)
  const contentRef = useRef(null)
  const [t, setT] = useState({ scale: 0.85, x: 24, y: 16 })
  const drag = useRef(null)
  const pinch = useRef(null)

  const clampScale = (s) => Math.min(max, Math.max(min, s))

  const zoomTo = useCallback((next, cx, cy) => {
    setT((prev) => {
      const scale = clampScale(next)
      const k = scale / prev.scale
      const rect = containerRef.current?.getBoundingClientRect()
      const px = cx !== undefined ? cx - (rect?.left ?? 0) : (rect?.width ?? 0) / 2
      const py = cy !== undefined ? cy - (rect?.top ?? 0) : (rect?.height ?? 0) / 2
      return { scale, x: px - (px - prev.x) * k, y: py - (py - prev.y) * k }
    })
  }, [])

  const zoomBy = useCallback((factor) => setT((p) => {
    const scale = clampScale(p.scale * factor)
    const rect = containerRef.current?.getBoundingClientRect()
    const px = (rect?.width ?? 0) / 2
    const py = (rect?.height ?? 0) / 2
    const k = scale / p.scale
    return { scale, x: px - (px - p.x) * k, y: py - (py - p.y) * k }
  }), [])

  const fit = useCallback(() => {
    const c = containerRef.current
    const content = contentRef.current
    if (!c || !content) return
    const cw = c.clientWidth
    const ch = c.clientHeight
    const w = content.scrollWidth || content.offsetWidth
    const h = content.scrollHeight || content.offsetHeight
    if (!w || !h) return
    const scale = clampScale(Math.min(cw / w, ch / h, 1))
    setT({ scale, x: (cw - w * scale) / 2, y: Math.max(12, (ch - h * scale) / 2) })
  }, [])

  useEffect(() => {
    const el = containerRef.current
    if (!el) return

    const onWheel = (e) => {
      if (!e.ctrlKey && !e.metaKey) return
      e.preventDefault()
      zoomTo(t.scale * (e.deltaY < 0 ? 1.12 : 0.89), e.clientX, e.clientY)
    }

    const onPointerDown = (e) => {
      if (e.target.closest('button, a, input, [data-no-pan="true"]')) return
      el.setPointerCapture(e.pointerId)
      drag.current = { id: e.pointerId, sx: e.clientX, sy: e.clientY, ox: t.x, oy: t.y }
    }
    const onPointerMove = (e) => {
      if (pinch.current) {
        const pts = pinch.current.points
        const idx = pts.findIndex((p) => p.id === e.pointerId)
        if (idx >= 0) pts[idx] = { id: e.pointerId, x: e.clientX, y: e.clientY }
        if (pts.length === 2) {
          const [a, b] = pts
          const dist = Math.hypot(a.x - b.x, a.y - b.y)
          const cx = (a.x + b.x) / 2
          const cy = (a.y + b.y) / 2
          if (pinch.current.startDist) {
            zoomTo(pinch.current.startScale * (dist / pinch.current.startDist), cx, cy)
          }
        }
        return
      }
      const d = drag.current
      if (!d || d.id !== e.pointerId) return
      // Snapshot d's fields now — setT's updater can run after this handler
      // returns (React may batch/defer it), by which point a pointerup
      // could have already nulled out drag.current out from under it.
      const nx = d.ox + (e.clientX - d.sx)
      const ny = d.oy + (e.clientY - d.sy)
      setT((p) => ({ ...p, x: nx, y: ny }))
    }
    const onPointerUp = (e) => {
      drag.current = null
      if (pinch.current) {
        pinch.current.points = pinch.current.points.filter((p) => p.id !== e.pointerId)
        if (pinch.current.points.length < 2) pinch.current = null
      }
    }
    const onSecondPointerDown = (e) => {
      // native pointer events: track 2 pointers for pinch
    }
    const pointers = new Map()
    const trackDown = (e) => {
      pointers.set(e.pointerId, { x: e.clientX, y: e.clientY })
      if (pointers.size === 2) {
        const [a, b] = [...pointers.values()]
        pinch.current = {
          points: [
            { id: [...pointers.keys()][0], x: a.x, y: a.y },
            { id: [...pointers.keys()][1], x: b.x, y: b.y },
          ],
          startDist: Math.hypot(a.x - b.x, a.y - b.y),
          startScale: t.scale,
        }
        drag.current = null
      }
    }
    const trackUp = (e) => pointers.delete(e.pointerId)

    el.addEventListener('wheel', onWheel, { passive: false })
    el.addEventListener('pointerdown', onPointerDown)
    el.addEventListener('pointerdown', trackDown)
    el.addEventListener('pointermove', onPointerMove)
    el.addEventListener('pointerup', onPointerUp)
    el.addEventListener('pointerup', trackUp)
    el.addEventListener('pointercancel', onPointerUp)
    el.addEventListener('pointercancel', trackUp)
    return () => {
      el.removeEventListener('wheel', onWheel)
      el.removeEventListener('pointerdown', onPointerDown)
      el.removeEventListener('pointerdown', trackDown)
      el.removeEventListener('pointermove', onPointerMove)
      el.removeEventListener('pointerup', onPointerUp)
      el.removeEventListener('pointerup', trackUp)
      el.removeEventListener('pointercancel', onPointerUp)
      el.removeEventListener('pointercancel', trackUp)
    }
  }, [t.scale, t.x, t.y, zoomTo])

  const center = useCallback((px, py, scale) => {
    const c = containerRef.current
    if (!c) return
    const s = scale ?? t.scale
    setT({ scale: s, x: c.clientWidth / 2 - px * s, y: c.clientHeight / 2 - py * s })
  }, [t.scale])

  return { containerRef, contentRef, transform: t, zoomBy, fit, center, setTransform: setT }
}
