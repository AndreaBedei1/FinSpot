import { Controller, Get, Query } from '@nestjs/common';
import { SpeciesService } from './species.service';

@Controller('species')
export class SpeciesController {
  constructor(private readonly service: SpeciesService) {}

  @Get()
  findByAnimal(@Query('animalId') animalId?: string) {
    if (animalId) {
      return this.service.findByAnimalId(Number(animalId));
    }
    return this.service.findAll();
  }
}
