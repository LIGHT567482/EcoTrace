import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { api, formatDate } from "../../api";

export default function CollectorAvailable() {
  const [data, setData] = useState({ count: 0, results: [] });
  const [error, setError] = useState("");
  const [search, setSearch] = useState("");

  function load() {
    const query = new URLSearchParams({ scope: "available" });
    if (search.trim()) query.set("q", search.trim());
    api(`/requests/list/?${query}`)
      .then(setData)
      .catch((e) => setError(e.message));
  }

  useEffect(load, [search]);

  async function claim(id) {
    setError("");
    try {
      await api(`/requests/${id}/claim/`, { method: "POST" });
      load();
    } catch (e) {
      setError(e.message);
    }
  }

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>Available pickups</h1>
          <p>Unclaimed requests from consumers in your area.</p>
        </div>
        <Link className="btn ghost" to="/tasks">
          My tasks
        </Link>
      </div>
      {error && <div className="alert error">{error}</div>}
      <label className="field" style={{ marginBottom: "1rem" }}>
        Search available pickups
        <input
          type="search"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          placeholder="Reference, customer, or item"
        />
      </label>
      <div className="grid">
        {data.results.map((r) => (
          <div className="card" key={r.id}>
            <div className="page-head" style={{ marginBottom: "0.5rem" }}>
              <div>
                <strong>{r.reference}</strong>{" "}
                <span className={`status ${r.status}`}>{r.status_label}</span>
                <p className="sub">
                  {r.request_type} · {r.item_count} items
                  <br />
                  {r.pickup_address || r.dropoff_point_detail?.name || "-"}
                  <br />
                  Created {formatDate(r.created_at)}
                </p>
              </div>
              <div className="actions">
                <Link className="btn ghost small" to={`/requests/${r.id}`}>
                  Open
                </Link>
                <button className="btn small" onClick={() => claim(r.id)}>
                  Claim
                </button>
              </div>
            </div>
          </div>
        ))}
        {!data.results.length && <div className="empty">No available pickups right now.</div>}
      </div>
    </div>
  );
}
