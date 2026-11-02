import { useCallback, useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { api, formatDate, formatUGX } from "../api";
import { useAuth } from "../auth";

export default function RequestDetailPage() {
  const { id } = useParams();
  const { user } = useAuth();
  const [req, setReq] = useState(null);
  const [error, setError] = useState("");
  const [note, setNote] = useState("");

  const load = useCallback(() => {
    api(`/requests/${id}/`)
      .then(setReq)
      .catch((e) => setError(e.message));
  }, [id]);

  useEffect(load, [load]);

  async function act(path, body) {
    setError("");
    try {
      await api(`/requests/${id}/${path}`, { method: "POST", body: body || {} });
      load();
    } catch (e) {
      setError(e.message);
    }
  }

  if (!req) return <div>{error ? <div className="alert error">{error}</div> : "Loading…"}</div>;

  const isCollector = user.role === "COLLECTOR";
  const isRecycler = user.role === "RECYCLER" || user.role === "ADMIN";
  const isOwner = req.consumer_detail?.id === user.id;
  const mine = req.collector_name || null;
  const collectorAssigned =
    isCollector && req.collector_name && req.consumer_detail
      ? req.events?.some((e) => e.actor_name && e.status === "ASSIGNED")
      : false;

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>{req.reference}</h1>
          <p>
            {req.request_type} · <span className={`status ${req.status}`}>{req.status_label}</span>{" "}
            · created {formatDate(req.created_at)}
          </p>
        </div>
        <Link className="btn ghost" to="/requests">
          Back to list
        </Link>
      </div>
      {error && <div className="alert error">{error}</div>}

      <div className="grid cols-2">
        <div className="card">
          <h3>Items</h3>
          {req.items.map((it) => (
            <div className="item-row" key={it.id} style={{ marginBottom: "0.5rem" }}>
              <div>
                <strong>{it.type_name}</strong>
                {it.hazardous && (
                  <span className="status REJECTED" style={{ marginLeft: "0.5rem" }}>
                    Hazardous
                  </span>
                )}
                <br />
                <small>
                  {it.category_name} · qty {it.quantity} · {it.condition} · ~
                  {Number(it.carbon_kg ?? 0).toFixed(1)} kg Carbon Dioxide equivalent
                </small>
              </div>
              <div className="right">
                <small>{formatUGX(it.reward_ugx)}</small>
              </div>
            </div>
          ))}
        </div>

        <div className="card">
          <h3>Details</h3>
          <p className="sub">
            Consumer: <strong>{req.consumer_detail?.full_name || req.consumer_detail?.phone}</strong>
            <br />
            Collector: {req.collector_name || "unassigned"}
            <br />
            {req.request_type === "PICKUP"
              ? `Pickup address: ${req.pickup_address || "-"}`
              : `Drop-off point: ${req.dropoff_point_detail?.name || "-"}`}
            <br />
            Preferred date: {req.preferred_date || "-"}
            <br />
            Estimated Carbon Dioxide avoided:{" "}
            <strong>~{Number(req.carbon_kg ?? 0).toFixed(1)} kg</strong>
            {Number(req.hazardous_count ?? 0) > 0 && (
              <>
                <br />
                Hazardous units: <strong>{req.hazardous_count}</strong> (specialised
                handling)
              </>
            )}
            <br />
            {req.consumer_note && <>Note: {req.consumer_note}</>}
          </p>
          {req.reward_credited && (
            <div className="alert success">Reward credited to the consumer wallet.</div>
          )}
          {req.certificate && (
            <div className="alert success">
              Certificate <strong>{req.certificate.code}</strong> ·{" "}
              {req.certificate.summary}
              {Number(req.certificate.carbon_kg ?? 0) > 0 && (
                <> · ~{Number(req.certificate.carbon_kg).toFixed(1)} kg Carbon Dioxide equivalent avoided</>
              )}
            </div>
          )}
          {req.processing && (
            <p className="sub">
              Processing: {req.processing.method} · received {req.processing.items_received}/
              {req.processing.items_expected} items at {formatDate(req.processing.processed_at)}
            </p>
          )}
        </div>
      </div>

      <div className="card mt">
        <h3>Status timeline</h3>
        <ul className="timeline">
          {req.events.map((e) => (
            <li key={e.id}>
              <strong>{e.status_label || e.status}</strong>
              {e.note && <> - {e.note}</>}
              <small>
                {formatDate(e.created_at)}
                {e.actor_name ? ` · ${e.actor_name}` : ""}
              </small>
            </li>
          ))}
        </ul>
      </div>

      <div className="card mt">
        <h3>Actions</h3>
        <div className="actions">
          {isOwner && ["PENDING", "ASSIGNED"].includes(req.status) && (
            <button className="btn danger" onClick={() => act("cancel")}>
              Cancel request
            </button>
          )}
          {isCollector && req.status === "PENDING" && (
            <button className="btn" onClick={() => act("claim")}>
              Claim pickup
            </button>
          )}
          {isCollector &&
            ["ASSIGNED", "COLLECTED"].includes(req.status) &&
            req.events?.some(
              (e) => e.status === "ASSIGNED" && e.actor_name === (user.full_name || user.phone)
            ) && (
              <>
                {req.status === "ASSIGNED" && (
                  <>
                    <button className="btn" onClick={() => act("transition", { status: "COLLECTED", note })}>
                      Mark collected
                    </button>
                    <button className="btn ghost" onClick={() => act("release")}>
                      Release
                    </button>
                  </>
                )}
                {req.status === "COLLECTED" && (
                  <button className="btn" onClick={() => act("transition", { status: "IN_TRANSIT", note })}>
                    Send to facility
                  </button>
                )}
              </>
            )}
          {isRecycler && req.status === "IN_TRANSIT" && (
            <button
              className="btn"
              onClick={() =>
                act("receive", {
                  items_received: req.item_count,
                  method: "RECYCLING",
                  notes: note,
                })
              }
            >
              Record receipt
            </button>
          )}
          {isRecycler && req.status === "RECEIVED" && (
            <>
              <button className="btn" onClick={() => act("process", { method: "RECYCLING", notes: note })}>
                Verify disposal & credit reward
              </button>
              <button
                className="btn danger"
                onClick={() => act("reject", { reason: note || "Rejected at facility" })}
              >
                Reject
              </button>
            </>
          )}
        </div>
        {(isCollector || isRecycler) && (
          <label className="field mt">
            Note / reason (optional)
            <input value={note} onChange={(e) => setNote(e.target.value)} />
          </label>
        )}
        {!isOwner && !isCollector && !isRecycler && (
          <p className="muted">No actions available for your role.</p>
        )}
      </div>
    </div>
  );
}
