import { Frame } from '../../components/frame';
import { site } from '../../lib/site';

export const metadata = {
  title: 'Terms',
  description:
    'The terms for using zyvault, an Android app that records your own spending and income in rupees.',
  alternates: { canonical: '/terms' },
};

export default function TermsPage() {
  return (
    <Frame>
      <article className="prose legal">
        <p className="pill">Terms</p>
        <h1>Terms and conditions</h1>
        <p className="updated">19 October 2026</p>
        <p>
          These terms cover the zyvault Android app and the site at zyvault.clawdage.com. By creating an account or using the app, you agree to them.
        </p>

        <h2>What zyvault is</h2>
        <p>
          zyvault keeps a record of money you enter: spends, income, accounts, budgets, goals, plans and who owes whom. Amounts are in rupees. You can type, speak, or photograph a bill, and you confirm a line before it is saved.
        </p>
        <p>
          zyvault is not a bank, a wallet, or a payments app. It does not send, receive, hold or invest money. Paying someone still happens in your bank or UPI app. A balance in zyvault is the total of the records you added. It is not an account balance fetched from a bank.
        </p>

        <h2>Your account</h2>
        <p>
          You need an email address you can open. zyvault sends a one-time code to sign in. You are responsible for that inbox. One person uses their own account. You need to be 18 or older.
        </p>
        <p>
          You can sign out in the app. To delete the account and the records stored for it, email{' '}
          <a className="text-link" href={`mailto:${site.contactEmail}?subject=Delete%20my%20zyvault%20account`}>
            {site.contactEmail}
          </a>{' '}
          from that same address. The steps are also on the{' '}
          <a className="text-link" href="/privacy#delete">
            privacy policy
          </a>
          .
        </p>

        <h2>Your records</h2>
        <p>
          You keep ownership of the transactions, notes and names you enter. You give zyvault permission to store them and to show them back to you, so the app can work. Do not enter someone else’s information unless you have a reason to keep that record for yourself, such as money you lent a friend.
        </p>
        <p>
          Categories and amounts suggested from what you say, or from a bill photo, can be wrong. You check the line before it is saved. zyvault is a notebook, not tax, legal or financial advice.
        </p>

        <h2>Phone permissions</h2>
        <p>
          The microphone, camera, photos, notifications and notification access are optional. Bank and UPI alerts stay off until you turn them on, and those messages stay on the phone. You can turn the switches off again in Profile.
        </p>

        <h2>Acceptable use</h2>
        <p>
          Use zyvault for your own records. Do not try to break the service, probe another person’s account, or use the app to store anything you are not allowed to store. We may suspend an account that is used that way.
        </p>

        <h2>The service</h2>
        <p>
          zyvault is provided as it is. Records can be unavailable while the service is being fixed. Keep your own copy of anything you cannot afford to lose. To the extent the law allows, zyvault is not liable for a missed reminder, a misread bill, or a decision you make from the records in the app.
        </p>

        <h2>The site and the APK</h2>
        <p>
          The website describes the app and may offer an APK. Installing an APK means you trust that file. When zyvault is on Google Play, the Play listing is the store copy of the same app. These terms cover both.
        </p>

        <h2>Changes</h2>
        <p>
          If these terms change, the date at the top of this page changes with it. Continuing to use zyvault after that date means you accept the new terms. Questions go to{' '}
          <a className="text-link" href={`mailto:${site.contactEmail}`}>
            {site.contactEmail}
          </a>
          .
        </p>
      </article>
    </Frame>
  );
}
