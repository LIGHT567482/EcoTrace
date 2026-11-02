import { useEffect, useState } from "react";
import { api, formatDate } from "../../api";
import { ReportPrintHeader } from "../../components/ReportPrintTools";

const EMPTY_FILTERS = { q: "", method: "", status: "", from: "", to: "" };

function describeActivity(entry) {
  const { method, path, status_code: statusCode } = entry;
  const failed = statusCode >= 400;
  const descriptions = [
    [/\/auth\/admin\/token\/$/, method === "POST" ? "Tried to sign in as an administrator" : "Opened administrator sign-in"],
    [/\/auth\/token\/$/, method === "POST" ? "Tried to sign in" : "Opened sign-in"],
    [/\/auth\/register\/$/, method === "POST" ? "Created an account" : "Opened registration"],
    [/\/auth\/me\/$/, method === "GET" ? "Viewed account profile" : "Updated account profile"],
    [/\/auth\/change-password\/$/, "Changed account password"],
    [/\/requests\/\d+\/claim\/$/, "Accepted a pickup request"],
    [/\/requests\/\d+\/release\/$/, "Returned a pickup request to the available list"],
    [/\/requests\/\d+\/transition\/$/, "Updated a pickup request's progress"],
    [/\/requests\/\d+\/cancel\/$/, "Cancelled a pickup request"],
    [/\/requests\/\d+\/receive\/$/, "Confirmed a shipment arrived at the facility"],
    [/\/requests\/\d+\/process\/$/, "Recorded recycling of a shipment"],
    [/\/requests\/\d+\/reject\/$/, "Declined a shipment at the facility"],
    [/\/requests\/list\/$/, "Viewed pickup requests"],
    [/\/requests\/\d+\/$/, "Viewed pickup request details"],
    [/\/requests\/$/, "Created a pickup request"],
    [/\/categories(?:\/\d+)?\/$/, method === "GET" ? "Viewed e-waste categories" : method === "POST" ? "Added an e-waste category" : method === "DELETE" ? "Removed an e-waste category" : "Updated an e-waste category"],
    [/\/item-types(?:\/\d+)?\/$/, method === "GET" ? "Viewed e-waste item types" : method === "POST" ? "Added an e-waste item type" : method === "DELETE" ? "Removed an e-waste item type" : "Updated an e-waste item type"],
    [/\/dropoff-points(?:\/\d+)?\/$/, method === "GET" ? "Viewed drop-off locations" : method === "POST" ? "Added a drop-off location" : method === "DELETE" ? "Removed a drop-off location" : "Updated a drop-off location"],
    [/\/items(?:\/\d+)?\/$/, method === "GET" ? "Viewed logged e-waste items" : method === "POST" ? "Logged e-waste items" : method === "DELETE" ? "Removed logged e-waste items" : "Updated logged e-waste items"],
    [/\/users\/\d+\/toggle-active\/$/, "Changed a user's access"],
    [/\/users(?:\/\d+)?\/$/, method === "GET" ? "Viewed user accounts" : method === "POST" ? "Created a user account" : method === "DELETE" ? "Removed a user account" : "Updated a user account"],
    [/\/redemptions\/\d+\/approve\/$/, "Approved a wallet payout"],
    [/\/redemptions\/\d+\/reject\/$/, "Declined a wallet payout"],
    [/\/redemptions(?:\/\d+)?\/$/, method === "GET" ? "Viewed wallet payout requests" : "Updated a wallet payout"],
    [/\/wallet\/redeem\/$/, "Requested a wallet payout"],
    [/\/notifications\/clear\/$/, "Cleared notifications"],
    [/\/notifications\/read-all\/$/, "Marked all notifications as read"],
    [/\/notifications\/\d+\/read\/$/, "Read a notification"],
    [/\/notifications\/\d+\/$/, "Deleted a notification"],
    [/\/notifications\/$/, "Viewed notifications"],
    [/\/reports\/summary\/$/, "Viewed system performance reports"],
    [/\/audit-logs\/$/, "Viewed audit history"],
    [/^\/admin\/login\/$/, "Tried to sign in to Django administration"],
    [/^\/admin\//, method === "GET" ? "Viewed a Django administration page" : "Updated information in Django administration"],
  ];
  const match = descriptions.find(([pattern]) => pattern.test(path));

  if (!match) return failed ? "Tried to use a feature, but it was not completed" : "Used a system feature";
  if (failed) return `${match[1]} but it was not completed`;
  return match[1];
}

function getQuery(filters, page = 1, pageSize = 20) {
  const query = new URLSearchParams({ page, page_size: pageSize });
  Object.entries(filters).forEach(([key, value]) => {
    if (value) query.set(key, value);
  });
  return query;
}

function ActivityTable({ entries, print = false }) {
  const leadingEntries = print ? entries.slice(0, 3) : entries;
  const remainingEntries = print ? entries.slice(3) : [];
  const renderEntry = (entry) => (
    <tr key={entry.id}>
      <td>{formatDate(entry.created_at)}</td>
      <td>{entry.actor_name || entry.actor_phone || "Unauthenticated"}</td>
      <td>{describeActivity(entry)}</td>
      <td>{entry.status_code >= 400 ? "Not completed" : "Completed"}</td>
    </tr>
  );

  return (
    <div className="table-wrap">
      <table>
        <thead>
          <tr>
            <th>Time</th>
            <th>Person</th>
            <th>What happened</th>
            <th>Outcome</th>
          </tr>
        </thead>
        <tbody>
          {leadingEntries.map(renderEntry)}
          {!entries.length && (
            <tr>
              <td className="empty" colSpan={4}>
                No matching activity found.
              </td>
            </tr>
          )}
        </tbody>
        {remainingEntries.length > 0 && (
          <tbody>{remainingEntries.map(renderEntry)}</tbody>
        )}
      </table>
    </div>
  );
}

export default function AuditTrailPage() {
  const [filters, setFilters] = useState(EMPTY_FILTERS);
  const [page, setPage] = useState(1);
  const [data, setData] = useState({ count: 0, next: null, previous: null, results: [] });
  const [printEntries, setPrintEntries] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    let active = true;
    api(`/audit-logs/?${getQuery(filters, page)}`)
      .then((result) => {
        if (active) setData(result);
      })
      .catch((loadError) => {
        if (active) setError(loadError.message);
      });
    return () => {
      active = false;
    };
  }, [filters, page]);

  async function savePdf() {
    setLoading(true);
    setError("");
    try {
      const firstPage = await api(`/audit-logs/?${getQuery(filters, 1, 100)}`);
      const pageCount = Math.ceil(firstPage.count / 100);
      const remainingPages = await Promise.all(
        Array.from({ length: pageCount - 1 }, (_, index) =>
          api(`/audit-logs/?${getQuery(filters, index + 2, 100)}`),
        ),
      );
      setPrintEntries([
        ...firstPage.results,
        ...remainingPages.flatMap((result) => result.results),
      ]);
    } catch (loadError) {
      setError(loadError.message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    if (!printEntries) return undefined;
    const printTimer = window.setTimeout(() => window.print(), 0);
    const clearPrintPreview = () => setPrintEntries(null);
    window.addEventListener("afterprint", clearPrintPreview, { once: true });
    return () => {
      window.clearTimeout(printTimer);
      window.removeEventListener("afterprint", clearPrintPreview);
    };
  }, [printEntries]);

  function updateFilter(key, value) {
    setError("");
    setPage(1);
    setFilters((current) => ({ ...current, [key]: value }));
  }

  return (
    <div>
      <div className="page-head no-print">
        <div>
          <h1>Audit trail</h1>
          <p>API activity and sign-in attempts, with user, endpoint, and result.</p>
        </div>
        <button className="btn" type="button" onClick={savePdf} disabled={loading}>
          {loading ? "Preparing PDF…" : "Save as PDF"}
        </button>
      </div>
      {error && <div className="alert error no-print">{error}</div>}

      <div className="form row no-print" style={{ marginBottom: "1rem" }}>
        <label className="field">
          Search activity
          <input
            type="search"
            value={filters.q}
            onChange={(event) => updateFilter("q", event.target.value)}
            placeholder="User, activity, or endpoint"
          />
        </label>
        <label className="field">
          Method
          <select
            value={filters.method}
            onChange={(event) => updateFilter("method", event.target.value)}
          >
            <option value="">All methods</option>
            <option value="POST">POST</option>
            <option value="PUT">PUT</option>
            <option value="PATCH">PATCH</option>
            <option value="DELETE">DELETE</option>
          </select>
        </label>
        <label className="field">
          Result code
          <input
            type="number"
            min="100"
            max="599"
            value={filters.status}
            onChange={(event) => updateFilter("status", event.target.value)}
          />
        </label>
        <label className="field">
          From
          <input
            type="date"
            value={filters.from}
            onChange={(event) => updateFilter("from", event.target.value)}
          />
        </label>
        <label className="field">
          To
          <input
            type="date"
            value={filters.to}
            onChange={(event) => updateFilter("to", event.target.value)}
          />
        </label>
      </div>

      <div className="no-print">
        <ActivityTable entries={data.results} />
        <div className="actions mt">
          <span className="muted">{data.count} recorded activities</span>
          <button
            className="btn ghost small"
            type="button"
            disabled={!data.previous}
            onClick={() => setPage((current) => current - 1)}
          >
            Previous
          </button>
          <button
            className="btn ghost small"
            type="button"
            disabled={!data.next}
            onClick={() => setPage((current) => current + 1)}
          >
            Next
          </button>
        </div>
      </div>

      {printEntries && (
        <div className="print-report print-only audit-print">
          <ReportPrintHeader />
          <h1 className="print-document-heading">Audit Trail</h1>
          <ActivityTable entries={printEntries} print />
        </div>
      )}
    </div>
  );
}
