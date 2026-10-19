import { siteUrl } from '../lib/site';

export default function sitemap() {
  const url = siteUrl();
  const lastModified = new Date();
  return [
    { url: `${url}/`, lastModified, changeFrequency: 'weekly', priority: 1 },
    { url: `${url}/about`, lastModified, changeFrequency: 'monthly', priority: 0.8 },
  ];
}
