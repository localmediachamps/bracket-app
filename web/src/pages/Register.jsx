import React, { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useMutation } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { AlertTriangle, Eye, EyeOff, UserPlus } from 'lucide-react'
import { api } from '../lib/api'
import { useAuthStore, toast } from '../lib/store'
import { Button, Input } from '../components/ui'
import AuthLayout from '../components/tournament/AuthLayout'
import { displayName } from '../components/tournament/helpers'
import { cn } from '../lib/utils'

const PW_INPUT =
  'w-full rounded-xl border bg-mat-800 px-3.5 pr-11 h-11 text-sm text-ink-100 placeholder:text-ink-600 transition-colors border-mat-600 hover:border-mat-500 focus:border-gold-500 focus:outline-none focus:ring-2 focus:ring-gold-500/25'

function PasswordField({ label, value, onChange, error, show, onToggle, autoComplete }) {
  return (
    <label className="block">
      <span className="mb-1.5 block text-xs font-bold uppercase tracking-wider text-ink-500">{label}</span>
      <div className="relative">
        <input
          type={show ? 'text' : 'password'}
          autoComplete={autoComplete}
          placeholder="••••••••"
          value={value}
          onChange={onChange}
          className={cn(PW_INPUT, error && 'border-blood-500 focus:border-blood-500 focus:ring-blood-500/25')}
        />
        <button
          type="button"
          onClick={onToggle}
          aria-label={show ? 'Hide password' : 'Show password'}
          className="absolute right-3 top-1/2 -translate-y-1/2 text-ink-500 transition-colors hover:text-ink-200"
        >
          {show ? <EyeOff size={16} /> : <Eye size={16} />}
        </button>
      </div>
      {error && <span className="mt-1 block text-xs font-semibold text-blood-400">{error}</span>}
    </label>
  )
}

export default function Register() {
  const navigate = useNavigate()
  const setAuth = useAuthStore((s) => s.setAuth)
  const [form, setForm] = useState({ name: '', username: '', email: '', password: '', confirm: '' })
  const [showPw, setShowPw] = useState(false)
  const [errors, setErrors] = useState({})
  const [serverError, setServerError] = useState('')
  const [shake, setShake] = useState(0)

  const set = (key) => (e) => {
    setForm((f) => ({ ...f, [key]: e.target.value }))
    if (errors[key]) setErrors((x) => ({ ...x, [key]: undefined }))
    if (serverError) setServerError('')
  }

  const mutation = useMutation({
    mutationFn: () =>
      api.signup({
        name: form.name.trim(),
        username: form.username.trim() || undefined,
        email: form.email.trim(),
        password: form.password,
      }),
    onSuccess: (data) => {
      setAuth(data.authToken ?? data.token, data.user)
      toast.success(`Welcome to the mat, ${displayName(data.user)}`)
      navigate('/dashboard', { replace: true })
    },
    onError: (e) => {
      setServerError(e.message || 'Sign up failed. Please try again.')
      setShake((n) => n + 1)
    },
  })

  const submit = (e) => {
    e.preventDefault()
    setServerError('')
    const errs = {}
    if (!form.name.trim() || form.name.trim().length < 2) errs.name = 'Your name is required'
    if (form.username.trim() && !/^[a-zA-Z0-9_]{3,20}$/.test(form.username.trim()))
      errs.username = '3–20 chars: letters, numbers, underscores'
    if (!form.email.trim()) errs.email = 'Email is required'
    else if (!/^\S+@\S+\.\S+$/.test(form.email.trim())) errs.email = 'Enter a valid email address'
    if (!form.password) errs.password = 'Password is required'
    else if (form.password.length < 8) errs.password = 'At least 8 characters'
    if (form.confirm !== form.password) errs.confirm = 'Passwords do not match'
    setErrors(errs)
    if (Object.keys(errs).length) {
      setShake((n) => n + 1)
      return
    }
    mutation.mutate()
  }

  return (
    <AuthLayout
      quote="Champions are picked long before the whistle. Pick yours."
      attribution="— Takedown scouting report"
      title="Join the mat"
      sub="One account. Every tournament. Eternal bragging rights."
      footer={
        <span>
          Already have an account?{' '}
          <Link to="/login" className="font-bold text-gold-500 hover:text-gold-300">
            Sign in
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
            label="Full name"
            autoComplete="name"
            placeholder="Cael Sanderson"
            value={form.name}
            error={errors.name}
            onChange={set('name')}
          />
          <Input
            label="Username (optional)"
            autoComplete="username"
            placeholder="mat_wizard"
            hint="3–20 letters, numbers, underscores. Shown on leaderboards."
            value={form.username}
            error={errors.username}
            onChange={set('username')}
          />
          <Input
            label="Email"
            type="email"
            autoComplete="email"
            placeholder="you@example.com"
            value={form.email}
            error={errors.email}
            onChange={set('email')}
          />
          <PasswordField
            label="Password"
            autoComplete="new-password"
            value={form.password}
            error={errors.password}
            show={showPw}
            onToggle={() => setShowPw((v) => !v)}
            onChange={set('password')}
          />
          <PasswordField
            label="Confirm password"
            autoComplete="new-password"
            value={form.confirm}
            error={errors.confirm}
            show={showPw}
            onToggle={() => setShowPw((v) => !v)}
            onChange={set('confirm')}
          />
          <Button type="submit" size="lg" className="w-full" loading={mutation.isPending}>
            <UserPlus size={16} /> Create account
          </Button>
          <p className="text-center text-xs text-ink-600">Free forever. Your picks, your glory.</p>
        </form>
      </motion.div>
    </AuthLayout>
  )
}
