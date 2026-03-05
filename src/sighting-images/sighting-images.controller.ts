import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Request,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname } from 'path';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { SightingImagesService } from './sighting-images.service';
import { convertUploadedImageToWebp } from '../utils/image-upload.utils';

const imageFileFilter = (
  req: Express.Request,
  file: Express.Multer.File,
  cb: (error: Error | null, acceptFile: boolean) => void,
) => {
  if (!file.mimetype.startsWith('image/')) {
    return cb(new BadRequestException('Sono consentiti solo file immagine'), false);
  }
  cb(null, true);
};

@Controller('sighting-images')
@UseGuards(JwtAuthGuard)
export class SightingImagesController {
  constructor(private readonly service: SightingImagesService) {}

  @Post(':sightingId/upload')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: './uploads/sightings',
        filename: (req, file, cb) => {
          const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
          cb(null, uniqueSuffix + extname(file.originalname));
        },
      }),
      fileFilter: imageFileFilter,
      limits: { fileSize: 10 * 1024 * 1024 },
    }),
  )
  async uploadImage(
    @Param('sightingId') sightingId: string,
    @Request() req,
    @UploadedFile() file: Express.Multer.File,
  ) {
    const converted = await convertUploadedImageToWebp(file, 'sightings');

    return this.service.addImage(Number(sightingId), converted.filename, req.user.userId);
  }

  @Get(':sightingId/images')
  async getImages(@Param('sightingId') sightingId: string) {
    return this.service.getImagesBySighting(Number(sightingId));
  }

  @Delete(':id')
  async deleteImage(@Param('id') id: string, @Request() req) {
    return this.service.deleteImage(Number(id), req.user.userId);
  }

  @Post(':imageId/annotations')
  async addAnnotation(
    @Param('imageId') imageId: string,
    @Request() req,
    @Body()
    body: { tl_x: number; tl_y: number; br_x: number; br_y: number; specimenName?: string },
  ) {
    return this.service.addAnnotation(Number(imageId), body, req.user.userId);
  }
}
