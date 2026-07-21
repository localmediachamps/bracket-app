import { useEffect, useState, useCallback } from 'react'
import { useMutation } from '@tanstack/react-query'
import { api } from '../lib/api'

const STORAGE_KEY = 'mat-savvy-results-analyst-messages'

function loadStored() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    return raw ? JSON.parse(raw) : []
  } catch {
    return []
  }
}

// The agent's run response includes its full step trace, so the exact filter
// arguments it settled on for search_match_results are already sitting right
// there - no need for a separate structured-output mechanism. Takes the LAST
// call (the most refined query, if the agent searched more than once) so a
// "View in Results" link reflects what it actually answered from.
function extractFilters(data) {
  const steps = data?.steps
  if (!Array.isArray(steps)) return null
  let lastArgs = null
  for (const step of steps) {
    const content = step?.content
    if (!Array.isArray(content)) continue
    for (const block of content) {
      if (block?.type === 'tool-call' && block?.toolName === 'search_match_results' && block?.input) {
        lastArgs = block.input
      }
    }
  }
  if (!lastArgs) return null
  const { query, school, wrestler, event_name, weight_class, start_date, end_date } = lastArgs
  if (!query && !school && !wrestler && !event_name && !weight_class && !start_date && !end_date) return null
  return { q: query, school, wrestler, event_name, weight_class, start_date, end_date }
}

/**
 * Chat state for the Results Analyst AI (admin-only for now). Each call to
 * /admin/results-analyst is a single independent question — the agent has no
 * server-side memory of prior turns, so this hook only ever sends the latest
 * message, not the full thread. Messages persist to localStorage purely so a
 * refresh doesn't wipe the visible conversation.
 */
export function useResultsAnalystChat() {
  const [messages, setMessages] = useState(loadStored)

  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(messages))
    } catch {
      // Ignore storage errors
    }
  }, [messages])

  const mutation = useMutation({
    mutationFn: (message) => api.resultsAnalystAsk(message),
    onSuccess: (data) => {
      const content = data?.result || "I didn't get a response back — try rephrasing the question."
      const filters = extractFilters(data)
      setMessages((prev) => [...prev, { id: `assistant-${Date.now()}`, role: 'assistant', content, filters }])
    },
    onError: (error) => {
      setMessages((prev) => [
        ...prev,
        { id: `error-${Date.now()}`, role: 'assistant', content: `Something went wrong: ${error.message || 'request failed'}`, isError: true },
      ])
    },
  })

  const sendMessage = useCallback(
    (text) => {
      const trimmed = text.trim()
      if (!trimmed) return
      setMessages((prev) => [...prev, { id: `user-${Date.now()}`, role: 'user', content: trimmed }])
      mutation.mutate(trimmed)
    },
    [mutation]
  )

  const clearChat = useCallback(() => {
    setMessages([])
    try {
      localStorage.removeItem(STORAGE_KEY)
    } catch {
      // Ignore storage errors
    }
  }, [])

  return { messages, sendMessage, clearChat, isLoading: mutation.isPending }
}
