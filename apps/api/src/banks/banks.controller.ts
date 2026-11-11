import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Post,
  UploadedFiles,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileFieldsInterceptor } from '@nestjs/platform-express';
import type { AuthUser } from '../auth/auth-user.js';
import { AuthGuard } from '../auth/auth.guard.js';
import { CurrentUser } from '../auth/current-user.decorator.js';
import { BanksService, type UploadedImage } from './banks.service.js';

type IncomingFile = {
  mimetype: string;
  size: number;
  buffer: Buffer;
  originalname: string;
};

@Controller('banks')
export class BanksController {
  constructor(private readonly banks: BanksService) {}

  @Get()
  list() {
    return this.banks.list();
  }

  @Post()
  @UseGuards(AuthGuard)
  @UseInterceptors(
    FileFieldsInterceptor(
      [
        { name: 'logo', maxCount: 1 },
        { name: 'mark', maxCount: 1 },
      ],
      { limits: { fileSize: 2 * 1024 * 1024 } },
    ),
  )
  create(
    @CurrentUser() user: AuthUser,
    @Body('name') name: string | string[] | undefined,
    @UploadedFiles() files: { logo?: IncomingFile[]; mark?: IncomingFile[] },
  ) {
    const logo = files?.logo?.[0];
    const mark = files?.mark?.[0];
    return this.banks.create(user.id, first(name), fileOf(logo), fileOf(mark));
  }
}

function first(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value[0] : value;
}

function fileOf(file: IncomingFile | undefined): UploadedImage | undefined {
  if (!file) return undefined;
  if (!Buffer.isBuffer(file.buffer)) {
    throw new BadRequestException('Could not read that image');
  }
  return {
    mimetype: file.mimetype,
    buffer: file.buffer,
    size: file.size,
    originalname: file.originalname,
  };
}
