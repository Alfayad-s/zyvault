import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { describe } from './llm.client.js';

const zeroShotTimeoutMs = 25_000;
const zeroShotUrl =
  'https://router.huggingface.co/hf-inference/models/facebook/bart-large-mnli';

export type ZeroShotLabel = { label: string; score: number };

@Injectable()
export class ZeroShotClient {
  private readonly logger = new Logger(ZeroShotClient.name);

  constructor(private readonly config: ConfigService) {}

  async classify(text: string, labels: readonly string[]): Promise<ZeroShotLabel> {
    const token = this.config.get<string>('HF_TOKEN');
    if (!token) {
      throw new ServiceUnavailableException('The AI categorizer is not configured');
    }
    let response: Response;
    try {
      response = await fetch(zeroShotUrl, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: `Bearer ${token}`,
          'x-wait-for-model': 'true',
        },
        body: JSON.stringify({
          inputs: text,
          parameters: { candidate_labels: labels },
        }),
        signal: AbortSignal.timeout(zeroShotTimeoutMs),
      });
    } catch (caught) {
      this.logger.warn(`Hugging Face request failed: ${describe(caught)}`);
      throw new ServiceUnavailableException('The AI categorizer did not answer in time');
    }
    if (!response.ok) {
      this.logger.warn(`Hugging Face answered ${response.status}`);
      throw new ServiceUnavailableException('The AI categorizer is warming up, try again');
    }
    return topLabel(await response.json());
  }
}

export function topLabel(body: unknown): ZeroShotLabel {
  if (Array.isArray(body)) {
    const best = (body as ZeroShotLabel[])
      .filter((item) => typeof item?.label === 'string' && typeof item?.score === 'number')
      .sort((a, b) => b.score - a.score)[0];
    if (best) {
      return best;
    }
  }
  if (body && typeof body === 'object') {
    const { labels, scores } = body as { labels?: string[]; scores?: number[] };
    if (labels?.length && scores?.length) {
      return { label: labels[0], score: scores[0] };
    }
  }
  throw new ServiceUnavailableException('The AI categorizer returned an unexpected reply');
}
