import { useEffect, useState } from "react";
import { Link, useOutletContext } from "react-router-dom";
import { api, formatDate } from "../api";

export default function NotificationsPage() {
  const { setUnread } = useOutletContext();
  const [data, setData] = useState({ count: 0, results: [] });
  const [error, setError] = useState("");
  const [search, setSearch] = useState("");
  const [expanded, setExpanded] = useState(null);
  const [busy, setBusy] = useState(false);

  function load() {
    api("/auth/notifications/")
      .then(setData)
      .catch((e) => setError(e.message));
  }

  useEffect(load, []);
  const filteredNotifications = data.results.filter((notification) =>
    `${notification.title} ${notification.body}`
      .toLowerCase()
      .includes(search.trim().toLowerCase()),
  );

  async function toggle(notification) {
    if (expanded === notification.id) {
      setExpanded(null);
      return;
    }

    setExpanded(notification.id);
    if (notification.is_read) return;

    setError("");
    try {
      const updated = await api(`/auth/notifications/${notification.id}/read/`, {
        method: "POST",
      });
      setData((current) => ({
        ...current,
        count: Math.max(0, current.count - 1),
        results: current.results.map((item) =>
          item.id === updated.id ? updated : item,
        ),
      }));
      setUnread((count) => Math.max(0, count - 1));
    } catch (e) {
      setError(e.message);
    }
  }

  async function readAll() {
    setError("");
    setBusy(true);
    try {
      await api("/auth/notifications/read-all/", { method: "POST" });
      setUnread(0);
      load();
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  async function remove(notificationId) {
    setError("");
    try {
      await api(`/auth/notifications/${notificationId}/`, { method: "DELETE" });
      const removed = data.results.find((item) => item.id === notificationId);
      if (removed && !removed.is_read) {
        setUnread((count) => Math.max(0, count - 1));
      }
      setData((current) => {
        return {
          count: Math.max(0, current.count - (removed && !removed.is_read ? 1 : 0)),
          results: current.results.filter((item) => item.id !== notificationId),
        };
      });
      if (expanded === notificationId) setExpanded(null);
    } catch (e) {
      setError(e.message);
    }
  }

  async function clearAll() {
    if (!window.confirm("Delete all notifications? This cannot be undone.")) return;
    setError("");
    setBusy(true);
    try {
      await api("/auth/notifications/clear/", { method: "DELETE" });
      setData({ count: 0, results: [] });
      setUnread(0);
      setExpanded(null);
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>Notifications</h1>
          <p>{data.count} unread</p>
        </div>
        <div className="actions">
          <button className="btn ghost" onClick={readAll} disabled={!data.count || busy}>
            Mark all as read
          </button>
          <button className="btn danger" onClick={clearAll} disabled={!data.results.length || busy}>
            Clear all
          </button>
        </div>
      </div>
      {error && <div className="alert error">{error}</div>}
      <label className="field" style={{ marginBottom: "1rem" }}>
        Search notifications
        <input
          type="search"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          placeholder="Title or notification details"
        />
      </label>
      <div className="grid">
        {filteredNotifications.map((n) => (
          <article
            className={`card notification-card${n.is_read ? "" : " unread"}`}
            key={n.id}
          >
            <div className="notification-head">
              <button
                type="button"
                className="notification-title"
                aria-expanded={expanded === n.id}
                onClick={() => toggle(n)}
              >
                <strong>{n.title}</strong>
                <span aria-hidden="true">{expanded === n.id ? "−" : "+"}</span>
              </button>
              <button
                type="button"
                className="btn ghost small"
                aria-label={`Delete notification: ${n.title}`}
                onClick={() => remove(n.id)}
              >
                Delete
              </button>
            </div>
            <small>{formatDate(n.created_at)}</small>
            {expanded === n.id && (
              <div className="notification-details">
                <p>{n.body || "There are no additional details."}</p>
                <div className="actions">
                  {n.request_id && (
                    <Link className="btn small" to={`/requests/${n.request_id}`}>
                      View request details
                    </Link>
                  )}
                  <Link className="btn ghost small" to="/requests">
                    View requests
                  </Link>
                </div>
              </div>
            )}
          </article>
        ))}
        {!filteredNotifications.length && (
          <div className="empty">
            {data.results.length ? "No matching notifications." : "No notifications yet."}
          </div>
        )}
      </div>
    </div>
  );
}
