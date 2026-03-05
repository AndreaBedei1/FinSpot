import { Controller, Get, Param, NotFoundException } from '@nestjs/common';
import { SpeciesInfoService } from './species-info.service';

@Controller('species-info')
export class SpeciesInfoController {
  constructor(private readonly service: SpeciesInfoService) {}

  @Get(':scientificName')
  async getInfo(@Param('scientificName') scientificName: string) {
    const info = await this.service.findByScientificName(scientificName);
    if (!info) throw new NotFoundException('Informazioni non trovate');
    return info;
  }
}
