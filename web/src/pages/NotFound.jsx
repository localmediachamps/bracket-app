import React from 'react'
import { useNavigate } from 'react-router-dom'
import { motion } from 'framer-motion'
import { Swords, Home, Trophy } from 'lucide-react'
import { Button } from '../components/ui'

export default function NotFound() {
  const navigate = useNavigate()
  return (
    <div className="relative flex min-h-[65vh] items-center justify-center overflow-hidden rounded-2xl border border-mat-800">
      <div className="bg-mat-stripes absolute inset-0" aria-hidden="true" />
      <div className="bg-arena absolute inset-0" aria-hidden="true" />
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, ease: [0.22, 1, 0.36, 1] }}
        className="relative px-6 py-16 text-center"
      >
        <span className="mx-auto mb-6 flex h-14 w-14 items-center justify-center rounded-2xl bg-mat-800 text-gold-500">
          <Swords size={26} />
        </span>
        <p className="font-display text-7xl uppercase leading-none tracking-tight text-gold-500 sm:text-8xl">404</p>
        <h1 className="mt-4 font-display text-xl uppercase tracking-wide text-ink-100">Thrown off the mat</h1>
        <p className="mx-auto mt-3 max-w-sm text-sm text-ink-500">
          This page got caught in a headlock and never made it to the bracket. Let’s get you back to the action.
        </p>
        <div className="mt-8 flex flex-col items-center justify-center gap-3 sm:flex-row">
          <Button onClick={() => navigate('/')}>
            <Home size={15} /> Back to the arena
          </Button>
          <Button variant="secondary" onClick={() => navigate('/tournaments')}>
            <Trophy size={15} /> Browse tournaments
          </Button>
        </div>
      </motion.div>
    </div>
  )
}
