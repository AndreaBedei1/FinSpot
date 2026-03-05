import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma.service';
import { CreateSightingDto } from './dto/create-sighting.dto';
import { QuerySightingsDto } from './dto/query-sightings.dto';
import { UpdateSightingDto } from './dto/update-sighting.dto';

@Injectable()
export class SightingsService {
  constructor(private prisma: PrismaService) {}

  async create(dto: CreateSightingDto, userId: number) {
    return this.prisma.sighting.create({
      data: {
        date: new Date(dto.date),
        specimens: dto.specimens,
        wind: dto.wind,
        sea: dto.sea,
        notes: dto.notes,
        latitude: dto.latitude,
        longitude: dto.longitude,
        userId,
        animalId: dto.animalId,
        speciesId: dto.speciesId ?? null,
      },
      include: { animal: true, species: true, user: { select: { id: true, email: true } } },
    });
  }

  async findAll(q: QuerySightingsDto) {
    const where: any = { deleted: false };
    if (q.fromDate) where.date = { ...where.date, gte: new Date(q.fromDate) };
    if (q.toDate)   where.date = { ...where.date, lte: new Date(q.toDate) };
    if (q.animalId) where.animalId = q.animalId;
    if (q.speciesId) where.speciesId = q.speciesId;

    const take = q.take ? Number(q.take) : 100;
    const skip = q.skip ? Number(q.skip) : 0;

    const [items, total] = await this.prisma.$transaction([
      this.prisma.sighting.findMany({
        where,
        orderBy: { date: 'desc' },
        take, skip,
        include: {
          animal: true,
          species: true,
          user: { select: { id: true, email: true } },
        },
      }),
      this.prisma.sighting.count({ where }),
    ]);

    return { items, total, take, skip };
  }

  async findOne(id: number) {
    const sighting = await this.prisma.sighting.findFirst({
      where: { id, deleted: false },
      include: {
        user: {
          select: {
            id: true,
            email: true,
            firstName: true,
            lastName: true,
            img: true,
          },
        },
        animal: true,
        species: { include: { info: true } },
      },
    });
    if (!sighting) {
      throw new NotFoundException('Avvistamento non trovato');
    }
    return sighting;
  }

  private async ensureSightingExists(id: number) {
    const sighting = await this.prisma.sighting.findFirst({
      where: { id, deleted: false },
      select: { id: true },
    });

    if (!sighting) {
      throw new NotFoundException('Avvistamento non trovato');
    }
  }

  async update(id: number, data: UpdateSightingDto, _actorUserId: number) {
    await this.ensureSightingExists(id);

    const updateData: {
      animalId?: number;
      speciesId?: number | null;
      sea?: string;
      wind?: string;
      notes?: string;
    } = {};
    if (data.animalId !== undefined) updateData.animalId = data.animalId;
    if (data.speciesId !== undefined) updateData.speciesId = data.speciesId;
    if (data.sea !== undefined) updateData.sea = data.sea;
    if (data.wind !== undefined) updateData.wind = data.wind;
    if (data.notes !== undefined) updateData.notes = data.notes;

    return this.prisma.sighting.update({
      where: { id },
      data: updateData,
      include: {
        animal: true,
        species: true,
        user: { select: { id: true, email: true } },
      },
    });
  }

  async softDelete(id: number, _actorUserId: number) {
    await this.ensureSightingExists(id);

    return this.prisma.sighting.update({
      where: { id },
      data: { deleted: true },
    });
  }
}
