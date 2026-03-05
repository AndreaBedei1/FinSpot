import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Param,
  Body,
  Query,
  UseGuards,
  Request,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { execFile } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';
import sharp from 'sharp';
import { SightingsService } from './sightings.service';
import { CreateSightingDto } from './dto/create-sighting.dto';
import { QuerySightingsDto } from './dto/query-sightings.dto';
import { UpdateSightingDto } from './dto/update-sighting.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { PrismaService } from '../prisma.service';

@UseGuards(JwtAuthGuard)
@Controller('sightings')
export class SightingsController {
  constructor(
    private readonly service: SightingsService,
    private readonly prisma: PrismaService,
  ) {}

  @Post(':id/recognition')
  async recognize(@Param('id') id: string): Promise<any> {
    const sightingId = Number(id);

    const dir = path.join(process.cwd(), 'uploads', 'temp', `${Date.now()}`);
    fs.mkdirSync(dir, { recursive: true });

    try {
      const images = await this.prisma.sightingImage.findMany({
        where: { sightingId },
        include: { annotations: true },
      });

      if (!images || images.length === 0) {
        throw new HttpException(
          { state: false, error: 'Nessuna immagine disponibile per il riconoscimento' },
          HttpStatus.BAD_REQUEST,
        );
      }

      let exportedCount = 0;

      for (const img of images) {
        const normalizedPath = img.url.replace(/^\/+/, '');
        const srcPath = path.join(process.cwd(), normalizedPath);

        if (!fs.existsSync(srcPath)) {
          continue;
        }

        const baseName = path.basename(srcPath, path.extname(srcPath));

        if (!img.annotations || img.annotations.length === 0) {
          const dstName = `${baseName}-${Date.now()}.jpg`;
          fs.copyFileSync(srcPath, path.join(dir, dstName));
          exportedCount += 1;
          continue;
        }

        const metadata = await sharp(srcPath).metadata();
        const width = metadata.width || 0;
        const height = metadata.height || 0;

        for (const ann of img.annotations) {
          const x1 = Math.max(0, Math.min(width, ann.tl_x));
          const y1 = Math.max(0, Math.min(height, ann.tl_y));
          const x2 = Math.max(0, Math.min(width, ann.br_x));
          const y2 = Math.max(0, Math.min(height, ann.br_y));

          const w = Math.max(1, Math.abs(x2 - x1));
          const h = Math.max(1, Math.abs(y2 - y1));
          if (w <= 1 || h <= 1) {
            continue;
          }

          const dstName = `${baseName}-${Date.now()}-${ann.id}.jpg`;
          await sharp(srcPath)
            .extract({
              left: Math.min(x1, x2),
              top: Math.min(y1, y2),
              width: w,
              height: h,
            })
            .toFile(path.join(dir, dstName));
          exportedCount += 1;
        }
      }

      if (exportedCount === 0) {
        throw new HttpException(
          { state: false, error: 'Nessuna immagine valida disponibile per il riconoscimento' },
          HttpStatus.BAD_REQUEST,
        );
      }

      const stdout = await new Promise<string>((resolve, reject) => {
        execFile(path.join(process.cwd(), 'bash.sh'), [dir], (error, out, stderr) => {
          if (error) {
            reject(
              new HttpException(
                { state: false, error: stderr || error.message },
                HttpStatus.INTERNAL_SERVER_ERROR,
              ),
            );
            return;
          }
          resolve(out.toString().trim());
        });
      });

      let ris: string[] = [];
      if (stdout.includes('Risultato:')) {
        ris = stdout
          .split('Risultato: ')[1]
          .split('-')
          .map((r) => r.trim())
          .filter((r) => r);
        ris = [...new Set(ris)];
      }

      return { state: true, data: ris };
    } finally {
      fs.rmSync(dir, { recursive: true, force: true });
    }
  }

  @Post()
  create(@Body() dto: CreateSightingDto, @Request() req) {
    return this.service.create(dto, req.user.userId);
  }

  @Get()
  findAll(@Query() q: QuerySightingsDto) {
    return this.service.findAll(q);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.service.findOne(Number(id));
  }

  @Put(':id')
  update(@Param('id') id: string, @Body() dto: UpdateSightingDto, @Request() req) {
    return this.service.update(Number(id), dto, req.user.userId);
  }

  @Delete(':id')
  remove(@Param('id') id: string, @Request() req) {
    return this.service.softDelete(Number(id), req.user.userId);
  }
}
