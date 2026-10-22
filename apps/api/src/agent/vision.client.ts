import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { linesFromWords, type PrintedLine } from './bill-items.js';
import type { BillImage } from './llm.client.js';

const readable = new Set(['image/jpeg', 'image/png', 'image/webp', 'application/pdf']);
const textLimit = 12_000;

type Word = {
  symbols?: { text?: string }[];
  boundingBox?: { vertices?: { x?: number; y?: number }[] };
};

type Page = {
  fullTextAnnotation?: {
    text?: string;
    pages?: { blocks?: { paragraphs?: { words?: Word[] }[] }[] }[];
  };
  error?: { message?: string };
};

export type VisionRead = { text: string; lines: string[] };

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

  /** Printed words from a photo or up to maxPages PDF pages. Empty when this file type is not sent. */
  async read(image: BillImage, maxPages = 5): Promise<VisionRead> {
    const key = this.config.get<string>('GOOGLE_CLOUD_VISION_API_KEY')?.trim();
    if (!key || !readable.has(image.mimeType)) return { text: '', lines: [] };
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
                  pages: Array.from({ length: Math.min(Math.max(maxPages, 1), 15) }, (_, index) => index + 1),
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
    return readOf(pdf ? pdfPages(body) : [body?.responses?.[0]]);
  }
}

function pdfPages(body: AnnotateBody | null): (Page | undefined)[] {
  const batch = body?.responses?.[0];
  if (batch?.error?.message) {
    throw new ServiceUnavailableException('Cloud Vision could not read that bill');
  }
  return batch?.responses ?? [];
}

function readOf(sheets: (Page | undefined)[]): VisionRead {
  const text = clip(
    sheets
      .map((page) => page?.fullTextAnnotation?.text?.trim() ?? '')
      .filter((page) => page.length > 0)
      .join('\n'),
  );
  if (!text && sheets.some((page) => page?.error?.message)) {
    throw new ServiceUnavailableException('Cloud Vision could not read that bill');
  }
  const words = sheets.flatMap((page) => wordsOn(page));
  const lines = words.length > 0 ? linesFromWords(words) : text.split('\n').map((line) => line.trim()).filter(Boolean);
  return { text, lines };
}

function wordsOn(page: Page | undefined): PrintedLine[] {
  const words: PrintedLine[] = [];
  for (const sheet of page?.fullTextAnnotation?.pages ?? []) {
    for (const block of sheet.blocks ?? []) {
      for (const paragraph of block.paragraphs ?? []) {
        for (const word of paragraph.words ?? []) {
          const text = (word.symbols ?? []).map((symbol) => symbol.text ?? '').join('');
          const vertices = word.boundingBox?.vertices ?? [];
          if (!text.trim() || vertices.length === 0) continue;
          const xs = vertices.map((point) => point.x ?? 0);
          const ys = vertices.map((point) => point.y ?? 0);
          const top = Math.min(...ys);
          const bottom = Math.max(...ys);
          words.push({
            text,
            x: Math.min(...xs),
            y: (top + bottom) / 2,
            height: Math.max(8, bottom - top),
            width: Math.max(8, Math.max(...xs) - Math.min(...xs)),
          });
        }
      }
    }
  }
  return words;
}

function clip(text: string): string {
  const cleaned = text.replace(/\s+\n/g, '\n').trim();
  return cleaned.length <= textLimit ? cleaned : cleaned.slice(0, textLimit);
}
