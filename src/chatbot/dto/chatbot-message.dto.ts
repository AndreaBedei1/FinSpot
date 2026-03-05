import { Transform, Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

const trimString = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;

export class ChatbotMessageDto {
  @Transform(trimString)
  @IsString()
  @MinLength(1)
  @MaxLength(1200)
  message: string;

  @IsOptional()
  @Transform(trimString)
  @IsString()
  @MaxLength(80)
  conversationId?: string;

  @IsOptional()
  @Transform(trimString)
  @IsString()
  @MaxLength(120)
  speciesHint?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  sightingId?: number;
}
