import React from 'react'
import { AlertTriangle, RefreshCw } from 'lucide-react'
import { Button, EmptyState } from '../ui'

/** Standard query-error block with retry. */
export function ErrorState({ error, onRetry, title = 'Failed to load' }) {
  return (
    <EmptyState
      icon={<AlertTriangle size={22} />}
      title={title}
      body={error?.message || 'Something went wrong while talking to the server.'}
      action={
        onRetry ? (
          <Button variant="secondary" size="sm" onClick={onRetry}>
            <RefreshCw size={14} /> Try again
          </Button>
        ) : undefined
      }
    />
  )
}
