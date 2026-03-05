import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma.service';

@Injectable()
export class AnnotationsService {
  constructor(private prisma: PrismaService) {}

  private async getAnnotationOrThrow(id: number) {
    const annotation = await this.prisma.annotation.findUnique({
      where: { id },
      include: {
        image: {
          include: {
            sighting: {
              select: { userId: true, deleted: true },
            },
          },
        },
      },
    });

    if (!annotation || annotation.image.sighting.deleted) {
      throw new NotFoundException('Annotazione non trovata');
    }

    return annotation;
  }

  async update(
    id: number,
    body: { tl_x?: number; tl_y?: number; br_x?: number; br_y?: number; specimenName?: string },
    _actorUserId: number,
  ) {
    const annotation = await this.getAnnotationOrThrow(id);

    const data: {
      tl_x?: number;
      tl_y?: number;
      br_x?: number;
      br_y?: number;
      specimenId?: number | null;
    } = {};

    if (body.tl_x !== undefined) data.tl_x = body.tl_x;
    if (body.tl_y !== undefined) data.tl_y = body.tl_y;
    if (body.br_x !== undefined) data.br_x = body.br_x;
    if (body.br_y !== undefined) data.br_y = body.br_y;

    if (body.specimenName !== undefined) {
      const cleanedName = body.specimenName.trim();
      if (!cleanedName) {
        data.specimenId = null;
      } else {
        const specimen = await this.prisma.specimen.upsert({
          where: { name: cleanedName },
          update: {},
          create: { name: cleanedName },
        });
        data.specimenId = specimen.id;
      }
    }

    return this.prisma.annotation.update({
      where: { id },
      data,
      include: { specimen: true },
    });
  }

  async delete(id: number, _actorUserId: number) {
    await this.getAnnotationOrThrow(id);
    return this.prisma.annotation.delete({ where: { id } });
  }
}
