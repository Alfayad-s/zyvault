'use client';

import { useEffect, useState } from 'react';
import { PrintButton } from './print-button';

const basicPoints = [
  'Add money you spent',
  'Add money you received',
  'Budgets and savings goals',
  'Add a spend by talking',
  'Read bank text messages',
];

const alertPoints = [
  'Everything in Basic',
  'See a payment as soon as it happens',
  'GPay, PhonePe, Paytm, BHIM and CRED',
  'Your phone asks a few extra questions',
];

const stops = [
  {
    title: 'Open the downloaded file',
    taps: ['Tap Download on the dark card.', 'Open the file named zyvault.apk.', 'Tap Install.'],
  },
  {
    title: 'If the phone says the app is unsafe',
    taps: ['Tap More details.', 'Tap Install anyway.'],
  },
  {
    title: 'If you do not see Install anyway',
    taps: [
      'Open the Play Store.',
      'Tap your photo.',
      'Tap Play Protect.',
      'Tap the gear.',
      'Turn off Scan apps with Play Protect.',
      'Go back and install zyvault.',
      'Turn Scan apps with Play Protect back on.',
    ],
  },
  {
    title: 'Let the app see payment alerts',
    taps: [
      'Open Settings.',
      'Tap Apps.',
      'Tap zyvault.',
      'Tap the three dots at the top.',
      'Tap Allow restricted settings.',
      'If the three dots are missing, skip this step.',
    ],
  },
  {
    title: 'Turn alerts on',
    taps: ['Open zyvault.', 'Tap Profile.', 'Turn on Read UPI app alerts.', 'On the next screen, turn zyvault on.'],
  },
];

function Check() {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path d="M9.2 16.2 4.8 11.8l1.4-1.4 3 3 8.6-8.6 1.4 1.4z" />
    </svg>
  );
}

function Points({ items, tone }) {
  return (
    <ul className={tone === 'light' ? 'plan-points light' : 'plan-points'}>
      {items.map((item) => (
        <li key={item}>
          <span>
            <Check />
          </span>
          {item}
        </li>
      ))}
    </ul>
  );
}

export function InstallPlans() {
  const [plan, setPlan] = useState(null);

  useEffect(() => {
    if (plan !== 'alerts') return;
    document.getElementById('upi-steps')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }, [plan]);

  return (
    <>
      <div className="plans">
        <article className={plan === 'basic' ? 'plan on' : 'plan'}>
          <h2>Basic</h2>
          <p className="plan-price">
            Free
          </p>
          <p className="plan-blurb">The money app. It does not read GPay, PhonePe or other payment alerts.</p>
          <div className="plan-actions">
            <a className="plan-btn dark" href="/zyvault-basic.apk" download="zyvault-basic.apk" onClick={() => setPlan('basic')}>
              Download
            </a>
          </div>
          <div className="plan-features">
            <p>What you get</p>
            <p className="plan-lead">The everyday app</p>
            <Points items={basicPoints} />
          </div>
        </article>

        <article className={plan === 'alerts' ? 'plan alerts on' : 'plan alerts'}>
          <div className="plan-top">
            <h2>Payment alerts</h2>
            <span className="plan-badge">Extra steps</span>
          </div>
          <p className="plan-price">Free</p>
          <p className="plan-blurb">The same app, plus alerts from GPay, PhonePe, Paytm, BHIM and CRED.</p>
          <div className="plan-actions">
            <a className="plan-btn lime" href="/zyvault.apk" download="zyvault.apk" onClick={() => setPlan('alerts')}>
              Download
            </a>
            <button type="button" className="plan-btn line" onClick={() => setPlan('alerts')}>
              Show the steps
            </button>
          </div>
          <div className="plan-features">
            <p>What you get</p>
            <p className="plan-lead">Everything in Basic, plus</p>
            <Points items={alertPoints} tone="light" />
          </div>
        </article>
      </div>

      {plan === 'basic' ? (
        <p className="plan-note no-print">Open the file you downloaded. Tap Install. That is all.</p>
      ) : null}

      {plan === 'alerts' ? (
        <section id="upi-steps" className="plan-steps">
          <div className="plan-steps-head">
            <div>
              <h2>Do these 5 things</h2>
              <p>Only for the Payment alerts download. Basic does not need this.</p>
            </div>
            <PrintButton />
          </div>
          <ol className="guide">
            {stops.map((stop, index) => (
              <li key={stop.title}>
                <span>{index + 1}</span>
                <div>
                  <h2>{stop.title}</h2>
                  <ul className="step-taps">
                    {stop.taps.map((tap) => (
                      <li key={tap}>{tap}</li>
                    ))}
                  </ul>
                </div>
              </li>
            ))}
          </ol>
        </section>
      ) : null}
    </>
  );
}
