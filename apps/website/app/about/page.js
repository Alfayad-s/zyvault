import { Frame } from '../../components/frame';
import { aboutJsonLd, features, site } from '../../lib/site';

export const metadata = {
  title: 'About',
  description:
    'zyvault is an Android app that records spends, income, budgets, goals and money lent, in rupees. Messages stay on the phone. It does not send money.',
  alternates: { canonical: '/about' },
};

export default function AboutPage() {
  return (
    <Frame>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(aboutJsonLd()) }}
      />
      <article className="prose about">
        <p className="pill">About</p>
        <h1>About zyvault</h1>
        <p className="lede about-lede">{site.description}</p>

        <h2>The short version</h2>
        <p>
          zyvault is an Android app for people who earn and spend in rupees. It replaces the notebook: cash, bank accounts, UPI payments you choose to catch, monthly plans, category budgets, savings goals, and a note of who owes whom.
        </p>
        <p>
          You talk to it the way you already talk. “450 pizza last night.” “35k salary on 6th.” “Add 500 to Goa trip.” English, Malayalam and Hinglish all work. A photo of a bill can be read the same way. Nothing is saved until you see the line and confirm it.
        </p>

        <h2>Who it is for</h2>
        <p>
          It is for someone with a salary, rent, food, a few UPI payments and maybe money lent to a friend. Cash and every bank account you add sit in one balance. The app is built around ₹, not dollars.
        </p>

        <h2>What you can do</h2>
        <ul>
          {features.map((item) => (
            <li key={item.title}>
              <strong>{item.title}.</strong> {item.body}
            </li>
          ))}
        </ul>
        <p>
          Home shows the balance, spending this month, the next planned payment, goals, budgets and recent operations. Activity charts expenses or income by week, month or quarter. Money holds the accounts. Scheduled holds the plans.
        </p>

        <h2>What stays on the phone</h2>
        <p>
          Bank SMS and UPI app alerts are optional. They stay off until you turn on “Read bank SMS” or “Read UPI app alerts” in Profile. Parsing happens on the device. Those messages are not uploaded. You can mark a sender as spam so later messages from them are ignored, and allow that sender again later.
        </p>
        <p>
          A fingerprint, face unlock or the phone PIN can be required each time the app opens. That lock is the phone’s own lock, not a separate zyvault password.
        </p>

        <h2>What zyvault does not do</h2>
        <ul>
          <li>It does not hold, send or receive money. A payment still happens in your bank or UPI app.</li>
          <li>It does not connect to a bank with your login. Accounts are names and opening balances you enter.</li>
          <li>It does not read messages until you allow notification access.</li>
          <li>It is an APK you install yourself. This site does not claim a Play Store listing.</li>
        </ul>

        <p>
          <a className="cta" href="/zyvault.apk" download="zyvault.apk">
            Download APK
          </a>
        </p>
      </article>
    </Frame>
  );
}
