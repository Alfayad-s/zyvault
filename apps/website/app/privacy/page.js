import { Frame } from '../../components/frame';
import { site } from '../../lib/site';

export const metadata = {
  title: 'Privacy',
  description:
    'What zyvault stores, what stays on your phone, and how to delete your account.',
  alternates: { canonical: '/privacy' },
};

export default function PrivacyPage() {
  return (
    <Frame>
      <article className="prose legal">
        <p className="pill">Privacy</p>
        <h1>Privacy policy</h1>
        <p className="updated">19 October 2026</p>
        <p>
          zyvault is an Android app for keeping a record of your own money in rupees. It does not send, receive or hold money. This page says what is stored, what stays on the phone, and how to delete an account.
        </p>

        <h2>Who we are</h2>
        <p>
          zyvault is published at zyvault.clawdage.com. Questions about this policy, and requests to delete an account, go to{' '}
          <a className="text-link" href={`mailto:${site.contactEmail}`}>
            {site.contactEmail}
          </a>
          .
        </p>

        <h2>The account</h2>
        <p>
          You sign in with an email address. zyvault emails you a one-time code. There is no password. The account is that email address, plus a session kept on the phone so you stay signed in.
        </p>

        <h2>What is stored for you</h2>
        <p>After you confirm a line, the server stores the records you create:</p>
        <ul>
          <li>Accounts you add, and the transactions, categories and notes on them.</li>
          <li>Budgets, savings goals, planned payments and who owes whom.</li>
          <li>A push token for this phone, if reminders from the server are turned on.</li>
        </ul>
        <p>
          Those records are sent over HTTPS and kept in a database so the same account can open them again. They are not sold, and they are not used for ads. zyvault does not show ads.
        </p>

        <h2>Voice and bill photos</h2>
        <p>
          The microphone is optional. Speech is turned into text by the speech service on the phone. zyvault then sends that text, not a recording, to read the amount, category and date. Nothing is saved until you confirm the line.
        </p>
        <p>
          The camera and photo library are optional. If you attach a bill, receipt or PDF, that file is sent so the amount and merchant can be read. The image is used for that reading and is not kept as a photo in your account. The text you confirm is what gets saved.
        </p>
        <p>
          Reading a line or a bill can pass through an AI provider (Google, Groq or OpenRouter, whichever is configured). That provider sees the text or the bill for the request. It does not receive your account email as part of the bill.
        </p>

        <h2>What stays on the phone</h2>
        <ul>
          <li>
            Bank message notifications and alerts from GPay, PhonePe, Paytm, BHIM and CRED. These stay off until you turn them on in Profile. The text is read on the phone to notice a payment. It is not uploaded.
          </li>
          <li>Senders you mark as spam, and the fingerprint or face unlock setting. Unlock uses the phone’s own lock. zyvault does not receive your fingerprint.</li>
          <li>The sign-in session.</li>
        </ul>
        <p>
          Notification access is a phone setting. Android can block it for an app installed outside the Play Store until you allow restricted settings. zyvault uses it only to notice a payment you can then confirm.
        </p>

        <h2>Who else handles data</h2>
        <ul>
          <li>The database that stores your account and records.</li>
          <li>The email service that delivers the sign-in code.</li>
          <li>An AI provider, only when you ask zyvault to read a line or a bill.</li>
          <li>Firebase Cloud Messaging, only if a push token is registered, to deliver a reminder.</li>
        </ul>
        <p>Bank logo pictures are ordinary images. They are not your transactions.</p>

        <h2 id="delete">Delete your account</h2>
        <p>
          Email{' '}
          <a className="text-link" href={`mailto:${site.contactEmail}?subject=Delete%20my%20zyvault%20account`}>
            {site.contactEmail}
          </a>{' '}
          from the address you use to sign in. Use the subject “Delete my account”.
        </p>
        <p>
          That request deletes the account and the records stored for it: transactions, accounts, budgets, goals, plans, debts and the push token. Sign-in codes expire on their own and are not kept as a password. You can sign out in the app at any time. Signing out stops this phone from receiving that account’s reminders. It does not delete the records.
        </p>

        <h2>Children</h2>
        <p>zyvault is for adults. It is not directed at anyone under 18, and we do not knowingly create accounts for children.</p>

        <h2>Changes</h2>
        <p>
          If this policy changes, the date at the top of this page changes with it. The current version is always at this address.
        </p>
      </article>
    </Frame>
  );
}
