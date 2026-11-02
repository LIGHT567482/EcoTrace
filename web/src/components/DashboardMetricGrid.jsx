import { useState } from "react";
import { Link } from "react-router-dom";
import { AnimatedCount } from "./AnimatedCount";

function getRandomOrder(metricCount) {
  const indexes = Array.from({ length: metricCount }, (_, index) => index);
  for (let index = indexes.length - 1; index > 0; index -= 1) {
    const swapIndex = Math.floor(Math.random() * (index + 1));
    [indexes[index], indexes[swapIndex]] = [indexes[swapIndex], indexes[index]];
  }
  return indexes;
}

export function DashboardMetricGrid({ metrics, columns = 3 }) {
  const [order] = useState(() => getRandomOrder(metrics.length));
  const orderByLabel = new Map(
    metrics.map((metric, index) => [metric.label, order.indexOf(index)]),
  );

  return (
    <div className={`grid cols-${columns}`}>
      {metrics.map((metric) => (
        <div className="card" key={metric.label}>
          <h3>{metric.label}</h3>
          <div className="stat">
            <AnimatedCount
              value={metric.value}
              order={orderByLabel.get(metric.label)}
            />
          </div>
          {metric.detail && <p className="sub">{metric.detail}</p>}
          {metric.status && (
            <span className={`status ${metric.status}`}>
              {metric.status.replaceAll("_", " ")}
            </span>
          )}
          {metric.link && <Link to={metric.link.to}>{metric.link.label}</Link>}
        </div>
      ))}
    </div>
  );
}
