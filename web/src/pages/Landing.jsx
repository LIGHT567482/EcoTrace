import { Link } from "react-router-dom";
import { useAuth } from "../auth";
import CountUp from "../components/CountUp";

const KANSANGA_POPULATION = 48000;
const UGANDA_GDP_PER_CAPITA_USD = 1000;

function ImpactCard() {
  return (
    <div className="lp-impact-card" aria-label="EcoTrace impact summary">
      <div className="lp-impact-card-head">
        <img className="lp-impact-icon" src="/bg.png" alt="" aria-hidden="true" />
        <div>
          <strong>Verified environmental impact</strong>
          <small>EcoTrace · Kampala</small>
        </div>
      </div>
      <div className="lp-impact-value">
        <strong>2 items</strong>
        <span>logged for recycling</span>
      </div>
      <div className="lp-impact-card-foot">
        <span>Certified recycling</span>
        <strong>UGX 800 earned</strong>
      </div>
    </div>
  );
}

export default function Landing() {
  const { user } = useAuth();

  return (
    <div className="lp">
      {/* HERO */}
      <section className="lp-hero">
        <div className="lp-wrap lp-hero-grid">
          <div className="lp-hero-copy">
            <h1>
              Old electronics
              <br />
              deserve a <em>second life</em>.
            </h1>
            <p className="lp-lede">
              EcoTrace follows every phone, battery and appliance you let go of -
              from your doorstep to the certified recycling floor - and pays you
              for the impact you make.
            </p>
            <div className="lp-cta">
              {user ? (
                <Link className="btn lp-btn-primary" to="/">
                  Open dashboard
                </Link>
              ) : (
                <>
                  <Link className="btn lp-btn-primary" to="/register">
                    Create free account
                  </Link>
                  <Link className="btn lp-btn-ghost" to="/login">
                    Sign in
                  </Link>
                </>
              )}
            </div>
            <ul className="lp-trust">
              <li><strong>Certified</strong> facilities only</li>
              <li><strong>Live</strong> chain-of-custody</li>
              <li><strong>Instant</strong> mobile-money payout</li>
            </ul>
            <div className="lp-stats-grid" aria-label="Impact so far">
              <div>
                <strong>
                  <CountUp value={Math.round(KANSANGA_POPULATION / 800)} />
                </strong>
                <span>waste categories tracked</span>
              </div>
              <div>
                <strong>
                  <CountUp
                    value={Math.round(UGANDA_GDP_PER_CAPITA_USD / 5)}
                    delay={120}
                  />
                </strong>
                <span>device &amp; appliance types</span>
              </div>
              <div>
                <strong>
                  <CountUp
                    value={Math.round(KANSANGA_POPULATION / 1500)}
                    delay={240}
                  />
                </strong>
                <span>certified drop-off points</span>
              </div>
              <div>
                <strong>
                  <CountUp value={100} delay={360} suffix="%" />
                </strong>
                <span>items followed to processing</span>
              </div>
            </div>
          </div>
          <div className="lp-hero-visual">
            <img
              className="lp-hero-logo"
              src="/bg.png"
              alt="EcoTrace - sustainable traceability solutions"
            />
            <ImpactCard />
          </div>
        </div>
      </section>

      {/* MAP TEASER */}
      <section className="lp-section" id="map">
        <div className="lp-wrap lp-map-grid">
          <div>
            <span className="lp-kicker">Find us</span>
            <h2 className="lp-h2">Drop it off around the corner.</h2>
            <p className="lp-sub">
              Certified collection points in Kansanga only. Open the map right
              here in EcoTrace, no extra apps, no leaving the system.
            </p>
            <div className="lp-cta">
              <Link className="btn" to="/map">
                Open the map
              </Link>
              <Link className="btn ghost" to="/register">
                Request a pickup instead
              </Link>
            </div>
          </div>
          <div className="lp-map-frame">
            <iframe
              title="EcoTrace drop-off points map"
              src="https://www.google.com/maps?q=Kansanga,+Kampala,+Uganda&z=15&output=embed"
              loading="lazy"
              referrerPolicy="no-referrer-when-downgrade"
            />
          </div>
        </div>
      </section>

      {/* FINAL CTA */}
      <section className="lp-final">
        <div className="lp-wrap lp-final-in">
          <h2>Ready to clear the drawer?</h2>
          <p>Three minutes to sign up. Your first certificate the same day.</p>
          <div className="lp-cta center">
            <Link className="btn lp-btn-primary" to="/register">
              Get started free
            </Link>
            <Link className="btn lp-btn-ghost" to="/login">
              I have an account
            </Link>
          </div>
        </div>
      </section>
    </div>
  );
}
