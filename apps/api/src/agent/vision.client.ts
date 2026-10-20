import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { BillImage } from './llm.client.js';

const readable = new Set(['image/jpeg', 'image/png', 'image/webp', 'application/pdf']);
const textLimit = 12_000;

type Page = {
  fullTextAnnotation?: { text?: string };
  error?: { message?: string };
};

type AnnotateBody = {
  error?: { message?: string };
  responses?: (Page & { responses?: Page[] })[];
};

@Injectable()
export class VisionClient {
  private readonly logger = new Logger(VisionClient.name);

  constructor(private readonly config: ConfigService) {}

  configured(): boolean {
    return Boolean(this.config.get<string>('GOOGLE_CLOUD_VISION_API_KEY')?.trim());
  }

  /** Printed words from a photo or the first five PDF pages. Empty when this file type is not sent. */
  async read(image: BillImage): Promise<string> {
    const key = this.config.get<string>('GOOGLE_CLOUD_VISION_API_KEY')?.trim();
    if (!key || !readable.has(image.mimeType)) return '';
    const pdf = image.mimeType === 'application/pdf';
    const response = await fetch(`https://vision.googleapis.com/v1/${pdf ? 'files' : 'images'}:annotate`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-goog-api-key': key },
      body: JSON.stringify(
        pdf
          ? {
              requests: [
                {
                  inputConfig: { mimeType: image.mimeType, content: image.data },
                  features: [{ type: 'DOCUMENT_TEXT_DETECTION' }],
                  pages: [1, 2, 3, 4, 5],
                },
              ],
            }
          : {
              requests: [
                {
                  image: { content: image.data },
                  features: [{ type: 'DOCUMENT_TEXT_DETECTION' }],
                },
              ],
            },
      ),
      signal: AbortSignal.timeout(20_000),
    });
    const body = (await response.json().catch(() => null)) as AnnotateBody | null;
    if (!response.ok || body?.error?.message) {
      this.logger.warn(`Cloud Vision answered ${response.status}`);
      throw new ServiceUnavailableException('Cloud Vision could not read that bill');
    }
    return clip(pdf ? pages(body) : body?.responses?.[0]?.fullTextAnnotation?.text ?? '');
  }
}

function pages(body: AnnotateBody | null): string {
  const batch = body?.responses?.[0];
  if (batch?.error?.message) {
    throw new ServiceUnavailableException('Cloud Vision could not read that bill');
  }
  const sheets = batch?.responses ?? [];
  const text = sheets
    .map((page) => page.fullTextAnnotation?.text?.trim() ?? '')
    .filter((page) => page.length > 0)
    .join('\n');
  if (!text && sheets.some((page) => page.error?.message)) {
    throw new ServiceUnavailableException('Cloud Vision could not read that bill');
  }
  return text;
}

function clip(text: string): string {
  const cleaned = text.replace(/\s+\n/g, '\n').trim();
  return cleaned.length <= textLimit ? cleaned : cleaned.slice(0, textLimit);
}
