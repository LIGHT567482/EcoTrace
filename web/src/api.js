const BASE = import.meta.env.VITE_API_URL || "http://localhost:8000/api";

export function getAccess() {
  return localStorage.getItem("ecotrace_access");
}
export function getRefresh() {
  return localStorage.getItem("ecotrace_refresh");
}
export function setTokens({ access, refresh }) {
  if (access) localStorage.setItem("ecotrace_access", access);
  if (refresh) localStorage.setItem("ecotrace_refresh", refresh);
}
export function clearTokens() {
  localStorage.removeItem("ecotrace_access");
  localStorage.removeItem("ecotrace_refresh");
  localStorage.removeItem("ecotrace_user");
}

export function getCachedUser() {
  try {
    return JSON.parse(localStorage.getItem("ecotrace_user"));
  } catch {
    return null;
  }
}
export function cacheUser(user) {
  localStorage.setItem("ecotrace_user", JSON.stringify(user));
}

async function tryRefresh() {
  const refresh = getRefresh();
  if (!refresh) return false;
  const res = await fetch(`${BASE}/auth/token/refresh/`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ refresh }),
  });
  if (!res.ok) return false;
  const data = await res.json();
  setTokens(data);
  return true;
}

export async function api(path, { method = "GET", body, auth = true } = {}) {
  const headers = { "Content-Type": "application/json" };
  if (auth && getAccess()) headers.Authorization = `Bearer ${getAccess()}`;
  let res = await fetch(`${BASE}${path}`, {
    method,
    headers,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  if (res.status === 401 && auth && getRefresh()) {
    if (await tryRefresh()) {
      headers.Authorization = `Bearer ${getAccess()}`;
      res = await fetch(`${BASE}${path}`, {
        method,
        headers,
        body: body !== undefined ? JSON.stringify(body) : undefined,
      });
    } else {
      clearTokens();
    }
  }
  const data = res.status === 204 ? null : await res.json().catch(() => null);
  if (!res.ok) {
    const err = new Error(
      (data && (data.detail || JSON.stringify(data))) || `Request failed (${res.status})`
    );
    err.status = res.status;
    err.data = data;
    throw err;
  }
  return data;
}

export async function login(phone, password) {
  const data = await api("/auth/token/", {
    method: "POST",
    body: { phone, password },
    auth: false,
  });
  setTokens(data);
  cacheUser(data.user);
  return data.user;
}

export async function adminLogin(phone, password) {
  const data = await api("/auth/admin/token/", {
    method: "POST",
    body: { phone, password },
    auth: false,
  });
  if (data.user?.role !== "ADMIN") {
    clearTokens();
    throw new Error("This account is not authorized for administrator access.");
  }
  setTokens(data);
  cacheUser(data.user);
  return data.user;
}

export async function register(payload) {
  const data = await api("/auth/register/", {
    method: "POST",
    body: payload,
    auth: false,
  });
  setTokens(data);
  cacheUser(data.user);
  return data.user;
}

export function logout() {
  clearTokens();
}

export function formatUGX(value) {
  return `UGX ${Number(value || 0).toLocaleString()}`;
}

export function formatDate(value) {
  if (!value) return "-";
  return new Date(value).toLocaleString("en-UG", {
    dateStyle: "medium",
    timeStyle: "short",
  });
}
