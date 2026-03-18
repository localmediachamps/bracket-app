function getToken() { return localStorage.getItem('bracket_token'); }
function setToken(t) { localStorage.setItem('bracket_token', t); }
function clearToken() { localStorage.removeItem('bracket_token'); }

function getUser() {
  try { return JSON.parse(localStorage.getItem('bracket_user')); } catch { return null; }
}
function setUser(u) { localStorage.setItem('bracket_user', JSON.stringify(u)); }
function clearUser() { localStorage.removeItem('bracket_user'); }

function requireAuth() {
  if (!getToken()) { window.location.href = '/login.html'; throw new Error('not authenticated'); }
}
function requireAdmin() {
  const u = getUser();
  if (!u || !u.is_admin) { window.location.href = '/tournaments.html'; throw new Error('not admin'); }
}
function logout() {
  clearToken();
  clearUser();
  window.location.href = '/login.html';
}
