import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Post,
  Put,
  Request,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { UsersService } from './users.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname } from 'path';
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

@UseGuards(JwtAuthGuard)
@Controller('users')
export class UsersController {
  constructor(private readonly service: UsersService) {}

  @Get('me')
  async getMe(@Request() req) {
    return this.service.findById(req.user.userId); // ✅ ora coerente
  }

  @Put('me')
  async updateProfile(
    @Request() req,
    @Body() body: { firstName?: string; lastName?: string },
  ) {
    return this.service.updateProfile(req.user.userId, body); // ✅
  }

  @Put('change-password')
  async changePassword(
    @Request() req,
    @Body() body: { oldPassword: string; newPassword: string },
  ) {
    return this.service.changePassword(
      req.user.userId,
      body.oldPassword,
      body.newPassword,
    ); // ✅
  }

  @Post('upload-avatar')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: './uploads/avatars',
        filename: (req, file, cb) => {
          const uniqueName = `${Date.now()}-${Math.round(
            Math.random() * 1e9,
          )}${extname(file.originalname)}`;
          cb(null, uniqueName);
        },
      }),
      fileFilter: imageFileFilter,
      limits: { fileSize: 5 * 1024 * 1024 },
    }),
  )
  async uploadAvatar(@Request() req, @UploadedFile() file: Express.Multer.File) {
    const converted = await convertUploadedImageToWebp(file, 'avatars');

    const imgUrl = `${
      process.env.APP_URL || 'https://isi-finspot.csr.unibo.it'
    }${converted.relativeUrl}`;
    await this.service.updateAvatar(req.user.userId, imgUrl); // ✅
    return { imgUrl };
  }
}
