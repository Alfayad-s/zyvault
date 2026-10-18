import { BadRequestException } from '@nestjs/common';
import { readBillImage } from './bill.js';

describe('readBillImage', () => {
  const jpeg = 'A'.repeat(40);

  it('accepts a jpeg and a data URL', () => {
    expect(readBillImage(jpeg, 'image/jpeg')).toEqual({ mimeType: 'image/jpeg', data: jpeg });
    expect(readBillImage(`data:application/pdf;base64,${jpeg}`)?.mimeType).toBe('application/pdf');
  });

  it('rejects a missing type and a huge payload', () => {
    expect(() => readBillImage(jpeg)).toThrow(BadRequestException);
    expect(() => readBillImage('A'.repeat(8_000_001), 'image/png')).toThrow(BadRequestException);
  });
});
