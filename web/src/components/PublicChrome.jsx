import { useEffect, useState } from "react";
import { Link, useLocation } from "react-router-dom";

function HomeLink({ className, children }) {
  const { pathname } = useLocation();
  return (
    <Link
      to="/"
      className={className}
      onClick={(e) => {
        if (pathname === "/") {
          e.preventDefault();
          window.scrollTo({ top: 0, behavior: "smooth" });
        }
      }}
    >
      {children}
    </Link>
  );
}

export function PublicHeader() {
  const { pathname } = useLocation();
  const [scrolled, setScrolled] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);

  // Home link shows only off the landing page, or once the landing view
  // (the hero section) has been scrolled past.
  useEffect(() => {
    const onScroll = () => {
      const hero = document.querySelector(".lp-hero");
      const limit = hero
        ? hero.offsetTop + hero.offsetHeight - 64
        : Math.round(window.innerHeight * 0.7);
      setScrolled(window.scrollY >= limit);
    };
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, [pathname]);

  const homeVisible = pathname !== "/" || scrolled;

  return (
    <header className="lp-top">
      <div className="lp-wrap lp-top-in">
        <Link to="/" className="lp-logo" aria-label="EcoTrace home">
          <img className="lp-logo-mark" src="/bg.png" alt="EcoTrace logo" />
        </Link>
        <div
          id="public-navigation"
          className={`lp-top-menu${menuOpen ? " is-open" : ""}`}
        >
          <nav className="lp-nav" onClick={() => setMenuOpen(false)}>
            {homeVisible && <HomeLink>Home</HomeLink>}
            <Link to="/map">Map</Link>
          </nav>
          <div className="lp-top-cta" onClick={() => setMenuOpen(false)}>
            <Link className="btn ghost small" to="/login">Sign in</Link>
            <Link className="btn small" to="/register">Get started</Link>
          </div>
        </div>
        <button
          type="button"
          className="menu-toggle public-menu-toggle"
          aria-label={menuOpen ? "Close navigation menu" : "Open navigation menu"}
          aria-expanded={menuOpen}
          aria-controls="public-navigation"
          onClick={() => setMenuOpen((open) => !open)}
        >
          <span className="menu-toggle-icon" aria-hidden="true">
            <span />
            <span />
            <span />
          </span>
        </button>
      </div>
    </header>
  );
}

export function PublicFooter() {
  return (
    <footer className="lp-foot">
      <div className="lp-wrap lp-foot-grid">
        <div>
          <span className="lp-logo">
            <img className="lp-logo-mark" src="/bg.png" alt="EcoTrace logo" />
          </span>
          <p>E-waste collection, tracking &amp; rewards.</p>
        </div>
        <div>
          <strong>Product</strong>
          <HomeLink>Home</HomeLink>
          <Link to="/roles">Who it's for</Link>
          <Link to="/impact">Rewards</Link>
          <Link to="/map">Map</Link>
        </div>
        <div>
          <strong>Account</strong>
          <Link to="/login">Sign in</Link>
          <Link to="/register">Create account</Link>
        </div>
      </div>
      <div className="lp-wrap lp-foot-legal">
        <span>© 2026 EcoTrace</span>
        <span>Certified recycling · Verified rewards</span>
      </div>
    </footer>
  );
}
