import { Frame } from '../components/frame';
import { faqs, features, steps } from '../lib/site';

const marks = ['Cash', 'Every bank', 'UPI', 'Voice', 'Chat', 'Offline'];

function Icon({ name }) {
  const paths = {
    mic: 'M12 14a3 3 0 0 0 3-3V6a3 3 0 0 0-6 0v5a3 3 0 0 0 3 3zm5-3a5 5 0 0 1-10 0H5a7 7 0 0 0 6 6.92V21h2v-3.08A7 7 0 0 0 19 11h-2z',
    bell: 'M12 22a2.5 2.5 0 0 0 2.45-2h-4.9A2.5 2.5 0 0 0 12 22zm7-6V11a7 7 0 0 0-5-6.71V3a2 2 0 1 0-4 0v1.29A7 7 0 0 0 5 11v5l-2 2v1h18v-1l-2-2z',
    target:
      'M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm0 4a6 6 0 1 1 0 12 6 6 0 0 1 0-12zm0 3a3 3 0 1 0 0 6 3 3 0 0 0 0-6z',
    cal: 'M7 2h2v2h6V2h2v2h3v18H4V4h3V2zm11 8H6v10h12V10z',
    chat: 'M4 4h16v12H7l-3 3V4zm3 4v2h10V8H7zm0 4v2h7v-2H7z',
    lock: 'M7 10V7a5 5 0 0 1 10 0v3h1v12H6V10h1zm2 0h6V7a3 3 0 0 0-6 0v3z',
    spark: 'M12 2l1.6 5.2L19 9l-5.4 1.8L12 16l-1.6-5.2L5 9l5.4-1.8L12 2zm6 12l.8 2.2L21 17l-2.2.8L18 20l-.8-2.2L15 17l2.2-.8L18 14z',
    widget: 'M4 4h7v7H4V4zm9 0h7v5h-7V4zM4 13h7v7H4v-7zm9 3h7v4h-7v-4z',
    phone: 'M8 2h8a2 2 0 0 1 2 2v16a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2zm4 16.5a1.2 1.2 0 1 0 0 2.4 1.2 1.2 0 0 0 0-2.4z',
    file: 'M6 2h8l4 4v16H6V2zm8 1.5V7h3.5L14 3.5zM8 11h8v1.5H8V11zm0 3.5h8V16H8v-1.5z',
  };
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path d={paths[name]} />
    </svg>
  );
}

export default function HomePage() {
  return (
    <Frame>
      <section className="hero" id="top">
        <p className="proof">Android app for everyday rupees</p>
        <h1>
          Take control of your
          <br />
          money by talking
        </h1>
        <p className="lede">
          zyvault is an Android app for spends, income, plans and goals. Say what you spent, ask the chat, catch UPI payments on the phone, and keep the records even when you are offline.
        </p>
        <div className="actions">
          <a className="cta" href="/zyvault-basic.apk" download="zyvault-basic.apk">
            Download the basic app
          </a>
          <a className="cta ghost" href="/install">
            App with payment alerts
          </a>
          <a className="cta ghost" href="/install">
            Install steps
          </a>
        </div>
      </section>

      <section className="marks" aria-label="What zyvault covers">
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
          Speak a spend, ask the chat, confirm it, and let plans, budgets and the home-screen widget live next to the balance.
        </p>
        <div className="grid">
          {features.map((item) => (
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

      <section className="split" id="how">
        <p className="pill">How it works</p>
        <h2>Three steps, then it is saved</h2>
        <ol className="steps">
          {steps.map((step, index) => (
            <li key={step.title}>
              <span>{index + 1}</span>
              <h3>{step.title}</h3>
              <p>{step.body}</p>
            </li>
          ))}
        </ol>
      </section>

      <section className="prose" id="about">
        <p className="pill">About</p>
        <h2>What zyvault is</h2>
        <p>
          zyvault is a personal finance app for Android. It keeps a record of cash and bank accounts in rupees: what came in, what went out, what is planned, and what you are saving for.
        </p>
        <p>
          You add a line by typing or speaking, including Malayalam and Hinglish, or by photographing a bill. If you allow it, a bank SMS or a payment alert from GPay, PhonePe, Paytm, BHIM or CRED can start the same question. You still confirm the category before it is saved.
        </p>
        <p>
          zyvault is not a bank and it does not send money. Paying someone still happens in your own UPI or bank app. The ledger is the part that used to live in a notebook.
        </p>
        <p>
          <a className="text-link" href="/about">
            Read the full about page
          </a>
        </p>
      </section>

      <section className="faq" id="faq">
        <p className="pill">FAQ</p>
        <h2>Questions people ask</h2>
        <div className="faq-list">
          {faqs.map((item) => (
            <article key={item.question}>
              <h3>{item.question}</h3>
              <p>{item.answer}</p>
            </article>
          ))}
        </div>
      </section>
    </Frame>
  );
}
