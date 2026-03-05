import { Controller, Patch, Delete, Param, Body, UseGuards, Request } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AnnotationsService } from './annotations.service';

@UseGuards(JwtAuthGuard)
@Controller('annotations')
export class AnnotationsController {
  constructor(private readonly service: AnnotationsService) {}

  @Patch(':id')
  update(
    @Param('id') id: string,
    @Request() req,
    @Body()
    body: { specimenName?: string; tl_x?: number; tl_y?: number; br_x?: number; br_y?: number },
  ) {
    return this.service.update(Number(id), body, req.user.userId);
  }

  @Delete(':id')
  delete(@Param('id') id: string, @Request() req) {
    return this.service.delete(Number(id), req.user.userId);
  }
}
