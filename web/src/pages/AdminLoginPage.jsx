import { useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { adminLogin } from "../api";
import { useAuth } from "../auth";

export default function AdminLoginPage() {
  const navigate = useNavigate();
  const { user, setUser } = useAuth();
  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (user?.role === "ADMIN") navigate("/", { replace: true });
  }, [navigate, user]);

  async function submit(event) {
    event.preventDefault();
    setError("");
    setBusy(true);
    try {
      const admin = await adminLogin(phone, password);
      setUser(admin);
      navigate("/", { replace: true });
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="center-page">
      <div className="auth-card">
        <img className="auth-logo" src="/bg.png" alt="EcoTrace logo" />
        <h1>Administrator sign in</h1>
        <p className="muted">Sign in to the protected EcoTrace admin panel.</p>
        {error && <div className="alert error">{error}</div>}
        <form className="form" onSubmit={submit}>
          <label className="field">
            Administrator phone number
            <input
              type="tel"
              autoComplete="username"
              value={phone}
              onChange={(event) => setPhone(event.target.value)}
              placeholder="+2567…"
              required
            />
          </label>
          <label className="field">
            Password
            <input
              type="password"
              autoComplete="current-password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              required
            />
          </label>
          <button className="btn" disabled={busy}>
            {busy ? "Please wait…" : "Sign in as administrator"}
          </button>
        </form>
        <p className="mt" style={{ textAlign: "center" }}>
          <Link to="/login">Regular user sign in</Link>
        </p>
      </div>
    </div>
  );
}
