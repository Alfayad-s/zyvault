import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { WorkerModule } from './worker.module.js';
import { WorkerRunner } from './finance/worker.runner.js';

async function bootstrap() {
  const app = await NestFactory.create(WorkerModule);
  app.enableShutdownHooks();
  const port = process.env.PORT ?? 3000;
  await app.listen(port, '0.0.0.0');
  app.get(WorkerRunner).start();
  Logger.log(`Finance worker listening on ${port}`, 'Worker');
}

await bootstrap();
