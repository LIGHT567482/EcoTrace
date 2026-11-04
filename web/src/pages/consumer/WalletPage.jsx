import { useEffect, useState } from "react";
import { api, formatDate, formatUGX } from "../../api";

export default function WalletPage() {
  const [data, setData] = useState({
    wallet: { balance: 0, points_balance: 0 },
    point_transactions: [],
    policy: { minimum_redemption_points: 1000, ugx_per_point: "1.00" },
  });
  const [form, setForm] = useState({
    redeem_mode: "points",
    points: "",
    amount: "",
    destination: "",
    method: "MOBILE_MONEY",
  });
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  function load() {
    api("/wallet/")
      .then(setData)
      .catch((e) => setError(e.message));
  }

  useEffect(load, []);

  async function redeem(e) {
    e.preventDefault();
    setError("");
    setSuccess("");
    try {
      await api("/wallet/redeem/", {
        method: "POST",
        body: {
          [form.redeem_mode]: Number(form[form.redeem_mode]),
          destination: form.destination,
          method: form.method,
        },
      });
      setSuccess("Redemption requested. The admin will process your payout.");
      setForm({
        ...form,
        points: "",
        amount: "",
      });
      load();
    } catch (err) {
      setError(err.message);
    }
  }

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>Rewards wallet</h1>
          <p>Credited only after disposal is recorded and verified.</p>
        </div>
      </div>
      {error && <div className="alert error">{error}</div>}
      {success && <div className="alert success">{success}</div>}

      <div className="grid cols-2">
        <div className="card">
          <h3>Points balance</h3>
          <div className="stat">{Number(data.wallet.points_balance || 0).toLocaleString()} pts</div>
          <p className="sub">
            Current value: {formatUGX(Number(data.wallet.points_balance || 0) * Number(data.policy.ugx_per_point || 0))}
            <br />
            Minimum redemption: {Number(data.policy.minimum_redemption_points || 0).toLocaleString()} pts
          </p>
          {Number(data.wallet.balance || 0) > 0 && (
            <p className="sub">Existing wallet funds: {formatUGX(data.wallet.balance)}</p>
          )}
          <form className="form" onSubmit={redeem}>
            <label className="field">
              Redeem from
              <select
                value={form.redeem_mode}
                onChange={(e) => setForm({ ...form, redeem_mode: e.target.value })}
              >
                <option value="points">Points balance</option>
                <option value="amount" disabled={Number(data.wallet.balance) <= 0}>
                  Existing UGX balance
                </option>
              </select>
            </label>
            <label className="field">
              {form.redeem_mode === "points" ? "Points to redeem" : "UGX to redeem"}
              <input
                type="number"
                min={form.redeem_mode === "points"
                  ? data.policy.minimum_redemption_points
                  : Number(data.policy.minimum_redemption_points) * Number(data.policy.ugx_per_point)}
                max={form.redeem_mode === "points" ? data.wallet.points_balance : data.wallet.balance}
                step={form.redeem_mode === "points" ? "1" : "0.01"}
                value={form[form.redeem_mode]}
                onChange={(e) => setForm({ ...form, [form.redeem_mode]: e.target.value })}
                required
              />
            </label>
            <label className="field">
              Mobile money / airtime number
              <input
                value={form.destination}
                onChange={(e) => setForm({ ...form, destination: e.target.value })}
                placeholder="+2567…"
                required
              />
            </label>
            <label className="field">
              Method
              <select
                value={form.method}
                onChange={(e) => setForm({ ...form, method: e.target.value })}
              >
                <option value="MOBILE_MONEY">Mobile money</option>
                <option value="AIRTIME">Airtime</option>
              </select>
            </label>
            <button
              className="btn"
              disabled={form.redeem_mode === "points"
                ? Number(data.wallet.points_balance) < Number(data.policy.minimum_redemption_points)
                : Number(data.wallet.balance) < Number(data.policy.minimum_redemption_points) * Number(data.policy.ugx_per_point)}
            >
              Request redemption
            </button>
          </form>
        </div>

        <div className="card">
          <h3>Points history</h3>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>When</th>
                  <th>Activity</th>
                  <th>Points</th>
                  <th>Reason</th>
                </tr>
              </thead>
              <tbody>
                {data.point_transactions.map((t) => (
                  <tr key={t.id}>
                    <td>{formatDate(t.created_at)}</td>
                    <td>
                      <span className={`status ${t.kind === "CREDIT" ? "PROCESSED" : "CANCELLED"}`}>
                        {t.kind === "CREDIT" ? "Earned" : "Redeemed"}
                      </span>
                    </td>
                    <td>{Number(t.points).toLocaleString()} pts</td>
                    <td>
                      {t.reason}
                      {t.request_reference && (
                        <>
                          <br />
                          <small>{t.request_reference}</small>
                        </>
                      )}
                    </td>
                  </tr>
                ))}
                {!data.point_transactions.length && (
                  <tr>
                    <td colSpan={4} className="empty">
                      No transactions yet.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  );
}
