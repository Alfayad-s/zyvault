import { BadRequestException } from '@nestjs/common';
import { assertImage, BanksService, mergeBrands } from './banks.service.js';
import { brandShort, unknownBankMessage } from './banks.js';

describe('card brands', () => {
  it('makes a short label from the first word', () => {
    expect(brandShort('HDFC Millennia')).toBe('HDFC');
    expect(brandShort('***')).toBe('CARD');
  });

  it('rejects a file that is not an image', () => {
    expect(() =>
      assertImage(
        { mimetype: 'text/plain', buffer: Buffer.from('hi'), size: 2 },
        'logo only',
      ),
    ).toThrow(BadRequestException);
  });

  it('keeps built-in banks ahead of community cards and skips a duplicate name', () => {
    const merged = mergeBrands(
      [
        {
          id: 'hdfc',
          name: 'HDFC Bank',
          short: 'HDFC',
          color: '#004C8F',
          logoUrl: null,
          markUrl: null,
        },
      ],
      [
        {
          id: '1',
          name: 'hdfc bank',
          short: 'HDFC',
          logo_url: 'logo',
          mark_url: 'mark',
        },
        {
          id: '2',
          name: 'SBI Card',
          short: 'SBI',
          logo_url: 'wide',
          mark_url: 'round',
        },
      ],
    );
    expect(merged.map((bank) => bank.id)).toEqual(['hdfc', '2']);
    expect(merged[1]).toMatchObject({
      logoUrl: 'wide',
      markUrl: 'round',
      color: '#3A3A3C',
    });
  });

  it('returns the built-in bank when the name already exists', async () => {
    const service = new BanksService(
      {} as never,
      { get: () => 'demo' } as never,
    );
    const bank = await service.create(
      'user',
      '  HDFC Bank  ',
      undefined,
      undefined,
    );
    expect(bank.id).toBe('hdfc');
    expect(bank.logoUrl).toContain('/finance-track/bank-logos/hdfc');
  });

  it('accepts a built-in id or a saved community id', () => {
    expect(unknownBankMessage('credit', 'hdfc', false)).toBeNull();
    expect(
      unknownBankMessage(
        'credit',
        '11111111-1111-4111-8111-111111111111',
        true,
      ),
    ).toBeNull();
    expect(unknownBankMessage('credit', 'made-up', false)).toBe(
      'Pick a bank from the list',
    );
    expect(unknownBankMessage('cash', 'made-up', false)).toBeNull();
  });
});
