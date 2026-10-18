import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { CommitSpendDto } from './dto/commit-spend.dto.js';

const accountId = '6f1c2b1e-8a4d-4c3b-9e2f-1a2b3c4d5e6f';
const categoryId = '7a2d3c4b-1e5f-4a6b-8c7d-9e0f1a2b3c4d';

function errors(body: unknown) {
  const dto = plainToInstance(CommitSpendDto, body);
  return validate(dto, { whitelist: true, forbidNonWhitelisted: true });
}

describe('CommitSpendDto', () => {
  it('accepts reviewed entries with a schedule, a loan and a goal', async () => {
    const result = await errors({
      accountId,
      today: '2026-10-18',
      items: [
        { amount: 20000, kind: 'expense', categoryId, occurredOn: '2026-10-18', note: 'lunch' },
        {
          amount: 3500000,
          kind: 'income',
          categoryId,
          occurredOn: '2026-11-01',
          schedule: { repeat: 'monthly', dayOfMonth: 1, nextOn: '2026-11-01' },
        },
        { amount: 50000, kind: 'expense', categoryId, occurredOn: '2026-10-18', debt: { type: 'lent', person: 'Ravi' } },
        { amount: 150000, kind: 'expense', categoryId, occurredOn: '2026-10-18', goal: { name: 'Goa trip', action: 'add' } },
      ],
    });
    expect(result).toEqual([]);
  });

  it('rejects an empty list, a zero amount and a made-up loan type', async () => {
    expect(await errors({ accountId, today: '2026-10-18', items: [] })).not.toEqual([]);
    const [bad] = await errors({
      accountId,
      today: '2026-10-18',
      items: [
        { amount: 0, kind: 'expense', categoryId, occurredOn: '2026-10-18', debt: { type: 'gift', person: 'Ravi' } },
      ],
    });
    expect(bad.property).toBe('items');
  });
});
