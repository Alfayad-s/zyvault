import { BadRequestException } from '@nestjs/common';
import { billMimeTypes } from './dto/parse-spend.dto.js';
import type { BillImage } from './llm.client.js';

const allowed = new Set<string>(billMimeTypes);

export function readBillImage(image?: string, mimeType?: string): BillImage | undefined {
  if (!image?.trim()) {
    return undefined;
  }
  let data = image.trim();
  let mime = mimeType;
  const dataUrl = data.match(/^data:([^;]+);base64,([\s\S]+)$/i);
  if (dataUrl) {
    mime = mime ?? dataUrl[1]?.toLowerCase();
    data = dataUrl[2] ?? '';
  }
  data = data.replace(/\s/g, '');
  if (!mime || !allowed.has(mime)) {
    throw new BadRequestException('Use a JPEG, PNG, WebP, HEIC, or PDF bill');
  }
  if (data.length < 32 || data.length > 8_000_000 || !/^[A-Za-z0-9+/]+={0,2}$/.test(data)) {
    throw new BadRequestException('That bill image is empty or too large');
  }
  return { mimeType: mime, data };
}
