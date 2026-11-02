import { useEffect, useState } from "react";
import { api, formatDate, formatUGX } from "../../api";

export default function WalletPage() {
  const [data, setData] = useState({ wallet: { balance: 0 }, transactions: [] });
  const [form, setForm] = useState({ amount: "", destination: "", method: "MOBILE_MONEY" });
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
          amount: Number(form.amount),
          destination: form.destination,
          method: form.method,
        },
      });
      setSuccess("Redemption requested - the admin will process your payout.");
      setForm({ amount: "", destination: form.destination, method: form.method });
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
          <h3>Balance</h3>
          <div className="stat">{formatUGX(data.wallet.balance)}</div>
          <p className="sub">Redeem via mobile money or airtime.</p>
          <form className="form" onSubmit={redeem}>
            <label className="field">
              Amount (UGX)
              <input
                type="number"
                min="1000"
                value={form.amount}
                onChange={(e) => setForm({ ...form, amount: e.target.value })}
                required
              />
            </label>
            <label className="field">
              Payout number
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
            <button className="btn">Request redemption</button>
          </form>
        </div>

        <div className="card">
          <h3>Transactions</h3>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>When</th>
                  <th>Type</th>
                  <th>Amount</th>
                  <th>Reason</th>
                </tr>
              </thead>
              <tbody>
                {data.transactions.map((t) => (
                  <tr key={t.id}>
                    <td>{formatDate(t.created_at)}</td>
                    <td>
                      <span className={`status ${t.kind === "CREDIT" ? "PROCESSED" : "CANCELLED"}`}>
                        {t.kind}
                      </span>
                    </td>
                    <td>{formatUGX(t.amount)}</td>
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
                {!data.transactions.length && (
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
