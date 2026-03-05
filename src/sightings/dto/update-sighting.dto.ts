import { IsInt, IsOptional, IsString } from 'class-validator';

export class UpdateSightingDto {
  @IsOptional()
  @IsInt()
  animalId?: number;

  @IsOptional()
  @IsInt()
  speciesId?: number;

  @IsOptional()
  @IsString()
  sea?: string;

  @IsOptional()
  @IsString()
  wind?: string;

  @IsOptional()
  @IsString()
  notes?: string;
}
