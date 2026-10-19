import { siteUrl } from '../lib/site';

export default function sitemap() {
  const url = siteUrl();
  const lastModified = new Date();
  return [
    { url: `${url}/`, lastModified, changeFrequency: 'weekly', priority: 1 },
    { url: `${url}/about`, lastModified, changeFrequency: 'monthly', priority: 0.8 },
    { url: `${url}/privacy`, lastModified, changeFrequency: 'yearly', priority: 0.4 },
    { url: `${url}/terms`, lastModified, changeFrequency: 'yearly', priority: 0.4 },
  ];
}
