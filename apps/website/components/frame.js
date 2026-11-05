export function Frame({ children }) {
  return (
    <div className="page">
      <div className="shell">
        <header className="nav">
          <a className="wordmark" href="/">
            zyvault<span className="dot">.</span>
          </a>
          <nav aria-label="Pages">
            <a href="/#benefits">Features</a>
            <a href="/#how">How it works</a>
            <a href="/about">About</a>
            <a href="/#faq">FAQ</a>
          </nav>
          <a className="nav-btn" href="/install">
            Get the app
          </a>
        </header>
        <main>{children}</main>
        <footer>
          <span>
            zyvault<span className="dot">.</span>
          </span>
          <nav aria-label="Footer">
            <a href="/about">About</a>
            <a href="/#faq">FAQ</a>
            <a href="/install">Install</a>
            <a href="/privacy">Privacy</a>
            <a href="/terms">Terms</a>
            <a href="/llms.txt">Product facts</a>
          </nav>
        </footer>
      </div>
    </div>
  );
}
