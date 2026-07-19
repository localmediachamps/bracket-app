import React, { useEffect, useRef, useState } from 'react'
import { formatPoints } from '../../lib/utils'

/**
 * AnimatedNumber — counts up from 0 (or previous value) to `value`.
 * Respects prefers-reduced-motion (renders final value immediately).
 */
export default function AnimatedNumber({ value, duration = 900, className }) {
  const target = Number(value) || 0
  const [display, setDisplay] = useState(0)
  const fromRef = useRef(0)
  const rafRef = useRef(null)

  useEffect(() => {
    const reduced = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches
    if (reduced) {
      setDisplay(target)
      fromRef.current = target
      return
    }
    const from = fromRef.current
    const start = performance.now()
    const tick = (now) => {
      const t = Math.min(1, (now - start) / duration)
      const eased = 1 - Math.pow(1 - t, 3)
      const v = from + (target - from) * eased
      setDisplay(v)
      if (t < 1) rafRef.current = requestAnimationFrame(tick)
      else fromRef.current = target
    }
    rafRef.current = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(rafRef.current)
  }, [target, duration])

  const shown = target % 1 !== 0 ? display.toFixed(1) : String(Math.round(display))
  return <span className={className}>{formatPoints(shown)}</span>
}
