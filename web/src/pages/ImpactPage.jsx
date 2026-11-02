import { Link } from "react-router-dom";

export default function ImpactPage() {
  return (
    <>
      <section className="lp-band" id="impact">
        <div className="lp-wrap lp-band-grid">
          <div>
            <span className="lp-kicker">Rewards &amp; proof</span>
            <h2 className="lp-h2">
              Paid for doing the right thing - and you can prove it.
            </h2>
            <p className="lp-band-copy">
              Every verified disposal credits your in-app wallet and mints a
              numbered certificate: <strong>ECO-XXXXXXXXX</strong>. Redeem to
              mobile money any time an administrator approves your payout.
            </p>
            <div className="lp-cta">
              <Link className="btn lp-btn-primary" to="/register">
                Start earning
              </Link>
            </div>
          </div>
          <div className="lp-cert" aria-hidden="true">
            <div className="lp-cert-top">
              <img className="lp-cert-seal" src="/bg.png" alt="" aria-hidden="true" />
              <div>
                <strong>Disposal Certificate</strong>
                <small>EcoTrace · verified chain of custody</small>
              </div>
            </div>
            <p className="lp-cert-code">ECO-BAD58EB4D1</p>
            <div className="lp-cert-grid">
              <div><small>Holder</small><strong>Aisha Nakato</strong></div>
              <div><small>Items</small><strong>2 · Phones</strong></div>
              <div><small>Items processed</small><strong>2 devices</strong></div>
              <div><small>Reward</small><strong>UGX 800</strong></div>
            </div>
          </div>
        </div>
      </section>

      <section className="lp-final">
        <div className="lp-wrap lp-final-in">
          <h2>Three minutes to sign up.</h2>
          <p>Your first certificate can land the same day you clear the drawer.</p>
          <div className="lp-cta center">
            <Link className="btn lp-btn-primary" to="/register">
              Create free account
            </Link>
            <Link className="btn lp-btn-ghost" to="/roles">
              Who it&apos;s for
            </Link>
          </div>
        </div>
      </section>
    </>
  );
}
