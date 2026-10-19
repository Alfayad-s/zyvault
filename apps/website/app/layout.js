import { Plus_Jakarta_Sans } from 'next/font/google';
import { site, siteUrl, softwareJsonLd } from '../lib/site';
import './globals.css';

const sans = Plus_Jakarta_Sans({
  subsets: ['latin'],
  variable: '--font-sans',
});

const url = siteUrl();

export const metadata = {
  metadataBase: new URL(url),
  title: {
    default: site.title,
    template: '%s — zyvault',
  },
  description: site.description,
  applicationName: site.name,
  keywords: [
    'zyvault',
    'Android money tracker',
    'expense tracker India',
    'UPI expense tracker',
    'voice expense tracker',
    'Malayalam finance app',
    'Hinglish expense app',
    'budget app rupees',
    'personal finance Android',
  ],
  authors: [{ name: 'zyvault' }],
  creator: 'zyvault',
  alternates: { canonical: '/' },
  robots: {
    index: true,
    follow: true,
    googleBot: { index: true, follow: true, 'max-image-preview': 'large' },
  },
  openGraph: {
    type: 'website',
    url,
    siteName: site.name,
    title: site.title,
    description: site.description,
    locale: 'en_IN',
  },
  twitter: {
    card: 'summary',
    title: site.title,
    description: site.description,
  },
  category: 'finance',
};

export default function RootLayout({ children }) {
  return (
    <html lang="en" className={sans.variable}>
      <body>
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(softwareJsonLd()) }}
        />
        {children}
      </body>
    </html>
  );
}
