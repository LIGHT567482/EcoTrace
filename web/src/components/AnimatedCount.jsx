import { useEffect, useState } from "react";

const COUNT_DURATION = 800;

function parseCount(value) {
  const stringValue = String(value);
  const match = stringValue.match(/^([^0-9-]*)(-?\d[\d,]*(?:\.\d+)?)(.*)$/);
  if (!match) return null;

  const number = Number(match[2].replaceAll(",", ""));
  if (!Number.isFinite(number)) return null;
  return {
    prefix: match[1],
    suffix: match[3],
    number,
    decimals: (match[2].split(".")[1] || "").length,
  };
}

function formatNumber(number, decimals) {
  return number.toLocaleString(undefined, {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  });
}

export function AnimatedCount({ value, order = 0 }) {
  const target = parseCount(value);
  const targetNumber = target?.number;
  const decimals = target?.decimals ?? 0;
  const [animation, setAnimation] = useState({ targetNumber: undefined, value: 0 });
  const displayNumber =
    animation.targetNumber === targetNumber ? animation.value : 0;

  useEffect(() => {
    if (targetNumber === undefined) return undefined;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      const frameId = window.requestAnimationFrame(() => {
        setAnimation({ targetNumber, value: targetNumber });
      });
      return () => window.cancelAnimationFrame(frameId);
    }

    let frameId;
    let timeoutId;
    let startTime;
    let cancelled = false;

    const animate = (timestamp) => {
      if (cancelled) return;
      if (startTime === undefined) startTime = timestamp;
      const progress = Math.min((timestamp - startTime) / COUNT_DURATION, 1);
      const easedProgress = 1 - (1 - progress) ** 3;
      setAnimation({ targetNumber, value: targetNumber * easedProgress });

      if (progress < 1) {
        frameId = window.requestAnimationFrame(animate);
      }
    };

    timeoutId = window.setTimeout(() => {
      frameId = window.requestAnimationFrame(animate);
    }, Math.max(0, order) * COUNT_DURATION);

    return () => {
      cancelled = true;
      window.clearTimeout(timeoutId);
      window.cancelAnimationFrame(frameId);
    };
  }, [order, targetNumber]);

  if (!target) return value;
  return `${target.prefix}${formatNumber(displayNumber, decimals)}${target.suffix}`;
}
