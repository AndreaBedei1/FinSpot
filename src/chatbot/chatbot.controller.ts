import { Body, Controller, Post, Request, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ChatbotService } from './chatbot.service';
import { ChatbotMessageDto } from './dto/chatbot-message.dto';
import { ChatbotResetDto } from './dto/chatbot-reset.dto';

@UseGuards(JwtAuthGuard)
@Controller('chatbot')
export class ChatbotController {
  constructor(private readonly chatbotService: ChatbotService) {}

  @Post('message')
  async sendMessage(@Body() dto: ChatbotMessageDto, @Request() req: any) {
    return this.chatbotService.ask(req.user.userId, dto);
  }

  @Post('reset')
  async resetConversation(@Body() dto: ChatbotResetDto, @Request() req: any) {
    return this.chatbotService.reset(req.user.userId, dto.conversationId);
  }
}
