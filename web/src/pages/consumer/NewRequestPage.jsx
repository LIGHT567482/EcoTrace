import { useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { api } from "../../api";

export default function NewRequestPage() {
  const navigate = useNavigate();
  const [items, setItems] = useState([]);
  const [dropoffs, setDropoffs] = useState([]);
  const [policy, setPolicy] = useState({ pickup_points_percent: 50, dropoff_points_percent: 100 });
  const [selected, setSelected] = useState([]);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [form, setForm] = useState({
    request_type: "PICKUP",
    pickup_address: "",
    dropoff_point: "",
    preferred_date: "",
    consumer_note: "",
  });

  useEffect(() => {
    api("/items/")
      .then((d) => setItems(d.results || d))
      .catch((e) => setError(e.message));
    api("/dropoff-points/")
      .then((d) => {
        const list = d.results || d;
        setDropoffs(list);
        if (list[0]) setForm((f) => ({ ...f, dropoff_point: list[0].id }));
      })
      .catch(() => {});
    api("/wallet/policy/")
      .then(setPolicy)
      .catch(() => {});
  }, []);

  function toggle(id) {
    setSelected((s) => (s.includes(id) ? s.filter((x) => x !== id) : [...s, id]));
  }

  const chosen = items.filter((i) => selected.includes(i.id));
  const reward = chosen.reduce((s, i) => s + Number(i.points || 0), 0);
  const rewardRate = form.request_type === "PICKUP"
    ? policy.pickup_points_percent
    : policy.dropoff_points_percent;
  const pointsEstimate = Math.round(reward * Number(rewardRate || 0) / 100);

  async function submit(e) {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      const body = {
        request_type: form.request_type,
        item_ids: selected,
        pickup_address: form.pickup_address,
        consumer_note: form.consumer_note,
        preferred_date: form.preferred_date || null,
      };
      if (form.request_type === "DROPOFF") body.dropoff_point = Number(form.dropoff_point);
      const created = await api("/requests/", { method: "POST", body });
      navigate(`/requests/${created.id}`);
    } catch (err) {
      setError(
        err.data && typeof err.data === "object"
          ? Object.values(err.data).flat().join(" ")
          : err.message
      );
      setBusy(false);
    }
  }

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>New collection request</h1>
          <p>Pick the logged items you want taken away.</p>
        </div>
        <Link className="btn ghost" to="/items">
          Log more items
        </Link>
      </div>
      {error && <div className="alert error">{error}</div>}

      <form className="form" onSubmit={submit}>
        <div className="card">
          <h3>1 · Choose items</h3>
          <div className="grid" style={{ gap: "0.5rem" }}>
            {items.map((it) => (
              <label
                className="item-row"
                key={it.id}
                style={{ cursor: "pointer" }}
              >
                <span style={{ display: "flex", gap: "0.6rem", alignItems: "center" }}>
                  <input
                    type="checkbox"
                    checked={selected.includes(it.id)}
                    onChange={() => toggle(it.id)}
                  />
                  <span>
                    <strong>{it.type_name}</strong>
                    <br />
                    <small>
                      {it.category_name} · qty {it.quantity}
                    </small>
                  </span>
                </span>
                <span className="right">
                  <small>{Number(it.points).toLocaleString()} base pts</small>
                </span>
              </label>
            ))}
            {!items.length && (
              <div className="empty">
                No items yet - <Link to="/items">log your e-waste first</Link>.
              </div>
            )}
          </div>
        </div>

        <div className="card">
          <h3>2 · How should we collect it?</h3>
          <div className="form row">
            <label className="field">
              Collection type
              <select
                value={form.request_type}
                onChange={(e) => setForm({ ...form, request_type: e.target.value })}
              >
                <option value="PICKUP">Pickup from my address</option>
                <option value="DROPOFF">I will drop it off</option>
              </select>
            </label>
            {form.request_type === "PICKUP" ? (
              <>
                <label className="field">
                  Pickup address
                  <input
                    value={form.pickup_address}
                    onChange={(e) => setForm({ ...form, pickup_address: e.target.value })}
                    placeholder="Plot, street, area"
                  />
                </label>
                <label className="field">
                  Preferred date
                  <input
                    type="date"
                    value={form.preferred_date}
                    onChange={(e) => setForm({ ...form, preferred_date: e.target.value })}
                  />
                </label>
              </>
            ) : (
              <label className="field">
                Drop-off point
                <select
                  value={form.dropoff_point}
                  onChange={(e) => setForm({ ...form, dropoff_point: e.target.value })}
                >
                  {dropoffs.map((d) => (
                    <option key={d.id} value={d.id}>
                      {d.name} - {d.address}
                    </option>
                  ))}
                </select>
              </label>
            )}
            <label className="field">
              Note for the collector
              <input
                value={form.consumer_note}
                onChange={(e) => setForm({ ...form, consumer_note: e.target.value })}
                placeholder="Landmark, gate colour…"
              />
            </label>
          </div>
        </div>

        <div className="card">
          <h3>3 · Summary</h3>
          <p className="sub">
            {chosen.length} item row{chosen.length === 1 ? "" : "s"} selected · about{" "}
            {pointsEstimate.toLocaleString()} points at the current {rewardRate}% rate, credited
            after verified processing.
          </p>
          <button className="btn" disabled={busy || !selected.length}>
            {busy ? "Submitting…" : "Submit request"}
          </button>
        </div>
      </form>
    </div>
  );
}
