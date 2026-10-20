import { HealthController } from './health.controller.js';
import type { StatusService } from './status.service.js';

describe('HealthController', () => {
  it('returns ok', () => {
    const controller = new HealthController({} as StatusService);
    expect(controller.getHealth()).toEqual({ status: 'ok' });
  });
});
