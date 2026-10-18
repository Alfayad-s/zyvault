import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { AuthService } from './auth.service.js';
import { RefreshDto, SendCodeDto, VerifyCodeDto } from './dto/auth.dto.js';

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('email/code')
  @HttpCode(200)
  sendCode(@Body() body: SendCodeDto) {
    return this.auth.sendCode(body.email);
  }

  @Post('email/verify')
  @HttpCode(200)
  verifyCode(@Body() body: VerifyCodeDto) {
    return this.auth.verifyCode(body.email, body.code);
  }

  @Post('refresh')
  @HttpCode(200)
  refresh(@Body() body: RefreshDto) {
    return this.auth.refresh(body.refreshToken);
  }
}
