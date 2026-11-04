import { useEffect, useState } from "react";
import { api } from "../../api";

const DEFAULT_POLICY = {
  minimum_redemption_points: 1000,
  ugx_per_point: "1.00",
  pickup_points_percent: 50,
  dropoff_points_percent: 100,
};

export default function RewardPolicyPage() {
  const [policy, setPolicy] = useState(DEFAULT_POLICY);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    api("/wallet/policy/")
      .then(setPolicy)
      .catch((e) => setError(e.message));
  }, []);

  async function save(event) {
    event.preventDefault();
    setError("");
    setSuccess("");
    setBusy(true);
    try {
      const saved = await api("/wallet/policy/", {
        method: "PATCH",
        body: {
          minimum_redemption_points: Number(policy.minimum_redemption_points),
          ugx_per_point: Number(policy.ugx_per_point),
          pickup_points_percent: Number(policy.pickup_points_percent),
          dropoff_points_percent: Number(policy.dropoff_points_percent),
        },
      });
      setPolicy(saved);
      setSuccess("Reward policy saved.");
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  function update(field, value) {
    setPolicy((current) => ({ ...current, [field]: value }));
  }

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>Rewards policy</h1>
          <p>Set point value, redemption minimum, and collection method rates.</p>
        </div>
      </div>
      {error && <div className="alert error">{error}</div>}
      {success && <div className="alert success">{success}</div>}
      <section className="card">
        <form className="form" onSubmit={save}>
          <label className="field">
            Minimum points per redemption
            <input
              type="number"
              min="1"
              step="1"
              value={policy.minimum_redemption_points}
              onChange={(event) => update("minimum_redemption_points", event.target.value)}
              required
            />
          </label>
          <label className="field">
            UGX value per point
            <input
              type="number"
              min="0.01"
              step="0.01"
              value={policy.ugx_per_point}
              onChange={(event) => update("ugx_per_point", event.target.value)}
              required
            />
          </label>
          <label className="field">
            Pickup points rate (%)
            <input
              type="number"
              min="0"
              max="100"
              step="1"
              value={policy.pickup_points_percent}
              onChange={(event) => update("pickup_points_percent", event.target.value)}
              required
            />
          </label>
          <label className="field">
            Drop-off points rate (%)
            <input
              type="number"
              min="0"
              max="100"
              step="1"
              value={policy.dropoff_points_percent}
              onChange={(event) => update("dropoff_points_percent", event.target.value)}
              required
            />
          </label>
          <p className="sub">
            Points are credited only after a recycler verifies processing. Consumers can redeem
            for mobile money or airtime once they meet the minimum.
          </p>
          <button className="btn" disabled={busy}>
            {busy ? "Saving…" : "Save reward policy"}
          </button>
        </form>
      </section>
    </div>
  );
}