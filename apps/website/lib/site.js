export function siteUrl() {
  const explicit = process.env.NEXT_PUBLIC_SITE_URL?.replace(/\/$/, '');
  if (explicit) return explicit;
  if (process.env.VERCEL_PROJECT_PRODUCTION_URL) {
    return `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}`;
  }
  if (process.env.VERCEL_URL) return `https://${process.env.VERCEL_URL}`;
  return 'http://localhost:3001';
}

export const site = {
  name: 'zyvault',
  title: 'zyvault — an Android money tracker you talk to',
  description:
    'zyvault is an Android app for rupees. Say a spend in English, Malayalam or Hinglish, catch bank SMS and UPI alerts on the phone, and keep budgets, goals and who owes whom.',
};

export const features = [
  {
    title: 'Just say it',
    body: 'Type or speak “450 pizza last night” or “35k salary on 6th”. zyvault shows the line before it is saved. Voice works in English, Malayalam and Hinglish, and a photo of a bill can be read the same way.',
    icon: 'mic',
  },
  {
    title: 'Payments caught',
    body: 'Bank SMS and alerts from GPay, PhonePe, Paytm, BHIM and CRED become one question: where did this money go? The message stays on the phone. A sender you mark as spam is skipped until you allow it.',
    icon: 'bell',
  },
  {
    title: 'Budgets & goals',
    body: 'Set a monthly limit for food, shopping or any category. zyvault warns you at 80% and again when you go over. Save toward a goal, such as a trip, by saying “add 500 to Goa trip”.',
    icon: 'target',
  },
  {
    title: 'Plans & reminders',
    body: 'Salary on the 1st, rent on the 5th, send ₹500 to someone at 6 pm. zyvault reminds you, then records the entry. Reminders can arrive when the app is closed.',
    icon: 'cal',
  },
  {
    title: 'Ask your money',
    body: 'Ask “How much on food this month?” or “Who owes me?” The answer comes back with a chart, from the accounts and categories you already keep.',
    icon: 'chat',
  },
  {
    title: 'Private on the phone',
    body: 'Bank SMS and UPI alerts are read on the device. You confirm a spend before it is saved, and a fingerprint, face or phone PIN can lock the app when it opens.',
    icon: 'lock',
  },
];

export const steps = [
  {
    title: 'Say the spend',
    body: 'Speak or type the amount and what it was for, in the words you already use. A bill photo works too.',
  },
  {
    title: 'Check the line',
    body: 'zyvault shows the amount, category, account and date. You change anything that is wrong, then save.',
  },
  {
    title: 'See the month',
    body: 'Home shows the balance, what you spent, goals and budgets. Activity splits the same money by week, month or quarter.',
  },
];

export const faqs = [
  {
    question: 'What is zyvault?',
    answer:
      'zyvault is an Android app for tracking everyday money in rupees. You record spends and income by talking or typing, catch bank SMS and UPI app alerts on the phone, and keep budgets, savings goals, plans and who owes whom.',
  },
  {
    question: 'Does zyvault move or hold my money?',
    answer:
      'No. zyvault does not send, receive or store money. It is a record of cash and bank accounts you add yourself. Paying someone still happens in your bank or UPI app.',
  },
  {
    question: 'Which languages can I speak?',
    answer:
      'You can type or speak in English, Malayalam or Hinglish. Examples: “450 pizza last night” or “35k salary on 6th”.',
  },
  {
    question: 'Do bank SMS and UPI alerts leave the phone?',
    answer:
      'No. Reading bank SMS and alerts from GPay, PhonePe, Paytm, BHIM and CRED happens on the phone, and only after you turn those options on in Profile. Messages are not uploaded.',
  },
  {
    question: 'Can I track who I lent money to?',
    answer:
      'Yes. You can mark a line as lent or paid back, then ask who owes you. The balance for each person stays with the rest of your records.',
  },
  {
    question: 'How do budgets and goals work?',
    answer:
      'A budget is a monthly limit on a category. zyvault warns you when that category reaches 80% and when it goes over. A goal is an amount you are saving toward. You can add to it by saying so, for example “add 500 to Goa trip”.',
  },
  {
    question: 'Is zyvault on the Play Store?',
    answer:
      'zyvault is an Android app you install from the APK offered on this site. It is not described here as a Play Store listing.',
  },
];

export function softwareJsonLd() {
  const url = siteUrl();
  return {
    '@context': 'https://schema.org',
    '@graph': [
      {
        '@type': 'WebSite',
        '@id': `${url}/#website`,
        url,
        name: site.name,
        description: site.description,
        inLanguage: 'en',
      },
      {
        '@type': 'SoftwareApplication',
        '@id': `${url}/#app`,
        name: site.name,
        applicationCategory: 'FinanceApplication',
        operatingSystem: 'Android',
        url,
        description: site.description,
        inLanguage: ['en', 'ml', 'hi'],
        featureList: features.map((item) => item.title),
        downloadUrl: `${url}/zyvault.apk`,
      },
      {
        '@type': 'FAQPage',
        '@id': `${url}/#faq`,
        url: `${url}/#faq`,
        mainEntity: faqs.map((item) => ({
          '@type': 'Question',
          name: item.question,
          acceptedAnswer: {
            '@type': 'Answer',
            text: item.answer,
          },
        })),
      },
    ],
  };
}

export function aboutJsonLd() {
  const url = siteUrl();
  return {
    '@context': 'https://schema.org',
    '@type': 'AboutPage',
    '@id': `${url}/about#about`,
    url: `${url}/about`,
    name: 'About zyvault',
    description: site.description,
    isPartOf: { '@id': `${url}/#website` },
    about: { '@id': `${url}/#app` },
    inLanguage: 'en',
  };
}

export function llmsText() {
  const url = siteUrl();
  const featureLines = features
    .map((item) => `- ${item.title}: ${item.body}`)
    .join('\n');
  const faqLines = faqs
    .map((item) => `### ${item.question}\n${item.answer}`)
    .join('\n\n');
  return `# zyvault

> ${site.description}

zyvault is a personal Android finance tracker for rupees. It is not a bank and it does not send money.

## Product
- Name: zyvault
- Platform: Android, installed from an APK
- Currency: Indian rupees (₹)
- Languages for entry: English, Malayalam, Hinglish
- Site: ${url}
- About: ${url}/about
- APK: ${url}/zyvault.apk

## What it does
${featureLines}

## What it does not do
- It does not hold, send or receive money.
- It does not read bank SMS or UPI alerts until those switches are turned on in Profile.
- It does not upload those messages. Parsing stays on the phone.
- It is not listed here as a Google Play app.

## Who it is for
People who spend and earn in rupees, use cash, a bank account or UPI, and want one place for spends, income, monthly plans, budgets, savings goals and money lent to friends.

## Questions
${faqLines}
`;
}
