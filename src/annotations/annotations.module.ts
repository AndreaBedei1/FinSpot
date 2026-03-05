import { Module } from '@nestjs/common';
import { AnnotationsController } from './annotations.controller';
import { AnnotationsService } from './annotations.service';
import { PrismaService } from '../prisma.service';

@Module({
  controllers: [AnnotationsController],
  providers: [AnnotationsService, PrismaService],
  exports: [AnnotationsService],
})
export class AnnotationsModule {}
