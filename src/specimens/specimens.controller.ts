// specimens.controller.ts
import { Controller, Get, Post, Delete, Param, Body, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { SpecimensService } from './specimens.service';

@UseGuards(JwtAuthGuard)
@Controller('specimens')
export class SpecimensController {
  constructor(private readonly service: SpecimensService) {}

  @Get()
  findAll() {
    return this.service.findAll();
  }

  @Post()
  create(@Body() body: { name: string }) {
    return this.service.create(body.name);
  }

  @Post(':id/wounds')
  addWound(@Param('id') specimenId: string, @Body() body: { type: string; severity: string }) {
    return this.service.addWound(Number(specimenId), body);
  }

  @Delete('wounds/:woundId')
  removeWound(@Param('woundId') woundId: string) {
    return this.service.removeWound(Number(woundId));
  }
}
