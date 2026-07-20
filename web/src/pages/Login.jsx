import React, { useState } from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { useMutation } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { AlertTriangle, Eye, EyeOff, LogIn } from 'lucide-react'
import { api } from '../lib/api'
import { useAuthStore, toast } from '../lib/store'
import { Button, Input } from '../components/ui'
import AuthLayout from '../components/tournament/AuthLayout'
import { displayName } from '../components/tournament/helpers'
import { cn } from '../lib/utils'

const PW_INPUT =
  'w-full rounded-xl border bg-mat-800 px-3.5 pr-11 h-11 text-sm text-ink-100 placeholder:text-ink-600 transition-colors border-mat-600 hover:border-mat-500 focus:border-gold-500 focus:outline-none focus:ring-2 focus:ring-gold-500/25'

export default function Login() {
  const navigate = useNavigate()
  const location = useLocation()
  const setAuth = useAuthStore((s) => s.setAuth)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPw, setShowPw] = useState(false)
  const [errors, setErrors] = useState({})
  const [serverError, setServerError] = useState('')
  const [shake, setShake] = useState(0)
  const from = location.state?.from || '/dashboard'

  const mutation = useMutation({
    mutationFn: () => api.login(email.trim(), password),
    onSuccess: (data) => {
      setAuth(data.authToken ?? data.token, data.user)
      toast.success(`Welcome back, ${displayName(data.user)}`)
      navigate(from, { replace: true })
    },
    onError: (e) => {
      setServerError(e.message || 'Sign in failed. Check your credentials and try again.')
      setShake((n) => n + 1)
    },
  })

  const submit = (e) => {
    e.preventDefault()
    setServerError('')
    const errs = {}
    if (!email.trim()) errs.email = 'Email is required'
    else if (!/^\S+@\S+\.\S+$/.test(email.trim())) errs.email = 'Enter a valid email address'
    if (!password) errs.password = 'Password is required'
    setErrors(errs)
    if (Object.keys(errs).length) {
      setShake((n) => n + 1)
      return
    }
    mutation.mutate()
  }

  return (
    <AuthLayout
      quote="Everyone has a bracket until the first whistle blows."
      attribution="— every fan in March"
      title="Sign in"
      sub="Back for another round? Your bracket missed you."
      footer={
        <span>
          New to Mat Savvy?{' '}
          <Link to="/register" className="font-bold text-gold-500 hover:text-gold-300">
            Create an account
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
          <Input
            label="Email"
            type="email"
            autoComplete="email"
            placeholder="you@example.com"
            value={email}
            error={errors.email}
            onChange={(e) => {
              setEmail(e.target.value)
              if (errors.email) setErrors((x) => ({ ...x, email: undefined }))
              if (serverError) setServerError('')
            }}
          />
          <label className="block">
            <span className="mb-1.5 block text-xs font-bold uppercase tracking-wider text-ink-500">Password</span>
            <div className="relative">
              <input
                type={showPw ? 'text' : 'password'}
                autoComplete="current-password"
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
          <Button type="submit" size="lg" className="w-full" loading={mutation.isPending}>
            <LogIn size={16} /> Sign in
          </Button>
        </form>
      </motion.div>
    </AuthLayout>
  )
}
