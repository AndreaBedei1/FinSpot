import { Module } from '@nestjs/common';
import { SpeciesController } from './species.controller';
import { SpeciesService } from './species.service';
import { PrismaService } from '../prisma.service';

@Module({
  controllers: [SpeciesController],
  providers: [SpeciesService, PrismaService],
  exports: [SpeciesService],
})
export class SpeciesModule {}
