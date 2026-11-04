import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { api } from "../api";
import { useAuth } from "../auth";

export default function DropOffsPage() {
  const { user } = useAuth();
  const town = user?.role === "COLLECTOR" ? user.town : "Kansanga";
  const [points, setPoints] = useState([]);
  const [search, setSearch] = useState("");
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [busyPoint, setBusyPoint] = useState(null);

  useEffect(() => {
    api(`/dropoff-points/?town=${encodeURIComponent(town)}`)
      .then((d) =>
        setPoints((d.results || d).filter(
          (point) => String(point.town || "").toLowerCase() === town.toLowerCase(),
        )),
      )
      .catch((e) => setError(e.message));
  }, [town]);

  async function notifyRecyclers(point) {
    setError("");
    setSuccess("");
    setBusyPoint(point.id);
    try {
      const result = await api(`/dropoff-points/${point.id}/capacity-alert/`, {
        method: "POST",
        body: {},
      });
      setSuccess(`${result.notified} recycler${result.notified === 1 ? "" : "s"} notified.`);
    } catch (e) {
      setError(e.message);
    } finally {
      setBusyPoint(null);
    }
  }

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>{town} drop-off points</h1>
          <p>Certified locations where you can hand over e-waste yourself.</p>
        </div>
      </div>
      {error && <div className="alert error">{error}</div>}
      {success && <div className="alert success">{success}</div>}
      <label className="field" style={{ marginBottom: "1rem" }}>
        Search {town} drop-off points
        <input
          type="search"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          placeholder="Name, address, or phone"
        />
      </label>
      <div className="grid cols-2">
        {points
          .filter((point) =>
            [point.name, point.address, point.phone]
              .join(" ")
              .toLowerCase()
              .includes(search.trim().toLowerCase()),
          )
          .map((p) => (
            <div className="card" key={p.id}>
              <h3>{p.town}</h3>
              <strong>{p.name}</strong>
              <p className="sub">
                {p.address}
                <br />
                Hours: {p.opening_hours || "-"}
                <br />
                Phone: {p.phone || "-"}
              </p>
              {p.latitude != null && p.longitude != null && (
                <Link className="btn ghost small" to={`/map?id=${p.id}`}>
                  View on map
                </Link>
              )}
              {user?.role === "COLLECTOR" && (
                <button
                  className="btn small mt"
                  disabled={busyPoint === p.id}
                  onClick={() => notifyRecyclers(p)}
                >
                  {busyPoint === p.id ? "Sending…" : "Notify recyclers: full"}
                </button>
              )}
            </div>
        ))}
        {!points.length && !error && <div className="empty">No drop-off points listed yet.</div>}
        {points.length > 0 &&
          !points.some((point) =>
            [point.name, point.address, point.phone]
              .join(" ")
              .toLowerCase()
              .includes(search.trim().toLowerCase()),
          ) && <div className="empty">No matching {town} drop-off points.</div>}
      </div>
    </div>
  );
}
