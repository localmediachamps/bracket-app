import React, { useState } from 'react'
import { Link } from 'react-router-dom'
import { useMutation } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { CheckCircle2, Mail } from 'lucide-react'
import { api } from '../lib/api'
import { Button, Input } from '../components/ui'
import AuthLayout from '../components/tournament/AuthLayout'

export default function ForgotPassword() {
  const [email, setEmail] = useState('')
  const [error, setError] = useState('')

  const mutation = useMutation({
    mutationFn: () => api.forgotPassword(email.trim()),
  })

  const submit = (e) => {
    e.preventDefault()
    setError('')
    if (!/^\S+@\S+\.\S+$/.test(email.trim())) {
      setError('Enter a valid email address')
      return
    }
    mutation.mutate()
  }

  return (
    <AuthLayout
      quote="Every comeback starts with someone showing up again."
      attribution="— every wrestling coach, probably"
      title="Forgot your password?"
      sub="Enter the email on your account and we'll send you a reset link."
      footer={
        <span>
          Remembered it after all?{' '}
          <Link to="/login" className="font-bold text-gold-500 hover:text-gold-300">
            Back to sign in
          </Link>
        </span>
      }
    >
      {mutation.isSuccess ? (
        <motion.div
          initial={{ opacity: 0, y: 6 }}
          animate={{ opacity: 1, y: 0 }}
          className="flex flex-col items-center gap-3 py-6 text-center"
        >
          <span className="flex h-12 w-12 items-center justify-center rounded-full bg-pin-500/12 text-pin-400">
            <CheckCircle2 size={24} />
          </span>
          <p className="text-sm text-ink-300">
            If an account exists for <strong className="text-ink-100">{email.trim()}</strong>, a reset link is on its way. Check your inbox.
          </p>
        </motion.div>
      ) : (
        <form onSubmit={submit} noValidate className="space-y-4">
          <Input
            label="Email"
            type="email"
            autoComplete="email"
            placeholder="you@example.com"
            value={email}
            error={error}
            onChange={(e) => {
              setEmail(e.target.value)
              if (error) setError('')
            }}
          />
          <Button type="submit" size="lg" className="w-full" loading={mutation.isPending}>
            <Mail size={16} /> Send reset link
          </Button>
        </form>
      )}
    </AuthLayout>
  )
}
