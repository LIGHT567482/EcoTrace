import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { api } from "../api";

export default function DropOffsPage() {
  const [points, setPoints] = useState([]);
  const [search, setSearch] = useState("");
  const [error, setError] = useState("");

  useEffect(() => {
    api("/dropoff-points/?town=Kansanga")
      .then((d) =>
        setPoints((d.results || d).filter(
          (point) => String(point.town || "").toLowerCase() === "kansanga",
        )),
      )
      .catch((e) => setError(e.message));
  }, []);

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>Kansanga drop-off points</h1>
          <p>Certified locations in Kansanga where you can hand over e-waste yourself.</p>
        </div>
      </div>
      {error && <div className="alert error">{error}</div>}
      <label className="field" style={{ marginBottom: "1rem" }}>
        Search Kansanga drop-off points
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
            </div>
        ))}
        {!points.length && !error && <div className="empty">No drop-off points listed yet.</div>}
        {points.length > 0 &&
          !points.some((point) =>
            [point.name, point.address, point.phone]
              .join(" ")
              .toLowerCase()
              .includes(search.trim().toLowerCase()),
          ) && <div className="empty">No matching Kansanga drop-off points.</div>}
      </div>
    </div>
  );
}
