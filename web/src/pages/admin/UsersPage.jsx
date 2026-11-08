import { useEffect, useState } from "react";
import { api, formatDate, listPasswordResetRequests } from "../../api";

export default function UsersPage() {
  const [data, setData] = useState({ count: 0, results: [] });
  const [error, setError] = useState("");
  const [search, setSearch] = useState("");
  const [showPw, setShowPw] = useState(false);
  const [resets, setResets] = useState([]);
  const [form, setForm] = useState({
    phone: "",
    password: "",
    full_name: "",
    role: "CONSUMER",
    town: "Kansanga",
  });

  function load() {
    const query = new URLSearchParams();
    if (search.trim()) query.set("q", search.trim());
    api(`/users/?${query}`)
      .then(setData)
      .catch((e) => setError(e.message));
  }

  function loadResets() {
    listPasswordResetRequests()
      .then(setResets)
      .catch(() => {});
  }

  useEffect(load, [search]);
  useEffect(() => {
    loadResets();
    const timer = setInterval(loadResets, 30000);
    return () => clearInterval(timer);
  }, []);

  async function create(e) {
    e.preventDefault();
    setError("");
    try {
      await api("/users/", { method: "POST", body: form });
      setForm({ ...form, phone: "", password: "", full_name: "" });
      load();
    } catch (err) {
      setError(
        err.data && typeof err.data === "object"
          ? Object.values(err.data).flat().join(" ")
          : err.message
      );
    }
  }

  async function toggle(u) {
    if (
      u.is_active &&
      !window.confirm(
        `Disable ${u.full_name || u.phone}? They will not be able to sign in until re-enabled.`
      )
    )
      return;
    setError("");
    try {
      await api(`/users/${u.id}/toggle-active/`, { method: "POST" });
      load();
    } catch (err) {
      setError(err.message);
    }
  }

  async function remove(u) {
    const label = u.full_name || u.phone;
    if (
      !window.confirm(
        `Delete ${label}? Their account and records are removed permanently. This cannot be undone.`
      )
    )
      return;
    setError("");
    try {
      await api(`/users/${u.id}/`, { method: "DELETE" });
      load();
    } catch (err) {
      setError(err.message);
    }
  }

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>Users</h1>
          <p>Create collector, recycler and administrator accounts, and manage access.</p>
        </div>
      </div>
      {error && <div className="alert error">{error}</div>}

      <div className="card" style={{ marginBottom: "1rem" }}>
        <h3>Create user</h3>
        <form className="form row" onSubmit={create}>
          <label className="field">
            Phone
            <input
              value={form.phone}
              onChange={(e) => setForm({ ...form, phone: e.target.value })}
              required
            />
          </label>
          <label className="field">
            Full name
            <input
              value={form.full_name}
              onChange={(e) => setForm({ ...form, full_name: e.target.value })}
            />
          </label>
          <label className="field">
            Role
            <select
              value={form.role}
              onChange={(e) => setForm({ ...form, role: e.target.value })}
            >
              <option value="CONSUMER">Consumer</option>
              <option value="COLLECTOR">Collector</option>
              <option value="RECYCLER">Recycler</option>
              <option value="ADMIN">Administrator</option>
            </select>
          </label>
          <label className="field">
            Town
            <input value={form.town} onChange={(e) => setForm({ ...form, town: e.target.value })} />
          </label>
          <label className="field">
            Password
            <span className="pw-wrap">
              <input
                type={showPw ? "text" : "password"}
                value={form.password}
                onChange={(e) => setForm({ ...form, password: e.target.value })}
                required
              />
              <button
                type="button"
                className="pw-toggle"
                onClick={() => setShowPw((v) => !v)}
                aria-label={showPw ? "Hide password" : "Show password"}
                title={showPw ? "Hide password" : "Show password"}
              >
                <svg
                  width="18"
                  height="18"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  aria-hidden="true"
                >
                  {showPw ? (
                    <>
                      <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24" />
                      <line x1="1" y1="1" x2="23" y2="23" />
                    </>
                  ) : (
                    <>
                      <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
                      <circle cx="12" cy="12" r="3" />
                    </>
                  )}
                </svg>
              </button>
            </span>
          </label>
          <button className="btn">Create</button>
        </form>
      </div>

      <div className="card" style={{ marginBottom: "1rem" }}>
        <h3>Password reset requests</h3>
        <p className="muted">
          Give the code below to the user over a call or in person, then they can
          set a new password on the sign-in screen. Codes expire 15 minutes after
          they are requested.
        </p>
        {resets.length === 0 ? (
          <p className="muted">No pending requests.</p>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>User</th>
                  <th>Phone</th>
                  <th>Code</th>
                  <th>Requested</th>
                  <th>Expires</th>
                </tr>
              </thead>
              <tbody>
                {resets.map((row) => (
                  <tr key={row.id}>
                    <td>{row.user}</td>
                    <td>{row.phone}</td>
                    <td>
                      <strong>{row.code}</strong>
                    </td>
                    <td>{formatDate(row.requested_at)}</td>
                    <td>{formatDate(row.expires_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <label className="field" style={{ marginBottom: "1rem" }}>
        Search users
        <input
          type="search"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          placeholder="Name, phone number, or town"
        />
      </label>

      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Phone</th>
              <th>Role</th>
              <th>Town</th>
              <th>Joined</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {(data.results || []).map((u) => (
              <tr key={u.id}>
                <td>{u.full_name || "-"}</td>
                <td>{u.phone}</td>
                <td>{u.role}</td>
                <td>{u.town}</td>
                <td>{formatDate(u.date_joined)}</td>
                <td>
                  <span className={`status ${u.is_active ? "PROCESSED" : "CANCELLED"}`}>
                    {u.is_active ? "Active" : "Disabled"}
                  </span>
                </td>
                <td>
                  <button className="btn ghost small" onClick={() => toggle(u)}>
                    {u.is_active ? "Disable" : "Enable"}
                  </button>{" "}
                  <button
                    className="btn danger small"
                    onClick={() => remove(u)}
                  >
                    Delete
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
