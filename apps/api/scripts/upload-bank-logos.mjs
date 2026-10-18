// Upload bank logo files (svg, png or jpg named <bank-id>.<ext>) to Cloudinary.
// Usage: node --env-file=.env scripts/upload-bank-logos.mjs <dir>
import { createHash } from 'node:crypto';
import { readFile, readdir } from 'node:fs/promises';
import { join } from 'node:path';

const cloud = process.env.CLOUDINARY_CLOUD_NAME;
const key = process.env.CLOUDINARY_API_KEY;
const secret = process.env.CLOUDINARY_API_SECRET;
if (!cloud || !key || !secret) {
  console.error('Set CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY and CLOUDINARY_API_SECRET in .env');
  process.exit(1);
}

const dir = process.argv[2];
const folder = 'finance-track/bank-logos';
const types = { svg: 'image/svg+xml', png: 'image/png', jpg: 'image/jpeg', jpeg: 'image/jpeg' };

for (const file of (await readdir(dir)).sort()) {
  const [publicId, ext] = file.split('.');
  if (!types[ext]) continue;
  const params = {
    folder,
    invalidate: 'true',
    overwrite: 'true',
    public_id: publicId,
    timestamp: `${Math.floor(Date.now() / 1000)}`,
  };
  const toSign = Object.keys(params).sort().map((name) => `${name}=${params[name]}`).join('&');
  const form = new FormData();
  for (const [name, value] of Object.entries(params)) form.append(name, value);
  form.append('api_key', key);
  form.append('signature', createHash('sha1').update(toSign + secret).digest('hex'));
  form.append('file', new Blob([await readFile(join(dir, file))], { type: types[ext] }), file);
  const response = await fetch(`https://api.cloudinary.com/v1_1/${cloud}/image/upload`, {
    method: 'POST',
    body: form,
  });
  const body = await response.json();
  console.log(response.ok ? `uploaded ${body.public_id}` : `failed ${publicId}: ${body.error?.message}`);
}
