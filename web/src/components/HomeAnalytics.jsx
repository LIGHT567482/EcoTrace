import { ACTIVITY_COLORS, STATUS_COLORS } from "../utils/homeAnalytics";

const PIE_RADIUS = 42;
const PIE_CIRCUMFERENCE = 2 * Math.PI * PIE_RADIUS;

function PieChart({ title, data }) {
  const total = data.reduce((sum, item) => sum + item.value, 0);
  let offset = 0;
  const slices = data.filter((item) => item.value > 0);

  return (
    <section className="card home-chart-card">
      <h2>{title}</h2>
      <div className="pie-chart-layout">
        <div className="pie-chart-wrap">
          <svg
            className="pie-chart"
            viewBox="0 0 120 120"
            role="img"
            aria-label={`${title}: ${total} total`}
          >
            <circle
              className="pie-chart-track"
              cx="60"
              cy="60"
              r={PIE_RADIUS}
            />
            {total > 0 &&
              slices.map((slice) => {
                const length = (slice.value / total) * PIE_CIRCUMFERENCE;
                const circle = (
                  <circle
                    className="pie-chart-slice"
                    key={slice.label}
                    cx="60"
                    cy="60"
                    r={PIE_RADIUS}
                    fill="none"
                    stroke={slice.color}
                    strokeDasharray={`${length} ${PIE_CIRCUMFERENCE - length}`}
                    strokeDashoffset={-offset}
                  >
                    <title>
                      {slice.label}: {slice.value}
                    </title>
                  </circle>
                );
                offset += length;
                return circle;
              })}
            <text className="pie-chart-total" x="60" y="58">
              {total}
            </text>
            <text className="pie-chart-caption" x="60" y="72">
              total
            </text>
          </svg>
        </div>
        <ul className="chart-legend">
          {data.map((item) => (
            <li key={item.label}>
              <span className="chart-legend-label">
                <span
                  className="chart-legend-dot"
                  style={{ backgroundColor: item.color }}
                  aria-hidden="true"
                />
                {item.label}
              </span>
              <strong>{item.value}</strong>
            </li>
          ))}
          {!total && <li className="muted">No activity recorded yet.</li>}
        </ul>
      </div>
    </section>
  );
}

function BarChart({ title, data }) {
  const width = 560;
  const height = 190;
  const chartTop = 18;
  const chartBottom = 148;
  const chartHeight = chartBottom - chartTop;
  const max = Math.max(1, ...data.map((item) => item.value));
  const slot = width / Math.max(data.length, 1);
  const barWidth = Math.min(34, slot * 0.55);
  const gridValues = [0, Math.ceil(max / 2), max];

  return (
    <section className="card home-chart-card">
      <h2>{title}</h2>
      <div className="bar-chart-wrap">
        <svg
          className="bar-chart"
          viewBox={`0 0 ${width} ${height}`}
          role="img"
          aria-label={`${title}. ${data.map(({ label, value }) => `${label}: ${value}`).join(", ")}`}
        >
          {gridValues.map((value, index) => {
            const y = chartBottom - (value / max) * chartHeight;
            return (
              <g key={`${value}-${index}`} className="bar-chart-gridline">
                <line x1="30" x2={width} y1={y} y2={y} />
                <text x="24" y={y + 4} textAnchor="end">
                  {value}
                </text>
              </g>
            );
          })}
          {data.map((item, index) => {
            const barHeight = (item.value / max) * chartHeight;
            const x = 30 + index * slot + (slot - barWidth) / 2;
            const y = chartBottom - barHeight;
            return (
              <g key={item.label}>
                <rect
                  className="chart-bar"
                  x={x}
                  y={y}
                  width={barWidth}
                  height={barHeight}
                  rx="5"
                  style={{
                    "--bar-index": index,
                    "--bar-color": item.color || ACTIVITY_COLORS[index % ACTIVITY_COLORS.length],
                  }}
                >
                  <title>
                    {item.label}: {item.value}
                  </title>
                </rect>
                <text
                  className="bar-chart-label"
                  x={x + barWidth / 2}
                  y="169"
                  textAnchor="middle"
                >
                  {item.label}
                </text>
              </g>
            );
          })}
        </svg>
      </div>
    </section>
  );
}

export function HomeAnalytics({ statusData, activityData, activityTitle = "Activity over the last 7 days" }) {
  const pieData = statusData.map((item) => ({
    ...item,
    color: item.color || STATUS_COLORS[item.label] || "#128a52",
  }));
  const activity = activityData.map((item) => ({ ...item, value: Number(item.value) || 0 }));

  return (
    <div className="grid cols-2 mt home-analytics">
      <PieChart
        key={pieData.map((item) => `${item.label}:${item.value}`).join("|")}
        title="Activity breakdown"
        data={pieData}
      />
      <BarChart
        key={activity.map((item) => `${item.label}:${item.value}`).join("|")}
        title={activityTitle}
        data={activity}
      />
    </div>
  );
}
