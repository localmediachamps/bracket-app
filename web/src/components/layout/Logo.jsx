import React from 'react'
import { Link } from 'react-router-dom'
import { cn } from '../../lib/utils'

export function Logo({ className }) {
  return (
    <Link to="/" className={cn('group inline-flex items-center', className)}>
      <img
        src="/branding/mat_savvy_logo_dark_landscape.svg"
        alt="Mat Savvy"
        className="h-8 w-auto transition-transform group-hover:scale-[1.02]"
      />
    </Link>
  )
}
