const XANO_AUTH    = 'https://xhuf-7flt-jytp.n7d.xano.io/api:47V6PWBN';
const XANO_BRACKET = 'https://xhuf-7flt-jytp.n7d.xano.io/api:17Ryya5W';
const XANO_ADMIN   = 'https://xhuf-7flt-jytp.n7d.xano.io/api:PBpa1T2y';

async function apiFetch(base, path, options = {}) {
  const token = localStorage.getItem('bracket_token');
  const headers = { ...(options.headers || {}) };
  if (token) headers['Authorization'] = 'Bearer ' + token;
  if (options.body && typeof options.body === 'string') {
    headers['Content-Type'] = 'application/json';
  }
  const res = await fetch(base + path, { ...options, headers });
  if (res.status === 401) {
    localStorage.removeItem('bracket_token');
    localStorage.removeItem('bracket_user');
    window.location.href = '/login.html';
    throw new Error('Unauthorized');
  }
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(data.message || data.error || `HTTP ${res.status}`);
  }
  return data;
}

// ── Auth ──────────────────────────────────────────────────────────────────────
async function apiLogin(email, password) {
  return apiFetch(XANO_AUTH, '/auth/login', { method: 'POST', body: JSON.stringify({ email, password }) });
}
async function apiSignup(name, email, password) {
  return apiFetch(XANO_AUTH, '/auth/signup', { method: 'POST', body: JSON.stringify({ name, email, password }) });
}
async function apiMe() {
  return apiFetch(XANO_AUTH, '/auth/me');
}

// ── Brackets ──────────────────────────────────────────────────────────────────
async function apiGetTournaments() {
  return apiFetch(XANO_BRACKET, '/brackets/tournaments');
}
async function apiGetTournament(id) {
  return apiFetch(XANO_BRACKET, `/brackets/tournament/${id}`);
}
async function apiGetWeightBracket(tournId, weight) {
  return apiFetch(XANO_BRACKET, `/brackets/tournament/${tournId}/weight/${weight}`);
}
async function apiGetMyBracket(tournId) {
  return apiFetch(XANO_BRACKET, `/brackets/tournament/${tournId}/my-bracket`);
}
async function apiMakePick(userBracketId, matchId, wrestlerId) {
  return apiFetch(XANO_BRACKET, '/brackets/pick', {
    method: 'POST',
    body: JSON.stringify({ user_bracket_id: userBracketId, bracket_match_id: matchId, picked_wrestler_id: wrestlerId }),
  });
}
async function apiGetLeaderboard(tournId, page = 1, per = 25) {
  return apiFetch(XANO_BRACKET, `/brackets/tournament/${tournId}/leaderboard?page=${page}&per=${per}`);
}
async function apiGetResults(tournId) {
  return apiFetch(XANO_BRACKET, `/brackets/tournament/${tournId}/results`);
}

// ── Admin ─────────────────────────────────────────────────────────────────────
async function apiCreateTournament(name, year, locksAt) {
  return apiFetch(XANO_ADMIN, '/admin/tournament', {
    method: 'POST',
    body: JSON.stringify({ name, year, locks_at: locksAt }),
  });
}
async function apiUpdateTournament(id, data) {
  return apiFetch(XANO_ADMIN, `/admin/tournament/${id}`, { method: 'PUT', body: JSON.stringify(data) });
}
async function apiPublishTournament(id) {
  return apiFetch(XANO_ADMIN, `/admin/tournament/${id}/publish`, { method: 'POST', body: '{}' });
}
async function apiLockTournament(id) {
  return apiFetch(XANO_ADMIN, `/admin/tournament/${id}/lock`, { method: 'POST', body: '{}' });
}
async function apiScoreTournament(id) {
  return apiFetch(XANO_ADMIN, `/admin/tournament/${id}/score`, { method: 'POST', body: '{}' });
}
async function apiGetWrestlers(weightClassId) {
  return apiFetch(XANO_ADMIN, `/admin/weight/${weightClassId}/wrestlers`);
}
async function apiSaveWrestlers(weightClassId, wrestlers) {
  return apiFetch(XANO_ADMIN, `/admin/weight/${weightClassId}/wrestlers`, {
    method: 'PUT',
    body: JSON.stringify({ wrestlers }),
  });
}
async function apiInitializeBracket(weightClassId) {
  return apiFetch(XANO_ADMIN, `/admin/weight/${weightClassId}/initialize-bracket`, { method: 'POST', body: '{}' });
}
async function apiSetMatchResult(matchId, winnerId, decision, score = '') {
  return apiFetch(XANO_ADMIN, `/admin/match/${matchId}/result`, {
    method: 'PUT',
    body: JSON.stringify({ winner_wrestler_id: winnerId, decision, score }),
  });
}
async function apiUploadTournamentPdf(tournamentId, pdfFile) {
  const formData = new FormData();
  formData.append('pdf_file', pdfFile);
  return apiFetch(XANO_ADMIN, `/admin/tournament/${tournamentId}/upload-pdf`, {
    method: 'POST',
    body: formData,
  });
}
async function apiGetWeightClasses(tournId) {
  const data = await apiGetTournament(tournId);
  return data.weight_classes || [];
}
async function apiGetMatches(weightClassId) {
  // Fetched via brackets_weight_GET using weight class data embedded — use admin wrestlers endpoint for now
  // We grab matches for a weight class through the bracket view endpoint
  // This function is a helper used in admin — we'll use the bracket weight endpoint
  return [];
}
