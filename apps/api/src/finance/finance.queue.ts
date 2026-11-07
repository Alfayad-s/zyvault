import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Queue } from 'bullmq';

export const financeQueues = [
  'financial-analysis',
  'cash-flow-forecast',
  'ai-insights',
  'spending-analysis',
  'scheduled-reports',
] as const;

export type FinanceQueue = (typeof financeQueues)[number];

export type FinanceJobData = {
  jobId: string;
  userId: string;
  days?: number;
};

@Injectable()
export class FinanceQueueClient {
  private readonly logger = new Logger(FinanceQueueClient.name);
  private readonly queues = new Map<FinanceQueue, Queue>();
  private readonly url: string | null;

  constructor(config: ConfigService) {
    this.url = config.get<string>('REDIS_URL')?.trim() || null;
  }

  enabled(): boolean {
    return this.url != null;
  }

  async enqueue(name: FinanceQueue, data: FinanceJobData): Promise<boolean> {
    if (!this.url) return false;
    try {
      const queue = this.queue(name);
      await queue.add(name, data, {
        attempts: 3,
        backoff: { type: 'exponential', delay: 2000 },
        removeOnComplete: { age: 24 * 60 * 60 },
        removeOnFail: false,
      });
      return true;
    } catch (caught) {
      this.logger.warn(`Could not enqueue ${name} for ${data.userId}`);
      return false;
    }
  }

  private queue(name: FinanceQueue): Queue {
    const existing = this.queues.get(name);
    if (existing) return existing;
    const created = new Queue(name, {
      connection: { url: this.url ?? '', maxRetriesPerRequest: null },
    });
    this.queues.set(name, created);
    return created;
  }
}
