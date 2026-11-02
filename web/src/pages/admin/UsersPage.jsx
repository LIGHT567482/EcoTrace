import { useEffect, useState } from "react";
import { api, formatDate } from "../../api";

export default function UsersPage() {
  const [data, setData] = useState({ count: 0, results: [] });
  const [error, setError] = useState("");
  const [search, setSearch] = useState("");
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

  useEffect(load, [search]);

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

  async function toggle(id) {
    setError("");
    try {
      await api(`/users/${id}/toggle-active/`, { method: "POST" });
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
            <input
              type="password"
              value={form.password}
              onChange={(e) => setForm({ ...form, password: e.target.value })}
              required
            />
          </label>
          <button className="btn">Create</button>
        </form>
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
                  <button className="btn ghost small" onClick={() => toggle(u.id)}>
                    {u.is_active ? "Disable" : "Enable"}
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
