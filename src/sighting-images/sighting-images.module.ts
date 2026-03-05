import { Module } from '@nestjs/common';
import { SightingImagesController } from './sighting-images.controller';
import { SightingImagesService } from './sighting-images.service';
import { PrismaService } from '../prisma.service';

@Module({
  controllers: [SightingImagesController],
  providers: [SightingImagesService, PrismaService],
})
export class SightingImagesModule {}
