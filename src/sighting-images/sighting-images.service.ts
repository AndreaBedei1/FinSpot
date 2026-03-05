import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma.service';
import { Specimen } from '@prisma/client';
import * as fs from 'fs';
import { join } from 'path';

@Injectable()
export class SightingImagesService {
  constructor(private prisma: PrismaService) {}

  private async ensureSightingExists(sightingId: number) {
    const sighting = await this.prisma.sighting.findFirst({
      where: { id: sightingId, deleted: false },
      select: { id: true },
    });

    if (!sighting) {
      throw new NotFoundException('Avvistamento non trovato');
    }

    return sighting;
  }

  private async getImageOrThrow(imageId: number) {
    const image = await this.prisma.sightingImage.findUnique({
      where: { id: imageId },
      include: { sighting: { select: { id: true, deleted: true, userId: true } } },
    });

    if (!image || image.sighting.deleted) {
      throw new NotFoundException('Immagine non trovata');
    }

    return image;
  }

  // Salva record immagine
  async addImage(sightingId: number, filename: string, _actorUserId: number) {
    await this.ensureSightingExists(sightingId);

    const url = `/uploads/sightings/${filename}`;
    return this.prisma.sightingImage.create({
      data: {
        url,
        sightingId,
      },
    });
  }

  // Elimina record immagine
  async deleteImage(id: number, _actorUserId: number) {
    const image = await this.getImageOrThrow(id);

    const deleted = await this.prisma.sightingImage.delete({
      where: { id },
    });

    const imagePath = join(process.cwd(), image.url.replace(/^\/+/, ''));
    if (fs.existsSync(imagePath)) {
      fs.unlinkSync(imagePath);
    }

    return deleted;
  }

  async getImagesBySighting(sightingId: number) {
    return this.prisma.sightingImage.findMany({
      where: {
        sightingId,
        sighting: { deleted: false },
      },
      include: {
        annotations: {
          include: { specimen: true },
        },
      },
    });
  }

  // Aggiunge rettangolo di annotazione
  async addAnnotation(
    imageId: number,
    body: { tl_x: number; tl_y: number; br_x: number; br_y: number; specimenName?: string },
    _actorUserId: number,
  ) {
    await this.getImageOrThrow(imageId);

    const cleanedSpecimenName = body.specimenName?.trim();
    let specimen: Specimen | null = null;
    if (cleanedSpecimenName) {
      specimen = await this.prisma.specimen.upsert({
        where: { name: cleanedSpecimenName },
        update: {},
        create: { name: cleanedSpecimenName },
      });
    }

    return this.prisma.annotation.create({
      data: {
        tl_x: body.tl_x,
        tl_y: body.tl_y,
        br_x: body.br_x,
        br_y: body.br_y,
        imageId,
        specimenId: specimen ? specimen.id : null,
      },
    });
  }
}
