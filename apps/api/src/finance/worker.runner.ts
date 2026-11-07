import { Controller, Get, Injectable, Logger, OnApplicationShutdown } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Worker } from 'bullmq';
import { FinanceService } from './finance.service.js';
import { financeQueues, type FinanceJobData, type FinanceQueue } from './finance.queue.js';

@Controller('health')
export class WorkerHealthController {
  @Get()
  getHealth(): { status: string } {
    return { status: 'ok' };
  }
}

@Injectable()
export class WorkerRunner implements OnApplicationShutdown {
  private readonly logger = new Logger(WorkerRunner.name);
  private readonly workers: Worker[] = [];

  constructor(
    private readonly config: ConfigService,
    private readonly finance: FinanceService,
  ) {}

  start(): void {
    const url = this.config.get<string>('REDIS_URL')?.trim();
    if (!url) {
      this.logger.warn('REDIS_URL is not set. This worker is idle.');
      return;
    }
    for (const name of financeQueues) {
      const worker = new Worker(name, async (job) => {
        const data = job.data as FinanceJobData;
        await this.finance.processQueued(name as FinanceQueue, data.jobId, data.userId, data.days);
      }, {
        connection: { url, maxRetriesPerRequest: null },
        concurrency: 2,
      });
      worker.on('failed', (job, error) => {
        this.logger.warn(`Job ${job?.id ?? 'unknown'} on ${name} failed for ${String(job?.data?.userId ?? '')}: ${error.message}`);
      });
      this.workers.push(worker);
    }
    this.logger.log('Finance queues are listening');
  }

  async onApplicationShutdown(): Promise<void> {
    await Promise.all(this.workers.map((worker) => worker.close()));
  }
}
