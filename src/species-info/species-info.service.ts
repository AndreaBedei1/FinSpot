import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma.service';

@Injectable()
export class SpeciesInfoService {
  constructor(private prisma: PrismaService) {}

  async findByScientificName(scientificName: string) {
    return this.prisma.speciesInfo.findUnique({
      where: { scientificName },
    });
  }
}
