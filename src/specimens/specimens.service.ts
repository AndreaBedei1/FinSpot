import { Injectable, HttpException, HttpStatus } from '@nestjs/common';
import { Prisma, PrismaClient } from '@prisma/client';
import { PrismaService } from '../prisma.service';

@Injectable()
export class SpecimensService {
  constructor(private prisma: PrismaService) {}

  findAll() {
    return this.prisma.specimen.findMany({
      include: { wounds: true },
    });
  }

  async create(name: string) {
    try {
      return await this.prisma.specimen.create({ data: { name } });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError) {
        if (error.code === 'P2002') {
          throw new HttpException(
            {
              statusCode: HttpStatus.CONFLICT,
              message: `Un esemplare con questo nome esiste già nel database.`,
            },
            HttpStatus.CONFLICT,
          );
        }
      }
      throw error;
    }
  }

  addWound(specimenId: number, body: { type: string; severity: string }) {
    return this.prisma.wound.create({
      data: { type: body.type, severity: body.severity, specimenId },
    });
  }

  removeWound(woundId: number) {
    return this.prisma.wound.delete({ where: { id: woundId } });
  }
}
