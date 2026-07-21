import React, { useState } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'
import { useMutation } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { AlertTriangle, Eye, EyeOff, KeyRound } from 'lucide-react'
import { api } from '../lib/api'
import { useAuthStore, toast } from '../lib/store'
import { Button } from '../components/ui'
import AuthLayout from '../components/tournament/AuthLayout'
import { displayName } from '../components/tournament/helpers'
import { cn } from '../lib/utils'

const PW_INPUT =
  'w-full rounded-xl border bg-mat-800 px-3.5 pr-11 h-11 text-sm text-ink-100 placeholder:text-ink-600 transition-colors border-mat-600 hover:border-mat-500 focus:border-gold-500 focus:outline-none focus:ring-2 focus:ring-gold-500/25'

export default function ResetPassword() {
  const [searchParams] = useSearchParams()
  const token = searchParams.get('token') || ''
  const navigate = useNavigate()
  const setAuth = useAuthStore((s) => s.setAuth)

  const [password, setPassword] = useState('')
  const [confirm, setConfirm] = useState('')
  const [showPw, setShowPw] = useState(false)
  const [errors, setErrors] = useState({})
  const [serverError, setServerError] = useState('')
  const [shake, setShake] = useState(0)

  const mutation = useMutation({
    mutationFn: () => api.resetPassword(token, password),
    onSuccess: (data) => {
      setAuth(data.authToken ?? data.token, data.user)
      toast.success(`Password reset. Welcome back, ${displayName(data.user)}`)
      navigate('/dashboard', { replace: true })
    },
    onError: (e) => {
      setServerError(e.message || 'That link is invalid or has expired.')
      setShake((n) => n + 1)
    },
  })

  const submit = (e) => {
    e.preventDefault()
    setServerError('')
    const errs = {}
    if (password.length < 8) errs.password = 'At least 8 characters'
    if (password !== confirm) errs.confirm = "Passwords don't match"
    setErrors(errs)
    if (Object.keys(errs).length) {
      setShake((n) => n + 1)
      return
    }
    mutation.mutate()
  }

  if (!token) {
    return (
      <AuthLayout title="Reset your password" sub="This link is missing its reset token.">
        <div role="alert" className="flex items-start gap-2.5 rounded-xl border border-blood-500/30 bg-blood-500/10 px-4 py-3 text-sm text-blood-300">
          <AlertTriangle size={16} className="mt-0.5 shrink-0" />
          <span>
            This reset link looks broken. <Link to="/forgot-password" className="font-bold underline">Request a new one</Link>.
          </span>
        </div>
      </AuthLayout>
    )
  }

  return (
    <AuthLayout
      title="Set a new password"
      sub="Choose a new password for your account."
      footer={
        <span>
          Remembered it?{' '}
          <Link to="/login" className="font-bold text-gold-500 hover:text-gold-300">
            Back to sign in
          </Link>
        </span>
      }
    >
      <motion.div key={shake} animate={{ x: [0, -10, 10, -6, 6, 0] }} transition={{ duration: 0.4 }}>
        {serverError && (
          <div role="alert" className="mb-4 flex items-start gap-2.5 rounded-xl border border-blood-500/30 bg-blood-500/10 px-4 py-3 text-sm text-blood-300">
            <AlertTriangle size={16} className="mt-0.5 shrink-0" />
            <span>{serverError}</span>
          </div>
        )}
        <form onSubmit={submit} noValidate className="space-y-4">
          <label className="block">
            <span className="mb-1.5 block text-xs font-bold uppercase tracking-wider text-ink-500">New password</span>
            <div className="relative">
              <input
                type={showPw ? 'text' : 'password'}
                autoComplete="new-password"
                placeholder="••••••••"
                value={password}
                onChange={(e) => {
                  setPassword(e.target.value)
                  if (errors.password) setErrors((x) => ({ ...x, password: undefined }))
                  if (serverError) setServerError('')
                }}
                className={cn(PW_INPUT, errors.password && 'border-blood-500 focus:border-blood-500 focus:ring-blood-500/25')}
              />
              <button
                type="button"
                onClick={() => setShowPw((v) => !v)}
                aria-label={showPw ? 'Hide password' : 'Show password'}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-ink-500 transition-colors hover:text-ink-200"
              >
                {showPw ? <EyeOff size={16} /> : <Eye size={16} />}
              </button>
            </div>
            {errors.password && <span className="mt-1 block text-xs font-semibold text-blood-400">{errors.password}</span>}
          </label>
          <label className="block">
            <span className="mb-1.5 block text-xs font-bold uppercase tracking-wider text-ink-500">Confirm password</span>
            <input
              type={showPw ? 'text' : 'password'}
              autoComplete="new-password"
              placeholder="••••••••"
              value={confirm}
              onChange={(e) => {
                setConfirm(e.target.value)
                if (errors.confirm) setErrors((x) => ({ ...x, confirm: undefined }))
                if (serverError) setServerError('')
              }}
              className={cn(PW_INPUT, 'pr-3.5', errors.confirm && 'border-blood-500 focus:border-blood-500 focus:ring-blood-500/25')}
            />
            {errors.confirm && <span className="mt-1 block text-xs font-semibold text-blood-400">{errors.confirm}</span>}
          </label>
          <Button type="submit" size="lg" className="w-full" loading={mutation.isPending}>
            <KeyRound size={16} /> Reset password
          </Button>
        </form>
      </motion.div>
    </AuthLayout>
  )
}
