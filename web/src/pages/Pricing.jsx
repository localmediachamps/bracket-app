import React, { useEffect, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { Check, Crown, ScrollText, ArrowRight } from 'lucide-react'
import { api } from '../lib/api'
import { toast, useAuthStore } from '../lib/store'
import { Button, Card, Badge, Skeleton } from '../components/ui'
import { cn } from '../lib/utils'

const rise = {
  hidden: { opacity: 0, y: 14 },
  show: { opacity: 1, y: 0, transition: { duration: 0.35, ease: [0.22, 1, 0.36, 1] } },
}
const stagger = { hidden: {}, show: { transition: { staggerChildren: 0.08 } } }

const FREE_FEATURES = [
  'Browse and predict brackets and pick\'em teams for any open tournament',
  'Up to 3 tournaments with a submitted entry, ever (any mix of bracket + pick\'em)',
  'Create private groups and run your own pool with friends',
  'Full access to the Results Library',
]

const ANNUAL_FEATURES = [
  'Unlimited tournament entries — bracket and pick\'em, every event',
  'Create and commission season-long fantasy leagues',
  'Everything in the free plan',
]

export default function Pricing() {
  const token = useAuthStore((s) => s.token)
  const [loadingCheckout, setLoadingCheckout] = useState(false)

  const { data: status, isLoading } = useQuery({
    queryKey: ['billing', 'status'],
    queryFn: api.billingStatus,
    enabled: !!token,
    retry: false,
  })

  const isAnnual = status?.plan === 'annual'

  useEffect(() => {
    const params = new URLSearchParams(window.location.search)
    if (params.get('checkout') === 'cancelled') {
      toast.info('Checkout cancelled', { body: 'No charge was made — pick up whenever you\'re ready.' })
      window.history.replaceState({}, '', window.location.pathname)
    }
  }, [])

  const startCheckout = async () => {
    if (!token) {
      window.location.href = '/register'
      return
    }
    setLoadingCheckout(true)
    try {
      const origin = window.location.origin
      const res = await api.billingCheckout(`${origin}/profile`, `${origin}/pricing`)
      window.location.href = res.checkout_url
    } catch (err) {
      toast.error('Could not start checkout', { body: err.message })
      setLoadingCheckout(false)
    }
  }

  return (
    <motion.div variants={stagger} initial="hidden" animate="show" className="mx-auto max-w-4xl py-10">
      <motion.header variants={rise} className="mb-10 text-center">
        <h1 className="font-display text-3xl uppercase tracking-tight text-ink-100 sm:text-4xl">
          Simple <span className="text-gold-400">pricing</span>
        </h1>
        <p className="mx-auto mt-3 max-w-lg text-sm text-ink-500 sm:text-base">
          Play free with a cap on how many tournaments you can enter, or go annual for unlimited play and season-long fantasy leagues.
        </p>
      </motion.header>

      <div className="grid gap-5 sm:grid-cols-2">
        {/* Free plan */}
        <motion.div variants={rise}>
          <Card className="flex h-full flex-col p-6">
            <div className="mb-1 flex items-center gap-2">
              <ScrollText size={18} className="text-ink-400" />
              <h2 className="font-display text-base uppercase tracking-wide text-ink-100">Free</h2>
            </div>
            <div className="mb-5 font-mono text-3xl font-bold text-ink-100">$0</div>
            <ul className="mb-6 flex-1 space-y-2.5">
              {FREE_FEATURES.map((f) => (
                <li key={f} className="flex items-start gap-2 text-sm text-ink-300">
                  <Check size={15} className="mt-0.5 shrink-0 text-ink-500" />
                  <span>{f}</span>
                </li>
              ))}
            </ul>
            {!isLoading && !isAnnual && token && (
              <div className="mb-3">
                <span className="text-xs text-ink-500">
                  {status?.submissions_used ?? 0} / {status?.submissions_limit ?? 3} tournaments used
                </span>
              </div>
            )}
            <Button variant="secondary" disabled className="w-full">
              {token && !isAnnual ? 'Your current plan' : 'Free plan'}
            </Button>
          </Card>
        </motion.div>

        {/* Annual plan */}
        <motion.div variants={rise}>
          <Card className="relative flex h-full flex-col overflow-hidden border-gold-500/40 p-6 shadow-glow-sm">
            <Badge color="gold" className="absolute right-4 top-4">Best value</Badge>
            <div className="mb-1 flex items-center gap-2">
              <Crown size={18} className="text-gold-400" />
              <h2 className="font-display text-base uppercase tracking-wide text-ink-100">Annual</h2>
            </div>
            <div className="mb-5 flex items-baseline gap-1.5">
              <span className="font-mono text-3xl font-bold text-gold-400">$29.99</span>
              <span className="text-sm text-ink-500">/ year</span>
            </div>
            <ul className="mb-6 flex-1 space-y-2.5">
              {ANNUAL_FEATURES.map((f) => (
                <li key={f} className="flex items-start gap-2 text-sm text-ink-200">
                  <Check size={15} className="mt-0.5 shrink-0 text-gold-400" />
                  <span>{f}</span>
                </li>
              ))}
            </ul>
            {isLoading && token ? (
              <Skeleton className="h-11 w-full" />
            ) : isAnnual ? (
              <Button variant="secondary" disabled className="w-full">
                <Check size={15} /> Your current plan
              </Button>
            ) : (
              <Button className="w-full" onClick={startCheckout} loading={loadingCheckout}>
                Go annual <ArrowRight size={15} />
              </Button>
            )}
          </Card>
        </motion.div>
      </div>
    </motion.div>
  )
}
