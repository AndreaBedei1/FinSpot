import {
  BadRequestException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { PrismaService } from '../prisma.service';
import * as bcrypt from 'bcrypt';

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

    async findById(id: number) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      select: {
        id: true,
        email: true,
        firstName: true,
        lastName: true,
        img: true,
        active: true,
        createdAt: true,
      },
    });

    if (!user) return null;

    const baseUrl = process.env.APP_URL || 'https://isi-finspot.csr.unibo.it';

    return {
      ...user,
      img: user.img
        ? user.img
        : `${baseUrl}/uploads/avatars/profile.webp`,
    };
  }

  async updateProfile(id: number, data: { firstName?: string; lastName?: string }) {
    return this.prisma.user.update({
      where: { id },
      data,
    });
  }

  async changePassword(userId: number, oldPassword: string, newPassword: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        password: true, // 👈 necessario per il confronto
      },
    });

    if (!user) {
      throw new NotFoundException('Utente non trovato');
    }

    const isValid = await bcrypt.compare(oldPassword, user.password);
    if (!isValid) {
      throw new UnauthorizedException('Password attuale non corretta');
    }

    if (newPassword.length < 6) {
      throw new BadRequestException(
        'La nuova password deve contenere almeno 6 caratteri',
      );
    }

    const hashed = await bcrypt.hash(newPassword, 10);
    return this.prisma.user.update({
      where: { id: userId },
      data: { password: hashed },
      select: { id: true, email: true },
    });
  }

  async updateAvatar(id: number, imgUrl: string) {
    return this.prisma.user.update({
      where: { id },
      data: { img: imgUrl },
    });
  }
}
