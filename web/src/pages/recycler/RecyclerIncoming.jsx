import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { api, formatDate } from "../../api";

export default function RecyclerIncoming() {
  const [data, setData] = useState({ count: 0, results: [] });
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [search, setSearch] = useState("");

  function load() {
    const query = new URLSearchParams({ status: "IN_TRANSIT" });
    if (search.trim()) query.set("q", search.trim());
    api(`/requests/list/?${query}`)
      .then(setData)
      .catch((e) => setError(e.message));
  }

  useEffect(load, [search]);

  async function receive(id, itemCount) {
    setError("");
    setSuccess("");
    try {
      const r = await api(`/requests/${id}/receive/`, {
        method: "POST",
        body: { items_received: itemCount, method: "RECYCLING" },
      });
      setSuccess(`${r.reference} recorded as received.`);
      load();
    } catch (e) {
      setError(e.message);
    }
  }

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>Incoming shipments</h1>
          <p>Consignments in transit to your facility - record receipt on arrival.</p>
        </div>
        <Link className="btn ghost" to="/requests">
          All tracked requests
        </Link>
      </div>
      {error && <div className="alert error">{error}</div>}
      {success && <div className="alert success">{success}</div>}
      <label className="field" style={{ marginBottom: "1rem" }}>
        Search shipments
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
                  From {r.consumer_detail?.town || "-"} · {r.item_count} items
                  <br />
                  Collector: {r.collector_name || "-"} · sent {formatDate(r.updated_at)}
                </p>
                <div className="chip-row">
                  {r.items.map((it) => (
                    <span className="chip" key={it.id}>
                      {it.type_name} × {it.quantity}
                    </span>
                  ))}
                </div>
              </div>
              <div className="actions">
                <Link className="btn ghost small" to={`/requests/${r.id}`}>
                  Open
                </Link>
                <button className="btn small" onClick={() => receive(r.id, r.item_count)}>
                  Record receipt
                </button>
              </div>
            </div>
          </div>
        ))}
        {!data.results.length && <div className="empty">No incoming shipments.</div>}
      </div>
    </div>
  );
}
