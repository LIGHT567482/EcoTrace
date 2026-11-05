import { useState } from "react";
import { Link, useLocation, useNavigate } from "react-router-dom";
import { login, register } from "../api";
import { useAuth } from "../auth";

export default function AuthPage() {
  const isRegister = useLocation().pathname === "/register";
  const navigate = useNavigate();
  const { setUser } = useAuth();
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [form, setForm] = useState({
    phone: "",
    password: "",
    full_name: "",
    town: "Kansanga",
    address: "",
  });

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
      navigate("/");
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
            onClick={() => navigate("/login")}
          >
            Sign in
          </button>
          <button
            type="button"
            className={isRegister ? "active" : ""}
            onClick={() => navigate("/register")}
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
            <input
              type="password"
              value={form.password}
              onChange={set("password")}
              required
            />
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
        <p className="mt" style={{ textAlign: "center" }}>
          <Link to="/">Back to home</Link>
        </p>
      </div>
    </div>
  );
}
