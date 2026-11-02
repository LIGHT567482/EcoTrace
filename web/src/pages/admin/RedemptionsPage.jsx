import { useEffect, useState } from "react";
import { api, formatDate, formatUGX } from "../../api";

export default function RedemptionsPage() {
  const [data, setData] = useState([]);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("");

  function load() {
    const query = new URLSearchParams();
    if (search.trim()) query.set("q", search.trim());
    if (statusFilter) query.set("status", statusFilter);
    api(`/redemptions/?${query}`)
      .then((d) => setData(d.results || d))
      .catch((e) => setError(e.message));
  }

  useEffect(load, [search, statusFilter]);

  async function decide(id, action, reason) {
    setError("");
    setSuccess("");
    try {
      await api(`/redemptions/${id}/${action}/`, {
        method: "POST",
        body: reason ? { reason } : {},
      });
      setSuccess(`Redemption ${action}d.`);
      load();
    } catch (e) {
      setError(e.message);
    }
  }

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>Redemptions</h1>
          <p>Approve payouts or reject and refund them to the wallet.</p>
        </div>
      </div>
      {error && <div className="alert error">{error}</div>}
      {success && <div className="alert success">{success}</div>}
      <div className="form row" style={{ marginBottom: "1rem" }}>
        <label className="field">
          Search payouts
          <input
            type="search"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Name, phone, destination, or method"
          />
        </label>
        <label className="field">
          Status
          <select value={statusFilter} onChange={(event) => setStatusFilter(event.target.value)}>
            <option value="">All statuses</option>
            <option value="PENDING">Pending</option>
            <option value="PAID">Paid</option>
            <option value="REJECTED">Rejected</option>
          </select>
        </label>
      </div>
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>User</th>
              <th>Amount</th>
              <th>Method</th>
              <th>Destination</th>
              <th>Status</th>
              <th>Requested</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {data.map((r) => (
              <tr key={r.id}>
                <td>
                  {r.user_detail?.full_name || r.user_detail?.phone}
                </td>
                <td>{formatUGX(r.amount)}</td>
                <td>{r.method}</td>
                <td>{r.destination}</td>
                <td>
                  <span
                    className={`status ${
                      r.status === "PAID"
                        ? "PROCESSED"
                        : r.status === "REJECTED"
                        ? "CANCELLED"
                        : "PENDING"
                    }`}
                  >
                    {r.status}
                  </span>
                </td>
                <td>{formatDate(r.created_at)}</td>
                <td>
                  {r.status === "PENDING" && (
                    <div className="actions">
                      <button
                        className="btn small"
                        onClick={() => decide(r.id, "approve")}
                      >
                        Mark paid
                      </button>
                      <button
                        className="btn danger small"
                        onClick={() => decide(r.id, "reject", "Payout could not be made")}
                      >
                        Reject
                      </button>
                    </div>
                  )}
                </td>
              </tr>
            ))}
            {!data.length && (
              <tr>
                <td colSpan={7} className="empty">
                  No redemption requests.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
