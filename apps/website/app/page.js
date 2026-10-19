const benefits = [
  {
    title: 'Just say it',
    body: 'Type or speak “450 pizza last night” or “35k salary on 6th”. You see the line before it is saved.',
    icon: 'mic',
  },
  {
    title: 'Payments caught',
    body: 'Bank SMS and GPay, PhonePe or Paytm alerts become one question: where did this ₹500 go?',
    icon: 'bell',
  },
  {
    title: 'Budgets & goals',
    body: 'A limit for food, a Goa trip, and a note of who owes whom. zyvault warns you at 80%.',
    icon: 'target',
  },
  {
    title: 'Plans & reminders',
    body: 'Salary on the 1st, rent on the 5th, send ₹500 to Ravi at 6 pm. It reminds you, then records it.',
    icon: 'cal',
  },
  {
    title: 'Ask your money',
    body: '“How much on food this month?” “Who owes me?” The answer comes back with a chart.',
    icon: 'chat',
  },
  {
    title: 'Private on the phone',
    body: 'Messages stay on the device. You confirm a spend before it is saved, and a fingerprint locks the app.',
    icon: 'lock',
  },
];

const marks = ['Cash', 'Every bank', 'UPI', 'Voice', 'Budgets', 'Goals'];

function Icon({ name }) {
  const paths = {
    mic: 'M12 14a3 3 0 0 0 3-3V6a3 3 0 0 0-6 0v5a3 3 0 0 0 3 3zm5-3a5 5 0 0 1-10 0H5a7 7 0 0 0 6 6.92V21h2v-3.08A7 7 0 0 0 19 11h-2z',
    bell: 'M12 22a2.5 2.5 0 0 0 2.45-2h-4.9A2.5 2.5 0 0 0 12 22zm7-6V11a7 7 0 0 0-5-6.71V3a2 2 0 1 0-4 0v1.29A7 7 0 0 0 5 11v5l-2 2v1h18v-1l-2-2z',
    target:
      'M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm0 4a6 6 0 1 1 0 12 6 6 0 0 1 0-12zm0 3a3 3 0 1 0 0 6 3 3 0 0 0 0-6z',
    cal: 'M7 2h2v2h6V2h2v2h3v18H4V4h3V2zm11 8H6v10h12V10z',
    chat: 'M4 4h16v12H7l-3 3V4zm3 4v2h10V8H7zm0 4v2h7v-2H7z',
    lock: 'M7 10V7a5 5 0 0 1 10 0v3h1v12H6V10h1zm2 0h6V7a3 3 0 0 0-6 0v3z',
  };
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path d={paths[name]} />
    </svg>
  );
}

export default function HomePage() {
  return (
    <div className="page">
      <div className="shell">
        <header className="nav">
          <a className="wordmark" href="#top">
            zyvault<span className="dot">.</span>
          </a>
          <nav>
            <a href="#top">Home</a>
            <a href="#benefits">Features</a>
            <a href="#benefits">How it works</a>
            <a href="#privacy">Privacy</a>
          </nav>
          <a className="nav-btn" href="/zyvault.apk" download="zyvault.apk">
            Download APK
          </a>
        </header>

        <section className="hero" id="top">
          <p className="proof">Everyday spends, income, plans and goals</p>
          <h1>
            Take control of your
            <br />
            money by talking
          </h1>
          <p className="lede">
            zyvault is an Android app for rupees. Say what you spent, catch UPI payments, and keep budgets in one calm place.
          </p>
          <div className="actions">
            <a className="cta" href="/zyvault.apk" download="zyvault.apk">
              Download APK
            </a>
            <a className="cta ghost" href="#benefits">
              See how it works
            </a>
          </div>
        </section>

        <section className="marks">
          <p>Made for the way money actually moves</p>
          <ul>
            {marks.map((mark) => (
              <li key={mark}>{mark}</li>
            ))}
          </ul>
        </section>

        <section className="benefits" id="benefits">
          <p className="pill">Features</p>
          <h2>A quieter way to track money</h2>
          <p className="sub">
            Speak a spend, confirm it, and let plans, budgets and questions live next to the balance.
          </p>
          <div className="grid">
            {benefits.map((item) => (
              <article key={item.title} id={item.icon === 'lock' ? 'privacy' : undefined}>
                <span className="icon">
                  <Icon name={item.icon} />
                </span>
                <h3>{item.title}</h3>
                <p>{item.body}</p>
              </article>
            ))}
          </div>
        </section>

        <footer>
          <span>
            zyvault<span className="dot">.</span>
          </span>
          <span>An Android app for everyday money.</span>
        </footer>
      </div>
    </div>
  );
}
