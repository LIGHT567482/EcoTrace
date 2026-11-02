import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { api, formatDate, formatUGX } from "../../api";
import { useAuth } from "../../auth";
import { DashboardMetricGrid } from "../../components/DashboardMetricGrid";
import { HomeAnalytics } from "../../components/HomeAnalytics";
import { getLastSevenDays } from "../../utils/homeAnalytics";

const QUEUE_STATUSES = [
  ["PENDING", "New requests"],
  ["ASSIGNED", "Assigned pickups"],
  ["IN_TRANSIT", "Shipments in transit"],
  ["RECEIVED", "Awaiting processing"],
];

export default function AdminHomeDashboard() {
  const { user } = useAuth();
  const [data, setData] = useState(null);
  const [error, setError] = useState("");

  useEffect(() => {
    let active = true;
    let loading = false;

    async function load() {
      if (loading) return;
      loading = true;
      try {
        const [summary, requests, wallet, redemptions] = await Promise.all([
          api("/reports/summary/"),
          api("/requests/list/?page_size=100"),
          api("/wallet/stats/"),
          api("/redemptions/?page_size=5"),
        ]);
        if (active) {
          setData({
            summary,
            requests: requests.results || [],
            wallet,
            redemptions: redemptions.results || redemptions,
          });
        }
      } catch (loadError) {
        if (active) setError(loadError.message);
      } finally {
        loading = false;
      }
    }

    load();
    const refresh = window.setInterval(load, 60000);
    return () => {
      active = false;
      window.clearInterval(refresh);
    };
  }, []);

  if (error) return <div className="alert error">{error}</div>;
  if (!data) return <div>Loading administrator home…</div>;

  const pendingRedemptions = data.wallet.pending_redemptions || 0;
  const lastName = user?.full_name?.trim().split(/\s+/).at(-1) || "Administrator";
  const pendingPayouts = data.redemptions.filter(
    (redemption) => redemption.status === "PENDING",
  );
  const statusData = Object.entries(data.summary.by_status || {}).map(
    ([status, value]) => ({
      label: status.replaceAll("_", " "),
      value,
    }),
  );
  const recentRequests = data.requests.slice(0, 5);
  const metrics = [
    ...QUEUE_STATUSES.map(([status, label]) => ({
      label,
      value: data.summary.by_status?.[status] || 0,
      status,
    })),
    {
      label: "Pending payouts",
      value: pendingRedemptions,
      link: { to: "/redemptions", label: "Review payout requests" },
    },
  ];

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>Welcome, {lastName}</h1>
          <p>Today’s operational queues and the latest system activity.</p>
        </div>
        <div className="actions">
          <Link className="btn" to="/admin">
            Open full reports
          </Link>
          <Link className="btn ghost" to="/requests">
            Review requests
          </Link>
        </div>
      </div>

      <DashboardMetricGrid metrics={metrics} />

      <HomeAnalytics
        statusData={statusData}
        activityData={getLastSevenDays(data.requests)}
        activityTitle="Collection requests over the last 7 days"
      />

      <div className="grid cols-2 mt">
        <section className="card">
          <div className="page-head">
            <div>
              <h2>Latest requests</h2>
              <p>Most recently updated collection activity.</p>
            </div>
            <Link to="/requests">All requests</Link>
          </div>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Reference</th>
                  <th>Customer</th>
                  <th>Status</th>
                  <th>Created</th>
                </tr>
              </thead>
              <tbody>
                {recentRequests.map((request) => (
                  <tr key={request.id}>
                    <td>
                      <Link to={`/requests/${request.id}`}>{request.reference}</Link>
                    </td>
                    <td>
                      {request.consumer_detail?.full_name ||
                        request.consumer_detail?.phone ||
                        "-"}
                    </td>
                    <td>
                      <span className={`status ${request.status}`}>
                        {request.status?.replaceAll("_", " ")}
                      </span>
                    </td>
                    <td>{formatDate(request.created_at)}</td>
                  </tr>
                ))}
                {!recentRequests.length && (
                  <tr>
                    <td className="empty" colSpan={4}>
                      No requests yet.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </section>

        <section className="card">
          <div className="page-head">
            <div>
              <h2>Payout attention</h2>
              <p>
                {pendingRedemptions
                  ? `${pendingRedemptions} payout${pendingRedemptions === 1 ? "" : "s"} need review.`
                  : "No payouts are waiting for review."}
              </p>
            </div>
            <Link to="/redemptions">Manage payouts</Link>
          </div>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>User</th>
                  <th>Amount</th>
                  <th>Requested</th>
                </tr>
              </thead>
              <tbody>
                {pendingPayouts.map((redemption) => (
                  <tr key={redemption.id}>
                    <td>
                      {redemption.user_detail?.full_name ||
                        redemption.user_detail?.phone ||
                        "-"}
                    </td>
                    <td>{formatUGX(redemption.amount)}</td>
                    <td>{formatDate(redemption.created_at)}</td>
                  </tr>
                ))}
                {!pendingPayouts.length && (
                  <tr>
                    <td className="empty" colSpan={3}>
                      No recent pending payouts.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </div>
  );
}
