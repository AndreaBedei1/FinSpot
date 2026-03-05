import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma.service';

@Injectable()
export class SpeciesService {
  constructor(private prisma: PrismaService) {}

  async findAll() {
    return this.prisma.species.findMany({
      orderBy: { name: 'asc' },
    });
  }

  async findByAnimalId(animalId: number) {
    return this.prisma.species.findMany({
      where: { animalId },
      orderBy: { name: 'asc' },
    });
  }
}
