import { IsOptional, IsString, MinLength, Matches } from 'class-validator';
import { ValidateIf } from 'class-validator';

export class UpdateUserDto {
  @IsOptional()
  @IsString()
  firstName?: string;

  @IsOptional()
  @IsString()
  lastName?: string;

  @IsOptional()
  @IsString()
  img?: string; // URL immagine salvata in uploads

  @IsOptional()
  @IsString()
  @MinLength(8, { message: 'La password deve contenere almeno 8 caratteri' })
  @Matches(/(?=.*[A-Z])/, { message: 'La password deve contenere almeno una lettera maiuscola' })
  @Matches(/(?=.*\d)/, { message: 'La password deve contenere almeno un numero' })
  @Matches(/(?=.*[@$!%*?&])/, { message: 'La password deve contenere almeno un carattere speciale' })
  password?: string;

  @ValidateIf((o) => o.password !== undefined)
  @IsString()
  confirmPassword?: string;
}
