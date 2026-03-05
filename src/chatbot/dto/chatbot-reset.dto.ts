import { Transform } from 'class-transformer';
import { IsOptional, IsString, MaxLength } from 'class-validator';

const trimString = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;

export class ChatbotResetDto {
  @IsOptional()
  @Transform(trimString)
  @IsString()
  @MaxLength(80)
  conversationId?: string;
}
