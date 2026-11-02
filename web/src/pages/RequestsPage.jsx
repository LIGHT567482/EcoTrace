import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { api, formatDate } from "../api";
import { useAuth } from "../auth";

const STATUSES = [
  "",
  "PENDING",
  "ASSIGNED",
  "COLLECTED",
  "IN_TRANSIT",
  "RECEIVED",
  "PROCESSED",
  "REJECTED",
  "CANCELLED",
];

export default function RequestsPage() {
  const { user } = useAuth();
  const [data, setData] = useState({ count: 0, results: [] });
  const [status, setStatus] = useState("");
  const [search, setSearch] = useState("");
  const [error, setError] = useState("");

  function load() {
    const params = new URLSearchParams();
    if (status) params.set("status", status);
    if (search) params.set("q", search);
    if (user.role === "COLLECTOR") params.set("scope", "mine");
    api(`/requests/list/?${params}`)
      .then(setData)
      .catch((e) => setError(e.message));
  }

  useEffect(load, [status, search]);

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>{user.role === "CONSUMER" ? "My requests" : "Requests"}</h1>
          <p>Track every collection request from logging to verified disposal.</p>
        </div>
        {user.role === "CONSUMER" && (
          <Link className="btn" to="/requests/new">
            New pickup request
          </Link>
        )}
      </div>
      {error && <div className="alert error">{error}</div>}
      <div className="form row" style={{ marginBottom: "1rem" }}>
        <label className="field">
          Status
          <select value={status} onChange={(e) => setStatus(e.target.value)}>
            {STATUSES.map((s) => (
              <option key={s} value={s}>
                {s || "All"}
              </option>
            ))}
          </select>
        </label>
        <label className="field">
          Search requests
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Reference, customer, town, or item"
          />
        </label>
      </div>
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Reference</th>
              <th>Type</th>
              <th>Status</th>
              <th>Items</th>
              <th>Created</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {data.results.map((r) => (
              <tr key={r.id}>
                <td>
                  <strong>{r.reference}</strong>
                  <br />
                  <small>{r.consumer_detail?.full_name || r.consumer_detail?.phone}</small>
                </td>
                <td>{r.request_type}</td>
                <td>
                  <span className={`status ${r.status}`}>{r.status_label}</span>
                </td>
                <td>{r.item_count}</td>
                <td>{formatDate(r.created_at)}</td>
                <td>
                  <Link className="btn ghost small" to={`/requests/${r.id}`}>
                    Open
                  </Link>
                </td>
              </tr>
            ))}
            {!data.results.length && (
              <tr>
                <td colSpan={6} className="empty">
                  No requests found.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
      <p className="muted mt">
        {data.count} request{data.count === 1 ? "" : "s"} total
      </p>
    </div>
  );
}
