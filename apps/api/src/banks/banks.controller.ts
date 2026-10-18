import { Controller, Get } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { banks, logoUrl, markUrl } from './banks.js';

@Controller('banks')
export class BanksController {
  constructor(private readonly config: ConfigService) {}

  @Get()
  list() {
    const cloud = this.config.get<string>('CLOUDINARY_CLOUD_NAME');
    return banks.map((bank) => ({
      id: bank.id,
      name: bank.name,
      short: bank.short,
      color: bank.color,
      logoUrl: cloud ? logoUrl(cloud, bank.id) : null,
      markUrl: cloud ? markUrl(cloud, bank) : null,
    }));
  }
}
