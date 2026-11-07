import { useState } from "react";
import { Navigate, useLocation, useNavigate } from "react-router-dom";
import { login, register } from "../api";
import { useAuth } from "../auth";

export default function AuthPage() {
  const location = useLocation();
  const isRegister = location.pathname === "/register";
  const from = location.state?.from;
  const navigate = useNavigate();
  const { setUser, user, loading } = useAuth();
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [showPw, setShowPw] = useState(false);
  const [form, setForm] = useState({
    phone: "",
    password: "",
    full_name: "",
    town: "Kansanga",
    address: "",
  });

  if (loading) return <div className="center-page">Loading…</div>;
  if (user) return <Navigate to="/" replace />;

  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value });

  async function submit(e) {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      const user = isRegister
        ? await register(form)
        : await login(form.phone, form.password);
      setUser(user);
      navigate(
        from ? { pathname: from.pathname, search: from.search } : "/",
        { replace: true }
      );
    } catch (err) {
      if (err.data && typeof err.data === "object" && !err.data.detail) {
        const msgs = Object.entries(err.data)
          .map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(", ") : v}`)
          .join(" · ");
        setError(msgs || err.message);
      } else {
        setError(err.message);
      }
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="center-page">
      <div className="auth-card">
        <img className="auth-logo" src="/bg.png" alt="EcoTrace logo" />
        <p className="muted">
          {isRegister ? "Create your account" : "Sign in to continue"}
        </p>
        {error && <div className="alert error">{error}</div>}
        <div className="tabs">
          <button
            type="button"
            className={!isRegister ? "active" : ""}
            onClick={() => navigate("/login", { state: location.state })}
          >
            Sign in
          </button>
          <button
            type="button"
            className={isRegister ? "active" : ""}
            onClick={() => navigate("/register", { state: location.state })}
          >
            Register
          </button>
        </div>
        <form className="form" onSubmit={submit}>
          <label className="field">
            Phone number
            <input
              value={form.phone}
              onChange={set("phone")}
              placeholder="+2567…"
              required
            />
          </label>
          <label className="field">
            Password
            <span className="pw-wrap">
              <input
                type={showPw ? "text" : "password"}
                value={form.password}
                onChange={set("password")}
                required
              />
              <button
                type="button"
                className="pw-toggle"
                onClick={() => setShowPw((v) => !v)}
                aria-label={showPw ? "Hide password" : "Show password"}
                title={showPw ? "Hide password" : "Show password"}
              >
                <svg
                  width="18"
                  height="18"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  aria-hidden="true"
                >
                  {showPw ? (
                    <>
                      <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24" />
                      <line x1="1" y1="1" x2="23" y2="23" />
                    </>
                  ) : (
                    <>
                      <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
                      <circle cx="12" cy="12" r="3" />
                    </>
                  )}
                </svg>
              </button>
            </span>
          </label>
          {isRegister && (
            <>
              <label className="field">
                Full name
                <input value={form.full_name} onChange={set("full_name")} />
              </label>
              <label className="field">
                Town / area
                <input value={form.town} onChange={set("town")} />
              </label>
              <label className="field">
                Address (for pickups)
                <input value={form.address} onChange={set("address")} />
              </label>
            </>
          )}
          <button className="btn" disabled={busy}>
            {busy ? "Please wait…" : isRegister ? "Create account" : "Sign in"}
          </button>
        </form>
      </div>
    </div>
  );
}
