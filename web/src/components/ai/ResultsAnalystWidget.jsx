import { useEffect, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { AnimatePresence, motion } from 'framer-motion'
import { Sparkles, X, Send, Trash2, ScrollText } from 'lucide-react'
import ReactMarkdown from 'react-markdown'
import remarkGfm from 'remark-gfm'
import { cn } from '../../lib/utils'
import { Button } from '../ui'
import { useResultsAnalystChat } from '../../hooks/useResultsAnalystChat'

function resultsUrl(filters) {
  const params = new URLSearchParams()
  if (filters.q) params.set('q', filters.q)
  if (filters.school) params.set('school', filters.school)
  if (filters.wrestler) params.set('wrestler', filters.wrestler)
  if (filters.event_name) params.set('event_name', filters.event_name)
  if (filters.weight_class) params.set('weight_class', filters.weight_class)
  if (filters.start_date) params.set('start_date', filters.start_date)
  if (filters.end_date) params.set('end_date', filters.end_date)
  return `/results?${params.toString()}`
}

const SAMPLE_PROMPTS = [
  'How did Jacob Jones from Air Force do this season?',
  "What's Ohio State's record at 133 lbs this year?",
  'Any matches decided by fall at the Clarion Open?',
]

export function ResultsAnalystWidget() {
  const [isOpen, setIsOpen] = useState(false)
  const [input, setInput] = useState('')
  const { messages, sendMessage, clearChat, isLoading } = useResultsAnalystChat()
  const scrollRef = useRef(null)
  const navigate = useNavigate()

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight
    }
  }, [messages, isLoading, isOpen])

  const handleSend = () => {
    if (!input.trim() || isLoading) return
    sendMessage(input)
    setInput('')
  }

  return (
    <>
      <button
        type="button"
        onClick={() => setIsOpen((v) => !v)}
        aria-label={isOpen ? 'Close Results Analyst' : 'Open Results Analyst'}
        className="fixed bottom-20 right-4 z-50 flex h-12 w-12 items-center justify-center rounded-full bg-gold-500 text-mat-950 shadow-glow transition-transform hover:scale-105 active:scale-95 md:bottom-6 md:right-6"
      >
        {isOpen ? <X size={22} /> : <Sparkles size={22} />}
      </button>

      <AnimatePresence>
        {isOpen && (
          <motion.div
            initial={{ opacity: 0, y: 16, scale: 0.97 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 12, scale: 0.97 }}
            transition={{ type: 'spring', damping: 28, stiffness: 380 }}
            className="fixed bottom-36 right-4 z-50 flex h-[32rem] w-[24rem] max-w-[calc(100vw-2rem)] flex-col overflow-hidden rounded-2xl border border-mat-600 bg-mat-850 shadow-card md:bottom-24 md:right-6"
          >
            <div className="flex shrink-0 items-center justify-between border-b border-mat-700 bg-mat-800/60 px-4 py-3">
              <div className="flex items-center gap-2.5">
                <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-gold-500/15 text-gold-400">
                  <Sparkles size={16} />
                </div>
                <div>
                  <p className="font-display text-xs uppercase tracking-wide text-ink-100">Results Analyst</p>
                  <p className="mt-0.5 text-[11px] text-ink-500">Ask about historical match results</p>
                </div>
              </div>
              <button
                type="button"
                onClick={clearChat}
                aria-label="Clear chat"
                className="shrink-0 rounded-lg p-1.5 text-ink-500 hover:bg-mat-700 hover:text-ink-100"
              >
                <Trash2 size={15} />
              </button>
            </div>

            <div ref={scrollRef} className="flex-1 overflow-y-auto px-3.5 py-3">
              {messages.length === 0 && (
                <div className="flex flex-col gap-3 rounded-xl border border-mat-700 bg-mat-900/50 p-3.5">
                  <div className="flex items-center gap-2">
                    <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-gold-500/15 text-gold-400">
                      <Sparkles size={16} />
                    </div>
                    <p className="text-sm text-ink-300">
                      Ask a question about real historical match results — I'll search the database and can send you straight to the full results with your filters applied.
                    </p>
                  </div>
                  <div className="flex flex-wrap gap-1.5 border-t border-mat-700 pt-3">
                    {SAMPLE_PROMPTS.map((p) => (
                      <Button key={p} variant="secondary" size="xs" onClick={() => sendMessage(p)} className="h-auto whitespace-normal py-1.5 text-left leading-snug">
                        {p}
                      </Button>
                    ))}
                  </div>
                </div>
              )}

              <div className="flex flex-col gap-2.5">
                {messages.map((msg) => (
                  <div
                    key={msg.id}
                    className={cn('flex max-w-[90%] flex-col gap-1', msg.role === 'user' ? 'self-end' : 'self-start')}
                  >
                    <div
                      className={cn(
                        'rounded-xl px-3 py-2 text-sm leading-relaxed shadow-sm',
                        msg.role === 'user'
                          ? 'whitespace-pre-wrap bg-gold-500 text-mat-950 font-medium'
                          : msg.isError
                            ? 'border border-blood-500/30 bg-blood-500/12 text-blood-400'
                            : 'border border-mat-700 bg-mat-800 text-ink-100'
                      )}
                    >
                      {msg.role === 'assistant' ? (
                        <div
                          className={cn(
                            '[&_p]:my-0 [&_ul]:my-1 [&_ul]:list-disc [&_ul]:pl-4 [&_li]:my-0.5 [&_strong]:text-ink-50 [&_a]:text-gold-400 [&_a]:underline',
                            '[&_table]:my-2 [&_table]:w-full [&_table]:border-collapse [&_table]:overflow-hidden [&_table]:rounded-lg [&_table]:border [&_table]:border-mat-600',
                            '[&_th]:border-b [&_th]:border-mat-600 [&_th]:bg-mat-900/60 [&_th]:px-2.5 [&_th]:py-1.5 [&_th]:text-left [&_th]:text-[11px] [&_th]:font-bold [&_th]:uppercase [&_th]:tracking-wider [&_th]:text-ink-500',
                            '[&_td]:border-t [&_td]:border-mat-700 [&_td]:px-2.5 [&_td]:py-1.5 [&_td]:text-ink-200',
                            '[&_tr:nth-child(even)_td]:bg-mat-900/30'
                          )}
                        >
                          <ReactMarkdown remarkPlugins={[remarkGfm]}>{msg.content}</ReactMarkdown>
                        </div>
                      ) : (
                        msg.content
                      )}
                    </div>
                    {msg.role === 'assistant' && msg.filters && (
                      <Button
                        variant="primary"
                        size="sm"
                        onClick={() => {
                          navigate(resultsUrl(msg.filters))
                          setIsOpen(false)
                        }}
                        className="w-fit self-start"
                      >
                        <ScrollText size={14} /> View in Results
                      </Button>
                    )}
                  </div>
                ))}
                {isLoading && (
                  <div className="self-start rounded-xl bg-mat-800 px-3 py-2 text-sm text-ink-500">Thinking…</div>
                )}
              </div>
            </div>

            <div className="flex shrink-0 items-center gap-2 border-t border-mat-700 bg-mat-800/40 p-2.5">
              <input
                value={input}
                onChange={(e) => setInput(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') {
                    e.preventDefault()
                    handleSend()
                  }
                }}
                placeholder="Ask about a wrestler, school, or event…"
                disabled={isLoading}
                className="h-10 flex-1 rounded-lg border border-mat-600 bg-mat-900 px-3 text-sm text-ink-100 placeholder:text-ink-600 transition-colors focus:border-gold-500 focus:outline-none focus:ring-2 focus:ring-gold-500/25 disabled:opacity-50"
              />
              <button
                type="button"
                onClick={handleSend}
                disabled={isLoading || !input.trim()}
                aria-label="Send message"
                className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-gold-500 text-mat-950 transition-colors hover:bg-gold-400 disabled:bg-mat-600 disabled:text-ink-500"
              >
                <Send size={16} />
              </button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  )
}
