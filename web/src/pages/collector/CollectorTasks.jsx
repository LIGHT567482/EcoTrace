import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { api, formatDate } from "../../api";

export default function CollectorTasks() {
  const [data, setData] = useState({ count: 0, results: [] });
  const [error, setError] = useState("");
  const [search, setSearch] = useState("");

  function load() {
    const query = new URLSearchParams();
    if (search.trim()) query.set("q", search.trim());
    api(`/requests/list/?${query}`)
      .then(setData)
      .catch((e) => setError(e.message));
  }

  useEffect(load, [search]);

  async function act(id, path, body) {
    setError("");
    try {
      await api(`/requests/${id}/${path}`, { method: "POST", body: body || {} });
      load();
    } catch (e) {
      setError(e.message);
    }
  }

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>My collection tasks</h1>
          <p>Assigned pickups and their progress.</p>
        </div>
        <Link className="btn ghost" to="/available">
          Browse available pickups
        </Link>
      </div>
      {error && <div className="alert error">{error}</div>}
      <label className="field" style={{ marginBottom: "1rem" }}>
        Search assigned tasks
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
                  {r.consumer_detail?.full_name || r.consumer_detail?.phone} ·{" "}
                  {r.pickup_address || r.dropoff_point_detail?.name || "-"} ·{" "}
                  {r.item_count} items
                  <br />
                  Created {formatDate(r.created_at)}
                </p>
              </div>
              <div className="actions">
                <Link className="btn ghost small" to={`/requests/${r.id}`}>
                  Open
                </Link>
                {r.status === "ASSIGNED" && (
                  <button
                    className="btn small"
                    onClick={() => act(r.id, "transition", { status: "COLLECTED" })}
                  >
                    Mark collected
                  </button>
                )}
                {r.status === "COLLECTED" && (
                  <button
                    className="btn small"
                    onClick={() => act(r.id, "transition", { status: "IN_TRANSIT" })}
                  >
                    Send to facility
                  </button>
                )}
                {r.status === "ASSIGNED" && (
                  <button className="btn ghost small" onClick={() => act(r.id, "release")}>
                    Release
                  </button>
                )}
              </div>
            </div>
          </div>
        ))}
        {!data.results.length && <div className="empty">No assigned tasks yet.</div>}
      </div>
    </div>
  );
}
