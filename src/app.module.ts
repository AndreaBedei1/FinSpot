import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { SightingsModule } from './sightings/sightings.module';
import { AnimalsModule } from './animals/animals.module';
import { SpeciesModule } from './species/species.module';
import { SightingImagesModule } from './sighting-images/sighting-images.module';
import { SpecimensModule } from './specimens/specimens.module';
import { AnnotationsModule } from './annotations/annotations.module';
import { ChatbotModule } from './chatbot/chatbot.module';


@Module({
  imports: [
    AuthModule,
    UsersModule,
    SightingsModule,
    AnimalsModule,
    SpeciesModule,
    SightingImagesModule,
    SpecimensModule,
    AnnotationsModule,
    ChatbotModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
