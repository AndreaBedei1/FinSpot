import { Module } from '@nestjs/common';
import { SightingsService } from './sightings.service';
import { SightingsController } from './sightings.controller';
import { PrismaService } from '../prisma.service';

@Module({
  controllers: [SightingsController],
  providers: [SightingsService, PrismaService],
})
export class SightingsModule {}
