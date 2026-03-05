import { BadRequestException } from '@nestjs/common';
import { promises as fs } from 'fs';
import { extname, join, parse } from 'path';
import sharp from 'sharp';

type ConvertToWebpResult = {
  filename: string;
  relativeUrl: string;
};

export async function convertUploadedImageToWebp(
  file: Express.Multer.File,
  uploadsSubdir: string,
): Promise<ConvertToWebpResult> {
  if (!file) {
    throw new BadRequestException('File non valido');
  }

  const sourceFilename = file.filename;
  const sourceExt = extname(sourceFilename).toLowerCase();
  const sourcePath =
    file.path || join(process.cwd(), 'uploads', uploadsSubdir, sourceFilename);
  const targetFilename = `${parse(sourceFilename).name}.webp`;
  const targetPath = join(process.cwd(), 'uploads', uploadsSubdir, targetFilename);

  if (sourceExt === '.webp') {
    if (sourceFilename !== targetFilename) {
      await fs.rename(sourcePath, targetPath);
    }

    return {
      filename: targetFilename,
      relativeUrl: `/uploads/${uploadsSubdir}/${targetFilename}`,
    };
  }

  try {
    await sharp(sourcePath).rotate().webp({ quality: 82 }).toFile(targetPath);
    await fs.unlink(sourcePath);
  } catch {
    throw new BadRequestException('Impossibile elaborare il file immagine');
  }

  return {
    filename: targetFilename,
    relativeUrl: `/uploads/${uploadsSubdir}/${targetFilename}`,
  };
}
