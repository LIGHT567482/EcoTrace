import { useEffect, useMemo, useState } from "react";
import { useSearchParams } from "react-router-dom";
import { api } from "../api";
import {
  KANSANGA,
  bearingDeg,
  cardinal,
  directionsSteps,
  haversineKm,
} from "../utils/geo";

const GENERAL = "https://www.google.com/maps?q=Kansanga,+Kampala,+Uganda&z=15&output=embed";

export default function MapPage() {
  const [points, setPoints] = useState([]);
  const [error, setError] = useState("");
  const origin = KANSANGA;
  const [params, setParams] = useSearchParams();

  useEffect(() => {
    api("/dropoff-points/?town=Kansanga")
      .then((d) =>
        setPoints((d.results || d).filter(
          (point) => String(point.town || "").toLowerCase() === "kansanga",
        )),
      )
      .catch((e) => setError(e.message));
  }, []);

  const selectedId = params.get("id");
  const selected = useMemo(
    () => points.find((p) => String(p.id) === String(selectedId)) || null,
    [points, selectedId]
  );

  const embedUrl =
    selected && selected.latitude != null && selected.longitude != null
      ? `https://www.google.com/maps?q=${selected.latitude},${selected.longitude}&z=16&output=embed`
      : GENERAL;

  const route = useMemo(() => {
    if (!selected || selected.latitude == null) return null;
    return directionsSteps(origin, {
      lat: selected.latitude,
      lng: selected.longitude,
    });
  }, [origin, selected]);

  const nearest = useMemo(() => {
    const located = points.filter((p) => p.latitude != null);
    if (!located.length) return null;
    return located
      .map((p) => ({
        p,
        km: haversineKm(origin, { lat: p.latitude, lng: p.longitude }),
      }))
      .sort((a, b) => a.km - b.km)[0];
  }, [points, origin]);

  function select(id) {
    setParams(id == null ? {} : { id: String(id) });
  }

  return (
    <div className="map-page">
      <div className="page-head">
        <div>
          <h1>Kansanga map &amp; directions</h1>
          <p>
            Explore Kansanga and its certified drop-off points. The map is
            limited to Kansanga.
          </p>
        </div>
        <div className="actions">
          <button
            className={`btn small ${selected ? "ghost" : ""}`}
            onClick={() => select(null)}
          >
            General view
          </button>
        </div>
      </div>
      {error && <div className="alert error">{error}</div>}
      <div className="map-layout">
        <div className="map-frame card">
          <iframe
            title={selected ? `Map · ${selected.name}` : "EcoTrace map"}
            src={embedUrl}
            loading="lazy"
            referrerPolicy="no-referrer-when-downgrade"
          />
          {route && selected && (
            <div className="directions">
              <div className="directions-head">
                <strong>Directions to {selected.name}</strong>
                <span className="sub">
                  {route.km < 1
                    ? `${Math.round(route.km * 1000)} m`
                    : `${route.km.toFixed(1)} km`}{" "}
                  · head {route.dir} ({Math.round(route.deg)}°)
                </span>
              </div>
              <ol>
                {route.steps.map((s, i) => (
                  <li key={i}>{s}</li>
                ))}
              </ol>
              <p className="sub">
                {selected.address} · {selected.town}
                <br />
                Hours: {selected.opening_hours || "-"} · Phone:{" "}
                {selected.phone || "-"}
              </p>
            </div>
          )}
          {!route && nearest && (
            <div className="directions">
              <div className="directions-head">
                <strong>Nearest drop-off point</strong>
                <span className="sub">
                  {nearest.p.name} ·{" "}
                  {nearest.km < 1
                    ? `${Math.round(nearest.km * 1000)} m`
                    : `${nearest.km.toFixed(1)} km`}{" "}
                  · head{" "}
                  {cardinal(
                    bearingDeg(origin, {
                      lat: nearest.p.latitude,
                      lng: nearest.p.longitude,
                    })
                  )}
                </span>
              </div>
              <p className="sub">
                Select a point on the map or from the list to get full
                directions.
              </p>
            </div>
          )}
        </div>
        <aside className="map-list">
          <div className="card map-list-head">
            <strong>Drop-off points</strong>
            <small className="muted">
              {points.length} certified location{points.length === 1 ? "" : "s"}
            </small>
          </div>
          {points.map((p) => {
            const active = String(p.id) === String(selectedId);
            const km =
              p.latitude != null
                ? haversineKm(origin, { lat: p.latitude, lng: p.longitude })
                : null;
            return (
              <button
                key={p.id}
                className={`map-pin card ${active ? "active" : ""}`}
                onClick={() => select(p.id)}
                disabled={p.latitude == null || p.longitude == null}
              >
                <strong>{p.name}</strong>
                <span className="sub">
                  {p.address} · {p.town}
                  {km != null &&
                    ` · ${km < 1 ? `${Math.round(km * 1000)} m` : `${km.toFixed(1)} km`}`}
                </span>
                <span className="sub">{p.opening_hours || "Hours not listed"}</span>
              </button>
            );
          })}
          {!points.length && !error && (
            <div className="empty">No drop-off points listed yet.</div>
          )}
        </aside>
      </div>
    </div>
  );
}
