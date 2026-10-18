import { Transform } from 'class-transformer';
import { IsEmail, IsString, Matches, MinLength } from 'class-validator';

const normalizeEmail = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim().toLowerCase() : value;

export class SendCodeDto {
  @Transform(normalizeEmail)
  @IsEmail()
  email: string;
}

export class RefreshDto {
  @IsString()
  @MinLength(10)
  refreshToken: string;
}

export class VerifyCodeDto {
  @Transform(normalizeEmail)
  @IsEmail()
  email: string;

  @Transform(({ value }) => (typeof value === 'string' ? value.replace(/\s/g, '') : value))
  @Matches(/^\d{6,10}$/, { message: 'Enter the code from the email' })
  code: string;
}
