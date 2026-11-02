import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { api, formatDate, formatUGX } from "../api";
import { useAuth } from "../auth";
import { DashboardMetricGrid } from "../components/DashboardMetricGrid";
import { HomeAnalytics } from "../components/HomeAnalytics";
import { getLastSevenDays, statusCounts } from "../utils/homeAnalytics";

const ACTIVE_STATUSES = new Set([
  "PENDING",
  "ASSIGNED",
  "COLLECTED",
  "IN_TRANSIT",
  "RECEIVED",
]);

function sum(values) {
  return values.reduce((total, value) => total + Number(value || 0), 0);
}

async function getAllPages(path) {
  const firstPage = await api(path);
  if (!Array.isArray(firstPage.results)) return firstPage;

  const pageCount =
    firstPage.pages || Math.ceil(firstPage.count / (firstPage.results.length || 20));
  if (pageCount <= 1) return firstPage;

  const [basePath, query = ""] = path.split("?");
  const params = new URLSearchParams(query);
  const remainingPages = await Promise.all(
    Array.from({ length: pageCount - 1 }, (_, index) => {
      params.set("page", String(index + 2));
      return api(`${basePath}?${params.toString()}`);
    }),
  );
  return {
    ...firstPage,
    results: [
      ...firstPage.results,
      ...remainingPages.flatMap((page) => page.results || []),
    ],
  };
}

function StatusSummary({ requests }) {
  const statuses = [
    "PENDING",
    "ASSIGNED",
    "COLLECTED",
    "IN_TRANSIT",
    "RECEIVED",
    "PROCESSED",
    "REJECTED",
    "CANCELLED",
  ];
  const counts = statuses.map((status) => [
    status,
    requests.filter((request) => request.status === status).length,
  ]);
  const max = Math.max(1, ...counts.map(([, count]) => count));

  return (
    <div className="card">
      <h3>Request status</h3>
      <div className="home-status-list">
        {counts.map(([status, count]) => (
          <div className="home-status-row" key={status}>
            <span className={`status ${status}`}>{status}</span>
            <div
              className="home-status-track"
              role="progressbar"
              aria-label={`${status} requests`}
              aria-valuemin={0}
              aria-valuemax={max}
              aria-valuenow={count}
            >
              <span
                className={`home-status-fill ${status}`}
                style={{ width: `${(count / max) * 100}%` }}
              />
            </div>
            <strong>{count}</strong>
          </div>
        ))}
      </div>
    </div>
  );
}

function RecentRequests({ requests }) {
  const recent = [...requests]
    .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
    .slice(0, 5);

  return (
    <div className="card">
      <div className="page-head">
        <div>
          <h3>Recent activity</h3>
          <p>Latest requests and shipment updates.</p>
        </div>
        <Link className="btn ghost small" to="/requests">
          View all
        </Link>
      </div>
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Reference</th>
              <th>Status</th>
              <th>Items</th>
              <th>Created</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {recent.map((request) => (
              <tr key={request.id}>
                <td><strong>{request.reference}</strong></td>
                <td>
                  <span className={`status ${request.status}`}>
                    {request.status_label}
                  </span>
                </td>
                <td>{request.item_count}</td>
                <td>{formatDate(request.created_at)}</td>
                <td>
                  <Link className="btn ghost small" to={`/requests/${request.id}`}>
                    Open
                  </Link>
                </td>
              </tr>
            ))}
            {!recent.length && (
              <tr>
                <td colSpan={5} className="empty">No requests yet.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

export default function HomeDashboard() {
  const { user } = useAuth();
  const [result, setResult] = useState({ role: null, dashboard: null, error: "" });

  useEffect(() => {
    let active = true;
    let loading = false;

    async function load() {
      if (loading) return;
      loading = true;
      try {
        const requestPath =
          user.role === "COLLECTOR"
            ? "/requests/list/?scope=mine&page_size=100"
            : "/requests/list/?page_size=100";
        const requestsPromise = getAllPages(requestPath);
        let results;

        if (user.role === "CONSUMER") {
          results = await Promise.all([
            requestsPromise,
            getAllPages("/items/"),
            api("/wallet/"),
          ]);
        } else if (user.role === "COLLECTOR") {
          results = await Promise.all([
            requestsPromise,
            getAllPages("/requests/list/?scope=available&page_size=100"),
          ]);
        } else {
          results = await Promise.all([requestsPromise]);
        }

        if (active) setResult({ role: user.role, dashboard: results, error: "" });
      } catch (loadError) {
        if (active) setResult({ role: user.role, dashboard: null, error: loadError.message });
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
  }, [user.role]);

  if (result.role !== user.role) return <div>Loading your home…</div>;
  if (result.error) return <div className="alert error">{result.error}</div>;
  if (!result.dashboard) return <div>Loading your home…</div>;

  const dashboard = result.dashboard;
  const requestData = dashboard[0];
  const requests = requestData.results || [];
  const processed = requests.filter((request) => request.status === "PROCESSED");
  let title;
  let description;
  let metrics;
  let actions;
  let chartStatuses;
  let chartActivity;
  let chartActivityTitle;

  if (user.role === "CONSUMER") {
    const items = dashboard[1].results || dashboard[1];
    const wallet = dashboard[2].wallet || { balance: 0 };
    title = `Welcome${user.full_name ? `, ${user.full_name}` : ""}`;
    description = "Your recycling activity, rewards, and collection progress.";
    metrics = [
      { label: "Total requests", value: requestData.count },
      {
        label: "Active requests",
        value: requests.filter((request) => ACTIVE_STATUSES.has(request.status)).length,
      },
      { label: "Verified disposals", value: processed.length },
      { label: "E-waste logged", value: sum(items.map((item) => item.quantity)), detail: "items" },
      {
        label: "Carbon Dioxide avoided",
        value: `${sum(processed.map((request) => request.carbon_kg)).toFixed(1)} kg`,
      },
      { label: "Wallet balance", value: formatUGX(wallet.balance) },
    ];
    actions = [
      ["/items", "Log e-waste"],
      ["/requests/new", "Request a pickup"],
      ["/wallet", "Open wallet"],
    ];
    chartStatuses = statusCounts(requests);
    chartActivity = getLastSevenDays(items, "created_at", (item) => item.quantity);
    chartActivityTitle = "E-waste logged over the last 7 days";
  } else if (user.role === "COLLECTOR") {
    const available = dashboard[1];
    const inProgress = requests.filter((request) =>
      ["COLLECTED", "IN_TRANSIT"].includes(request.status),
    );
    title = `Collector home${user.full_name ? `, ${user.full_name}` : ""}`;
    description = "Your collection workload and nearby pickup opportunities.";
    metrics = [
      { label: "Assigned requests", value: requestData.count },
      { label: "Ready to collect", value: requests.filter((request) => request.status === "ASSIGNED").length },
      { label: "In progress", value: inProgress.length },
      { label: "Available pickups", value: available.count },
      { label: "Items in assigned requests", value: sum(requests.map((request) => request.item_count)) },
      { label: "Completed collections", value: requests.filter((request) => ["RECEIVED", "PROCESSED"].includes(request.status)).length },
    ];
    actions = [
      ["/tasks", "View my tasks"],
      ["/available", "Browse pickups"],
    ];
    chartStatuses = statusCounts(requests, [
      {
        label: "AVAILABLE",
        value: available.count,
        color: "#8b6bc1",
      },
    ]);
    chartActivity = getLastSevenDays(requests);
    chartActivityTitle = "Assigned requests over the last 7 days";
  } else {
    const byStatus = (status) => requests.filter((request) => request.status === status);
    const received = byStatus("RECEIVED");
    const handled = [...received, ...processed];
    title = `Recycler home${user.full_name ? `, ${user.full_name}` : ""}`;
    description = "Incoming shipments, processing workload, and verified impact.";
    metrics = [
      { label: "Incoming shipments", value: byStatus("IN_TRANSIT").length },
      { label: "Awaiting processing", value: received.length },
      { label: "Processed requests", value: processed.length },
      { label: "Units received", value: sum(handled.map((request) => request.processing?.items_received)) },
      { label: "Units processed", value: sum(processed.map((request) => request.processing?.items_received)) },
      { label: "Carbon Dioxide avoided", value: `${sum(processed.map((request) => request.carbon_kg)).toFixed(1)} kg` },
    ];
    actions = [
      ["/incoming", "Review incoming shipments"],
      ["/requests", "View tracked requests"],
    ];
    chartStatuses = statusCounts(requests);
    chartActivity = getLastSevenDays(
      requests.filter((request) =>
        ["RECEIVED", "PROCESSED"].includes(request.status),
      ),
      "updated_at",
    );
    chartActivityTitle = "Shipments handled over the last 7 days";
  }

  return (
    <div>
      <div className="page-head home-page-head">
        <div>
          <h1>{title}</h1>
          <p>{description}</p>
        </div>
        <div className="actions">
          {actions.map(([to, label]) => (
            <Link className="btn" key={to} to={to}>{label}</Link>
          ))}
        </div>
      </div>
      <DashboardMetricGrid metrics={metrics} />
      <HomeAnalytics
        statusData={chartStatuses}
        activityData={chartActivity}
        activityTitle={chartActivityTitle}
      />
      <div className="grid cols-2 mt home-analytics">
        <StatusSummary requests={requests} />
        <RecentRequests requests={requests} />
      </div>
    </div>
  );
}
