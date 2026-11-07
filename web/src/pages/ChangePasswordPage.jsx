import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { changePassword } from "../api";

export default function ChangePasswordPage() {
  const navigate = useNavigate();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [note, setNote] = useState("");
  const [form, setForm] = useState({
    old_password: "",
    new_password: "",
    confirm: "",
  });

  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value });

  async function submit(e) {
    e.preventDefault();
    setError("");
    setNote("");
    if (form.new_password !== form.confirm) {
      setError("The new passwords do not match.");
      return;
    }
    setBusy(true);
    try {
      await changePassword(form.old_password, form.new_password);
      setForm({ old_password: "", new_password: "", confirm: "" });
      setNote("Password updated.");
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
    <div>
      <div className="page-head">
        <div>
          <h1>Change password</h1>
          <p className="muted">
            Use a password you do not use anywhere else.
          </p>
        </div>
        <button className="btn ghost" onClick={() => navigate(-1)}>
          Back
        </button>
      </div>
      <div className="card" style={{ maxWidth: 480 }}>
        {error && <div className="alert error">{error}</div>}
        {note && <div className="alert success">{note}</div>}
        <form className="form" onSubmit={submit}>
          <label className="field">
            Current password
            <input
              type="password"
              value={form.old_password}
              onChange={set("old_password")}
              autoComplete="current-password"
              required
            />
          </label>
          <label className="field">
            New password
            <input
              type="password"
              value={form.new_password}
              onChange={set("new_password")}
              autoComplete="new-password"
              minLength={8}
              required
            />
          </label>
          <label className="field">
            Confirm new password
            <input
              type="password"
              value={form.confirm}
              onChange={set("confirm")}
              autoComplete="new-password"
              minLength={8}
              required
            />
          </label>
          <button className="btn" disabled={busy}>
            {busy ? "Please wait…" : "Update password"}
          </button>
        </form>
      </div>
    </div>
  );
}
