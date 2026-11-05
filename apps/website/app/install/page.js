import { Frame } from '../../components/frame';
import { InstallPlans } from '../../components/install-plans';

export const metadata = {
  title: 'Install',
  description:
    'Download the free basic zyvault app, or the free app that reads payment alerts. The extra taps are on this page.',
  alternates: { canonical: '/install' },
};

export default function InstallPage() {
  return (
    <Frame>
      <article className="prose install">
        <h1>Pick the app you want</h1>
        <p className="lede about-lede">Both are free. Basic is the easy one. Payment alerts needs a few extra taps on your phone.</p>
        <InstallPlans />
      </article>
    </Frame>
  );
}
