/**
 * Mat Savvy API client — speaks to Xano per docs/build/ARCHITECTURE.md §6.
 * All functions return parsed JSON or throw Error(message).
 */
import { useAuthStore } from './store'

export const XANO_AUTH = 'https://xhuf-7flt-jytp.n7d.xano.io/api:47V6PWBN'
export const XANO_APP = 'https://xhuf-7flt-jytp.n7d.xano.io/api:17Ryya5W'
export const XANO_ADMIN = 'https://xhuf-7flt-jytp.n7d.xano.io/api:PBpa1T2y'

async function apiFetch(base, path, options = {}) {
  const token = useAuthStore.getState().token
  const headers = { ...(options.headers || {}) }
  if (token) headers['Authorization'] = `Bearer ${token}`
  if (options.body && typeof options.body === 'string') {
    headers['Content-Type'] = 'application/json'
  }
  const res = await fetch(base + path, { ...options, headers })
  if (res.status === 401) {
    useAuthStore.getState().logout()
    if (!path.startsWith('/auth/')) window.location.href = '/login'
    throw new Error('Unauthorized')
  }
  const data = await res.json().catch(() => ({}))
  if (!res.ok) {
    const err = new Error(data.message || data.error || `Request failed (${res.status})`)
    err.status = res.status
    err.payload = data
    throw err
  }
  return data
}

const get = (base, path) => apiFetch(base, path)
const post = (base, path, body) => apiFetch(base, path, { method: 'POST', body: JSON.stringify(body ?? {}) })
const put = (base, path, body) => apiFetch(base, path, { method: 'PUT', body: JSON.stringify(body ?? {}) })
const patch = (base, path, body) => apiFetch(base, path, { method: 'PATCH', body: JSON.stringify(body ?? {}) })
const del = (base, path, body) => apiFetch(base, path, { method: 'DELETE', body: body ? JSON.stringify(body) : undefined })

/* ── Auth ─────────────────────────────────────────────── */
export const api = {
  signup: (payload) => post(XANO_AUTH, '/auth/signup', payload),
  login: (email, password) => post(XANO_AUTH, '/auth/login', { email, password }),
  me: () => get(XANO_AUTH, '/auth/me'),
  updateMe: (payload) => patch(XANO_AUTH, '/auth/me', payload),

  /* ── Public tournaments ─────────────────────────────── */
  tournaments: (params = {}) => get(XANO_APP, `/tournaments${qs(params)}`),
  tournament: (slugOrId) => get(XANO_APP, `/tournaments/${slugOrId}`),
  myEntry: (tournamentId) => get(XANO_APP, `/tournaments/${tournamentId}/my-entry`),
  bracketView: (tournamentId, weightClassId, entryId, withPercents) =>
    get(XANO_APP, `/tournaments/${tournamentId}/bracket/${weightClassId}${qs({ entry_id: entryId, pick_percentages: withPercents || undefined })}`),
  leaderboard: (tournamentId, params = {}) => get(XANO_APP, `/tournaments/${tournamentId}/leaderboard${qs(params)}`),
  results: (tournamentId, params = {}) => get(XANO_APP, `/tournaments/${tournamentId}/results${qs(params)}`),
  pickPopularity: (tournamentId) => get(XANO_APP, `/tournaments/${tournamentId}/pick-popularity`),
  tournamentGroups: (tournamentId) => get(XANO_APP, `/tournaments/${tournamentId}/groups`),
  group: (groupId) => get(XANO_APP, `/groups/${groupId}`),
  groupLeaderboard: (groupId, params = {}) => get(XANO_APP, `/groups/${groupId}/leaderboard${qs(params)}`),
  userProfile: (userId) => get(XANO_APP, `/users/${userId}/profile`),
  searchResults: (params = {}) => get(XANO_APP, `/results/matches${qs(params)}`),
  resultsFacets: (params = {}) => get(XANO_APP, `/results/facets${qs(params)}`),

  /* ── Player ─────────────────────────────────────────── */
  createEntry: (tournamentId) => post(XANO_APP, `/tournaments/${tournamentId}/entries`),
  entry: (entryId) => get(XANO_APP, `/entries/${entryId}`),
  savePicks: (entryId, picks) => put(XANO_APP, `/entries/${entryId}/picks`, { picks }),
  submitEntry: (entryId) => post(XANO_APP, `/entries/${entryId}/submit`),
  reviewEntry: (entryId) => get(XANO_APP, `/entries/${entryId}/review`),
  compareEntries: (aId, bId) => get(XANO_APP, `/entries/${aId}/compare/${bId}`),

  createPickemEntry: (tournamentId) => post(XANO_APP, `/tournaments/${tournamentId}/pickem`),
  pickemEntry: (entryId) => get(XANO_APP, `/pickem-entries/${entryId}`),
  savePickem: (entryId, payload) => put(XANO_APP, `/pickem-entries/${entryId}`, payload),
  submitPickem: (entryId) => post(XANO_APP, `/pickem-entries/${entryId}/submit`),

  createGroup: (payload) => post(XANO_APP, `/groups`, payload),
  joinGroup: (inviteCode) => post(XANO_APP, `/groups/join`, { invite_code: inviteCode }),
  leaveGroup: (groupId) => post(XANO_APP, `/groups/${groupId}/leave`),
  updateGroup: (groupId, payload) => patch(XANO_APP, `/groups/${groupId}`, payload),
  removeGroupMember: (groupId, userId) => del(XANO_APP, `/groups/${groupId}/members/${userId}`),

  dashboard: () => get(XANO_APP, `/me/dashboard`),
  myAnalytics: () => get(XANO_APP, `/me/analytics`),
  notifications: (params = {}) => get(XANO_APP, `/me/notifications${qs(params)}`),
  markNotificationRead: (id) => post(XANO_APP, `/notifications/${id}/read`),
  markAllNotificationsRead: () => post(XANO_APP, `/notifications/read-all`),

  /* ── Admin ──────────────────────────────────────────── */
  adminTournaments: () => get(XANO_ADMIN, `/admin/tournaments`),
  adminTournament: (id) => get(XANO_ADMIN, `/admin/tournaments/${id}`),
  adminCreateTournament: (payload) => post(XANO_ADMIN, `/admin/tournaments`, payload),
  adminUpdateTournament: (id, payload) => put(XANO_ADMIN, `/admin/tournaments/${id}`, payload),
  adminPublishTournament: (id) => post(XANO_ADMIN, `/admin/tournaments/${id}/publish`),
  adminTournamentStatus: (id, action, reason) => post(XANO_ADMIN, `/admin/tournaments/${id}/status`, { action, reason }),
  adminAddWeight: (tournamentId, payload) => post(XANO_ADMIN, `/admin/tournaments/${tournamentId}/weights`, payload),
  adminUpdateWeight: (weightId, payload) => put(XANO_ADMIN, `/admin/weights/${weightId}`, payload),
  adminSaveCompetitors: (weightId, competitors) => put(XANO_ADMIN, `/admin/weights/${weightId}/competitors`, { competitors }),
  adminGenerateBracket: (weightId, template) => post(XANO_ADMIN, `/admin/weights/${weightId}/generate-bracket`, { template }),
  adminBracketView: (tournamentId, weightClassId) => get(XANO_ADMIN, `/admin/tournaments/${tournamentId}/bracket/${weightClassId}`),
  adminSetResult: (matchId, payload) => put(XANO_ADMIN, `/admin/matches/${matchId}/result`, payload),
  adminClearResult: (matchId, reason) => del(XANO_ADMIN, `/admin/matches/${matchId}/result`, { reason }),
  adminRescore: (tournamentId) => post(XANO_ADMIN, `/admin/tournaments/${tournamentId}/rescore`),
  adminGetScoringConfig: (tournamentId) => get(XANO_ADMIN, `/admin/tournaments/${tournamentId}/scoring-config`),
  adminSaveScoringConfig: (tournamentId, config) => put(XANO_ADMIN, `/admin/tournaments/${tournamentId}/scoring-config`, config),
  adminGetPickemConfig: (tournamentId) => get(XANO_ADMIN, `/admin/tournaments/${tournamentId}/pickem-config`),
  adminSavePickemConfig: (tournamentId, config) => put(XANO_ADMIN, `/admin/tournaments/${tournamentId}/pickem-config`, config),
  adminUploadPdf: (tournamentId, file) => {
    const form = new FormData()
    form.append('pdf_file', file)
    return apiFetch(XANO_ADMIN, `/admin/tournaments/${tournamentId}/upload-pdf`, { method: 'POST', body: form })
  },
  adminGetDocument: (docId) => get(XANO_ADMIN, `/admin/documents/${docId}`),
  adminConfirmDocument: (docId, payload) => post(XANO_ADMIN, `/admin/documents/${docId}/confirm`, payload),
  adminAnalytics: (tournamentId) => get(XANO_ADMIN, `/admin/tournaments/${tournamentId}/analytics`),
  adminAuditLogs: (params = {}) => get(XANO_ADMIN, `/admin/audit-logs${qs(params)}`),
  adminExport: (tournamentId) => get(XANO_ADMIN, `/admin/tournaments/${tournamentId}/export`),

  /* ── Admin ingestion (external results) ─────────────── */
  adminSources: (tournamentId) => get(XANO_ADMIN, `/admin/tournaments/${tournamentId}/sources`),
  adminCreateSource: (tournamentId, payload) => post(XANO_ADMIN, `/admin/tournaments/${tournamentId}/sources`, payload),
  adminUpdateSource: (sourceId, payload) => put(XANO_ADMIN, `/admin/sources/${sourceId}`, payload),
  adminDeleteSource: (sourceId) => del(XANO_ADMIN, `/admin/sources/${sourceId}`),
  adminIngestCandidates: (sourceId, candidates) => post(XANO_ADMIN, `/admin/sources/${sourceId}/ingest`, { candidates }),
  adminCandidates: (tournamentId, params = {}) => get(XANO_ADMIN, `/admin/tournaments/${tournamentId}/candidates${qs(params)}`),
  adminApproveCandidate: (candidateId, override) => post(XANO_ADMIN, `/admin/candidates/${candidateId}/approve`, override ? { override } : {}),
  adminRejectCandidate: (candidateId, reason) => post(XANO_ADMIN, `/admin/candidates/${candidateId}/reject`, { reason }),
  adminBulkApproveCandidates: (tournamentId, candidateIds) => post(XANO_ADMIN, `/admin/tournaments/${tournamentId}/candidates/bulk-approve`, { candidate_ids: candidateIds }),
  adminConflicts: (tournamentId, params = {}) => get(XANO_ADMIN, `/admin/tournaments/${tournamentId}/conflicts${qs(params)}`),

  /* ── Admin AI (Results Analyst) ─────────────────────── */
  resultsAnalystAsk: (message) => post(XANO_ADMIN, `/admin/results-analyst`, { message }),
}

function qs(params) {
  const entries = Object.entries(params).filter(([, v]) => v !== undefined && v !== null && v !== '')
  if (!entries.length) return ''
  return '?' + entries.map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`).join('&')
}
