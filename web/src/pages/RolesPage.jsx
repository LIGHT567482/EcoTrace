import { Link } from "react-router-dom";

const ROLES = [
  {
    t: "Consumers",
    d: "Log e-waste, request pickups, watch it get recycled and earn mobile-money rewards.",
  },
  {
    t: "Collectors",
    d: "See nearby open requests, claim jobs, and confirm hand-offs with one tap.",
  },
  {
    t: "Recyclers",
    d: "Receive shipments, verify contents and process batches to unlock rewards.",
  },
  {
    t: "Administrators",
    d: "Oversee users, categories, redemption payouts and full-chain impact reports.",
  },
];

export default function RolesPage() {
  return (
    <>
      <section className="lp-section lp-alt" id="roles">
        <div className="lp-wrap">
          <span className="lp-kicker">One system, four roles</span>
          <h2 className="lp-h2">Built for everyone in the chain</h2>
          <p className="lp-sub">
            EcoTrace connects the people letting go of old electronics with the
            collectors, certified recyclers and administrators who take them
            the rest of the way.
          </p>
          <div className="lp-roles">
            {ROLES.map((r) => (
              <article className="lp-role" key={r.t}>
                <h3>{r.t}</h3>
                <p>{r.d}</p>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="lp-final">
        <div className="lp-wrap lp-final-in">
          <h2>Pick your part in the chain.</h2>
          <p>
            Consumers register themselves — create an account and start
            tracking your e-waste.
          </p>
          <div className="lp-cta center">
            <Link className="btn lp-btn-primary" to="/register">
              Get started free
            </Link>
            <Link className="btn lp-btn-ghost" to="/impact">
              See how rewards work
            </Link>
          </div>
        </div>
      </section>
    </>
  );
}
