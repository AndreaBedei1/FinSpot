import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma.service';

@Injectable()
export class AnimalsService {
  constructor(private prisma: PrismaService) {}

  async findAll() {
    return this.prisma.animal.findMany({
      orderBy: { name: 'asc' },
    });
  }
}
