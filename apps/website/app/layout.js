import { Plus_Jakarta_Sans } from 'next/font/google';
import './globals.css';

const sans = Plus_Jakarta_Sans({
  subsets: ['latin'],
  variable: '--font-sans',
});

export const metadata = {
  title: 'zyvault — your money, sorted by talking',
  description:
    'zyvault is an Android app for spends, income, plans and goals. Say what happened, catch UPI payments, and ask your money questions.',
};

export default function RootLayout({ children }) {
  return (
    <html lang="en" className={sans.variable}>
      <body>{children}</body>
    </html>
  );
}
