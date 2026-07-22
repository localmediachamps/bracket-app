import React from 'react'
import { motion } from 'framer-motion'
import { Scale } from 'lucide-react'

/** Shared shell for the Terms of Service and Privacy Policy pages. */
export function LegalLayout({ eyebrow, title, updated, toc, children }) {
  const jump = (key) => (e) => {
    e.preventDefault()
    document.getElementById(key)?.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }

  return (
    <div className="mx-auto max-w-3xl">
      <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.4 }} className="mb-8">
        <span className="mb-3 inline-flex items-center gap-2 rounded-full border border-gold-500/30 bg-gold-500/10 px-3 py-1 text-[10px] font-bold uppercase tracking-[0.16em] text-gold-400">
          <Scale size={12} /> {eyebrow}
        </span>
        <h1 className="font-display text-2xl uppercase tracking-wide text-ink-100 sm:text-3xl">{title}</h1>
        <p className="mt-2 text-xs font-semibold uppercase tracking-wider text-ink-600">Last updated: {updated}</p>
      </motion.div>

      {toc && toc.length > 0 && (
        <nav className="mb-10 rounded-xl border border-mat-700 bg-mat-850 p-5">
          <span className="mb-3 block text-[10px] font-bold uppercase tracking-[0.14em] text-ink-500">On this page</span>
          <ol className="grid gap-1.5 sm:grid-cols-2">
            {toc.map((t, i) => (
              <li key={t.key}>
                <a href={`#${t.key}`} onClick={jump(t.key)} className="text-sm text-ink-400 hover:text-gold-400">
                  {i + 1}. {t.label}
                </a>
              </li>
            ))}
          </ol>
        </nav>
      )}

      <div className="space-y-10">{children}</div>
    </div>
  )
}

export function LegalSection({ id, title, children }) {
  return (
    <section id={id} className="scroll-mt-24 border-b border-mat-800 pb-10 last:border-b-0">
      <h2 className="mb-3 font-display text-base uppercase tracking-wide text-ink-100">{title}</h2>
      <div className="space-y-3 text-sm leading-relaxed text-ink-300 [&_ol]:list-decimal [&_ol]:space-y-1.5 [&_ol]:pl-5 [&_ul]:list-disc [&_ul]:space-y-1.5 [&_ul]:pl-5 [&_strong]:font-bold [&_strong]:text-ink-100">
        {children}
      </div>
    </section>
  )
}
