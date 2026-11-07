import { useEffect, useState } from "react";
import { Link, NavLink, Outlet, useLocation, useNavigate } from "react-router-dom";
import { api } from "../api";
import { useAuth } from "../auth";

const NAV = {
  CONSUMER: [
    ["/", "Home"],
    ["/items", "Log items"],
    ["/requests/new", "Request pickup"],
    ["/requests", "My requests"],
    ["/wallet", "Wallet"],
    ["/dropoffs", "Drop-off points"],
    ["/map", "Map"],
    ["/notifications", "Notifications"],
    ["/messages", "Messages"],
  ],
  COLLECTOR: [
    ["/", "Home"],
    ["/tasks", "My tasks"],
    ["/available", "Available pickups"],
    ["/dropoffs", "Drop-off points"],
    ["/requests", "Requests"],
    ["/map", "Map"],
    ["/notifications", "Notifications"],
    ["/messages", "Messages"],
  ],
  RECYCLER: [
    ["/", "Home"],
    ["/incoming", "Incoming shipments"],
    ["/requests", "All tracked"],
    ["/map", "Map"],
    ["/notifications", "Notifications"],
    ["/messages", "Messages"],
  ],
  ADMIN: [
    ["/", "Home"],
    ["/admin", "Reports"],
    ["/requests", "Requests"],
    ["/users", "Users"],
    ["/redemptions", "Redemptions"],
    ["/reward-settings", "Rewards policy"],
    ["/categories", "Categories"],
    ["/audit", "Audit trail"],
    ["/dropoffs", "Drop-off points"],
    ["/map", "Map"],
    ["/notifications", "Notifications"],
    ["/messages", "Messages"],
  ],
};

export default function Layout() {
  const { user, logout, loading } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [unread, setUnread] = useState(0);
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => {
    window.scrollTo(0, 0);
  }, [location.pathname]);

  useEffect(() => {
    if (!user) return;
    api("/auth/notifications/?background=1")
      .then((d) => setUnread(d.count))
      .catch(() => {});
    const t = setInterval(() => {
      api("/auth/notifications/?background=1")
        .then((d) => setUnread(d.count))
        .catch(() => {});
    }, 30000);
    return () => clearInterval(t);
  }, [user]);

  if (loading) return <div className="center-page">Loading…</div>;
  if (!user)
    return (
      <div className="public-shell">
        <main className="public-main">
          <Outlet />
        </main>
      </div>
    );

  const links = NAV[user.role] || NAV.CONSUMER;

  return (
    <div className="shell">
      <aside className={`sidebar${menuOpen ? " is-open" : ""}`}>
        <Link to="/" className="brand" aria-label="EcoTrace home">
          <span className="brand-mark">
            <img className="brand-logo" src="/bg.png" alt="EcoTrace logo" />
          </span>
          <small>E-waste collection, tracking & rewards</small>
        </Link>
        <button
          type="button"
          className="menu-toggle app-menu-toggle"
          aria-label={menuOpen ? "Close navigation menu" : "Open navigation menu"}
          aria-expanded={menuOpen}
          aria-controls="app-navigation"
          onClick={() => setMenuOpen((open) => !open)}
        >
          <span className="menu-toggle-icon" aria-hidden="true">
            <span />
            <span />
            <span />
          </span>
        </button>
        <nav id="app-navigation" className={menuOpen ? "is-open" : ""}>
          {links.map(([to, label]) => (
            <NavLink
              key={to}
              to={to}
              end={to === "/" || to === "/requests"}
              onClick={() => setMenuOpen(false)}
            >
              {label}
              {to === "/notifications" && unread > 0 && (
                <span className="badge">{unread}</span>
              )}
            </NavLink>
          ))}
        </nav>
        <div className="sidebar-foot">
          <div className="user-chip">
            <strong>{user.full_name || user.phone}</strong>
            <small>{user.phone}</small>
            <small>
              {user.role} · {user.town}
            </small>
          </div>
          <button
            className="btn ghost"
            onClick={() => navigate("/account/password")}
          >
            Change password
          </button>
          <button
            className="btn danger"
            onClick={() => {
              logout();
              navigate("/login");
            }}
          >
            Sign out
          </button>
        </div>
      </aside>
      <main className="content">
        <Outlet context={{ unread, setUnread }} />
      </main>
    </div>
  );
}
