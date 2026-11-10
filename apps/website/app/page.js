import { Coffee } from '../components/coffee';
import { FeatureTabs } from '../components/feature-tabs';
import { Frame } from '../components/frame';
import { faqs, steps } from '../lib/site';

const marks = ['Cash', 'Every bank', 'UPI', 'Voice', 'Chat', 'Forecast'];

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
        <FeatureTabs />
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

      <Coffee />
    </Frame>
  );
}
