import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Redis } from 'ioredis';

@Injectable()
export class FinanceCache {
  private readonly redis: Redis | null;
  private readonly memory = new Map<string, { value: string; expires: number }>();

  constructor(config: ConfigService) {
    const url = config.get<string>('REDIS_URL')?.trim();
    this.redis = url ? new Redis(url, { maxRetriesPerRequest: 2, lazyConnect: true, enableOfflineQueue: false }) : null;
  }

  async get(userId: string, name: string): Promise<string | null> {
    const key = this.key(userId, name);
    if (!this.redis) return this.memoryGet(key);
    try {
      return await this.redis.get(key);
    } catch {
      return this.memoryGet(key);
    }
  }

  async set(userId: string, name: string, value: string, ttlSeconds: number): Promise<void> {
    const key = this.key(userId, name);
    this.memory.set(key, { value, expires: Date.now() + ttlSeconds * 1000 });
    if (!this.redis) return;
    try {
      await this.redis.set(key, value, 'EX', ttlSeconds);
    } catch {
      // The response is already stored in memory for this process.
    }
  }

  async invalidate(userId: string): Promise<void> {
    const prefix = `fin:${userId}:`;
    for (const key of this.memory.keys()) {
      if (key.startsWith(prefix)) this.memory.delete(key);
    }
    if (!this.redis) return;
    try {
      const keys = await this.redis.keys(`${prefix}*`);
      if (keys.length > 0) await this.redis.del(...keys);
    } catch {
      // A short TTL still drops a stale dashboard.
    }
  }

  async allow(userId: string, action: string, limit: number, windowSeconds: number): Promise<boolean> {
    const key = `fin:${userId}:rate:${action}`;
    if (this.redis) {
      try {
        const count = await this.redis.incr(key);
        if (count === 1) await this.redis.expire(key, windowSeconds);
        return count <= limit;
      } catch {
        // Fall through to the process memory counter.
      }
    }
    const current = Number(this.memoryGet(key) ?? '0') + 1;
    this.memory.set(key, { value: String(current), expires: Date.now() + windowSeconds * 1000 });
    return current <= limit;
  }

  private key(userId: string, name: string): string {
    return `fin:${userId}:${name}`;
  }

  private memoryGet(key: string): string | null {
    const row = this.memory.get(key);
    if (!row) return null;
    if (row.expires <= Date.now()) {
      this.memory.delete(key);
      return null;
    }
    return row.value;
  }
}
