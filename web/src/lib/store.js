import { create } from 'zustand'
import { persist } from 'zustand/middleware'

/* ── Auth ─────────────────────────────────────────────── */
export const useAuthStore = create(
  persist(
    (set, get) => ({
      token: null,
      user: null,
      setAuth: (token, user) => set({ token, user }),
      setUser: (user) => set({ user }),
      logout: () => set({ token: null, user: null }),
      isAdmin: () => !!get().user?.is_admin,
    }),
    { name: 'takedown-auth' }
  )
)

/* ── Toasts ───────────────────────────────────────────── */
let toastSeq = 0
export const useToastStore = create((set) => ({
  toasts: [],
  push: (toast) => {
    const id = ++toastSeq
    const t = { id, variant: 'default', duration: 3800, ...toast }
    set((s) => ({ toasts: [...s.toasts.slice(-4), t] }))
    if (t.duration > 0) {
      setTimeout(() => set((s) => ({ toasts: s.toasts.filter((x) => x.id !== id) })), t.duration)
    }
    return id
  },
  dismiss: (id) => set((s) => ({ toasts: s.toasts.filter((x) => x.id !== id) })),
}))

export const toast = {
  success: (title, opts = {}) => useToastStore.getState().push({ title, variant: 'success', ...opts }),
  error: (title, opts = {}) => useToastStore.getState().push({ title, variant: 'error', duration: 5200, ...opts }),
  info: (title, opts = {}) => useToastStore.getState().push({ title, variant: 'info', ...opts }),
}
