import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { api, formatUGX } from "../../api";
import { ReportPrintHeader, SaveReportPdfButton } from "../../components/ReportPrintTools";

export default function AdminDashboard() {
  const [summary, setSummary] = useState(null);
  const [wallet, setWallet] = useState(null);
  const [error, setError] = useState("");
  const [filters, setFilters] = useState({ from: "", to: "", town: "" });

  useEffect(() => {
    const query = new URLSearchParams();
    Object.entries(filters).forEach(([key, value]) => {
      if (value) query.set(key, value);
    });
    api(`/reports/summary/?${query}`)
      .then((report) => {
        setSummary(report);
        setError("");
      })
      .catch((e) => setError(e.message));
  }, [filters]);

  useEffect(() => {
    api("/wallet/stats/").then(setWallet).catch(() => {});
  }, []);

  if (error) return <div className="alert error">{error}</div>;
  if (!summary) return <div>Loading…</div>;

  const statusRows = Object.entries(summary.by_status || {});

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>System reports</h1>
          <p>Detailed system-wide performance and impact figures.</p>
        </div>
        <div className="actions">
          <SaveReportPdfButton />
          <Link className="btn ghost" to="/users">
            Manage users
          </Link>
          <Link className="btn" to="/redemptions">
            Redemptions
          </Link>
        </div>
      </div>

      <div className="form row no-print" style={{ marginBottom: "1rem" }}>
        <label className="field">
          From
          <input
            type="date"
            value={filters.from}
            onChange={(event) =>
              setFilters((current) => ({ ...current, from: event.target.value }))
            }
          />
        </label>
        <label className="field">
          To
          <input
            type="date"
            value={filters.to}
            onChange={(event) =>
              setFilters((current) => ({ ...current, to: event.target.value }))
            }
          />
        </label>
        <label className="field">
          Town
          <input
            value={filters.town}
            onChange={(event) =>
              setFilters((current) => ({ ...current, town: event.target.value }))
            }
            placeholder="All towns"
          />
        </label>
      </div>

      <section className="print-report">
        <ReportPrintHeader />
        <h1 className="print-document-heading">System reports</h1>
        <div className="grid cols-4">
        <div className="card">
          <h3>Requests</h3>
          <div className="stat">{summary.total_requests}</div>
        </div>
        <div className="card">
          <h3>Items recycled</h3>
          <div className="stat">{summary.recycled_items}</div>
        </div>
        <div className="card">
          <h3>Requests processed</h3>
          <div className="stat">{summary.processed_requests}</div>
        </div>
        <div className="card">
          <h3>Carbon Dioxide avoided</h3>
          <div className="stat">
            {Number(summary.carbon_saved_kg ?? 0).toFixed(1)} kg
          </div>
        </div>
        <div className="card">
          <h3>Reward credits</h3>
          <div className="stat amber">{formatUGX(summary.reward_credits_ugx)}</div>
        </div>
        </div>

        <div className="grid cols-2 mt">
        <div className="card">
          <h3>Requests by status</h3>
          <table>
            <tbody>
              {statusRows.map(([k, v]) => (
                <tr key={k}>
                  <td>
                    <span className={`status ${k}`}>{k}</span>
                  </td>
                  <td className="right">
                    <strong>{v}</strong>
                  </td>
                </tr>
              ))}
              {!statusRows.length && (
                <tr>
                  <td className="empty">No data yet.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>

        <div className="card">
          <h3>Users by role</h3>
          <table>
            <tbody>
              {Object.entries(summary.users_by_role || {}).map(([k, v]) => (
                <tr key={k}>
                  <td>{k}</td>
                  <td className="right">
                    <strong>{v}</strong>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <h3 className="mt">Wallet</h3>
          {wallet && (
            <p className="sub">
              Credited: {formatUGX(wallet.total_credited)} · Paid out:{" "}
              {formatUGX(wallet.total_paid_out)} · Pending redemptions:{" "}
              {wallet.pending_redemptions}
            </p>
          )}
        </div>
        </div>

        <div className="card mt">
        <h3>Volumes by town</h3>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Town</th>
                <th>Requests</th>
                <th>Units</th>
                <th>Carbon Dioxide avoided</th>
              </tr>
            </thead>
            <tbody>
              {(summary.by_town || []).map((t) => (
                <tr key={t.consumer__town || "-"}>
                  <td>{t.consumer__town || "-"}</td>
                  <td>{t.requests}</td>
                  <td>{t.items ?? 0}</td>
                  <td>{Number(t.carbon_kg ?? 0).toFixed(1)} kg</td>
                </tr>
              ))}
              {!(summary.by_town || []).length && (
                <tr>
                  <td className="empty" colSpan={4}>
                    No data yet.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
        </div>

        <div className="card mt">
        <h3>Items by category</h3>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Category</th>
                <th>Item rows</th>
                <th>Units</th>
              </tr>
            </thead>
            <tbody>
              {(summary.categories || []).map((c) => (
                <tr key={c.name}>
                  <td>{c.name}</td>
                  <td>{c.n}</td>
                  <td>{c.qty ?? 0}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        </div>
      </section>
    </div>
  );
}
