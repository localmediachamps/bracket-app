import React, { useEffect } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { useMutation } from '@tanstack/react-query'
import { AlertTriangle, CheckCircle2, Loader2 } from 'lucide-react'
import { api } from '../lib/api'
import { Button } from '../components/ui'
import AuthLayout from '../components/tournament/AuthLayout'
import { useAuthStore } from '../lib/store'

export default function VerifyEmail() {
  const [searchParams] = useSearchParams()
  const token = searchParams.get('token') || ''
  const isLoggedIn = useAuthStore((s) => !!s.token)

  const mutation = useMutation({
    mutationFn: () => api.verifyEmail(token),
  })

  useEffect(() => {
    if (token) mutation.mutate()
    // Only fire once per token, regardless of mutation identity churn.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token])

  return (
    <AuthLayout title="Verify your email" sub="Confirming your Mat Savvy account.">
      {!token ? (
        <div role="alert" className="flex items-start gap-2.5 rounded-xl border border-blood-500/30 bg-blood-500/10 px-4 py-3 text-sm text-blood-300">
          <AlertTriangle size={16} className="mt-0.5 shrink-0" />
          <span>This verification link is missing its token.</span>
        </div>
      ) : mutation.isPending || mutation.isIdle ? (
        <div className="flex flex-col items-center gap-3 py-6 text-center text-ink-400">
          <Loader2 size={24} className="animate-spin text-gold-500" />
          <p className="text-sm">Confirming your email…</p>
        </div>
      ) : mutation.isSuccess ? (
        <div className="flex flex-col items-center gap-4 py-6 text-center">
          <span className="flex h-12 w-12 items-center justify-center rounded-full bg-pin-500/12 text-pin-400">
            <CheckCircle2 size={24} />
          </span>
          <p className="text-sm text-ink-300">Your email is verified.</p>
          <Link to={isLoggedIn ? '/dashboard' : '/login'}>
            <Button size="lg">{isLoggedIn ? 'Go to dashboard' : 'Sign in'}</Button>
          </Link>
        </div>
      ) : (
        <div className="flex flex-col items-center gap-4 py-6 text-center">
          <div role="alert" className="flex w-full items-start gap-2.5 rounded-xl border border-blood-500/30 bg-blood-500/10 px-4 py-3 text-left text-sm text-blood-300">
            <AlertTriangle size={16} className="mt-0.5 shrink-0" />
            <span>{mutation.error?.message || 'This verification link is invalid or has expired.'}</span>
          </div>
          <Link to={isLoggedIn ? '/dashboard' : '/login'} className="font-bold text-gold-500 hover:text-gold-300">
            {isLoggedIn ? 'Go to dashboard' : 'Back to sign in'}
          </Link>
        </div>
      )}
    </AuthLayout>
  )
}
