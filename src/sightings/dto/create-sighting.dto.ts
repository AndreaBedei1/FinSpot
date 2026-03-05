import { IsInt, IsNumber, IsOptional, IsString, IsDateString, Min } from 'class-validator';

export class CreateSightingDto {
  @IsDateString()
  date: string; // ISO string

  @IsInt() @Min(1)
  specimens: number;

  @IsOptional() @IsString()
  wind?: string;

  @IsOptional() @IsString()
  sea?: string;

  @IsOptional() @IsString()
  notes?: string;

  @IsNumber()
  latitude: number;

  @IsNumber()
  longitude: number;

  @IsInt()
  animalId: number;

  @IsOptional() @IsInt()
  speciesId?: number;
}
