import { useEffect, useState } from "react";

export default function CountUp({ value, duration = 1300, delay = 0, suffix = "" }) {
  const [n, setN] = useState(0);

  useEffect(() => {
    let raf = 0;
    const from = performance.now() + delay;
    const tick = (now) => {
      if (now < from) {
        raf = requestAnimationFrame(tick);
        return;
      }
      const p = Math.min(1, (now - from) / duration);
      const eased = 1 - Math.pow(1 - p, 3);
      setN(Math.round(value * eased));
      if (p < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [value, duration, delay]);

  return (
    <>
      {n}
      {suffix}
    </>
  );
}
