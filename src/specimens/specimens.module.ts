import { Module } from '@nestjs/common';
import { SpecimensController } from './specimens.controller';
import { SpecimensService } from './specimens.service';
import { PrismaService } from '../prisma.service';

@Module({
  controllers: [SpecimensController],
  providers: [SpecimensService, PrismaService],
  exports: [SpecimensService], // se servirà altrove
})
export class SpecimensModule {}
