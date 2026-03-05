import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ChildProcessWithoutNullStreams, spawn } from 'child_process';
import * as path from 'path';
import { PrismaService } from '../prisma.service';
import { ChatbotMessageDto } from './dto/chatbot-message.dto';

type WorkerResponseSuccess = {
  id: number;
  answer: string;
  lastSpecies: string | null;
};

type WorkerResponseError = {
  id: number;
  error: string;
};

type WorkerResponseReady = {
  ready: true;
};

type WorkerResponse = WorkerResponseSuccess | WorkerResponseError | WorkerResponseReady;

type PendingRequest = {
  resolve: (value: WorkerResponseSuccess) => void;
  reject: (reason?: unknown) => void;
  timer: NodeJS.Timeout;
};

type ConversationContext = {
  lastSpecies: string | null;
  updatedAt: number;
};

const WORKER_TIMEOUT_MS = 25_000;
const CONTEXT_TTL_MS = 6 * 60 * 60 * 1000;
const CONTEXT_CLEANUP_INTERVAL_MS = 10 * 60 * 1000;

@Injectable()
export class ChatbotService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(ChatbotService.name);

  private worker: ChildProcessWithoutNullStreams | null = null;
  private workerReady = false;
  private workerOutputBuffer = '';
  private nextRequestId = 1;
  private readonly pendingRequests = new Map<number, PendingRequest>();
  private readonly contextByConversation = new Map<string, ConversationContext>();
  private cleanupTimer: NodeJS.Timeout | null = null;

  constructor(private readonly prisma: PrismaService) {}

  onModuleInit(): void {
    this.cleanupTimer = setInterval(() => this.cleanupExpiredContexts(), CONTEXT_CLEANUP_INTERVAL_MS);
    this.cleanupTimer.unref();
    this.startWorker();
  }

  onModuleDestroy(): void {
    if (this.cleanupTimer) {
      clearInterval(this.cleanupTimer);
      this.cleanupTimer = null;
    }
    this.stopWorker(new ServiceUnavailableException('Chatbot non disponibile'));
  }

  async ask(userId: number, dto: ChatbotMessageDto) {
    const conversationId = this.normalizeConversationId(dto.conversationId);
    const contextKey = this.makeContextKey(userId, conversationId);
    let lastSpecies = this.contextByConversation.get(contextKey)?.lastSpecies ?? null;

    if (!lastSpecies && dto.speciesHint) {
      lastSpecies = dto.speciesHint;
    }

    if (!lastSpecies && dto.sightingId !== undefined) {
      lastSpecies = await this.findSpeciesNameForSighting(dto.sightingId);
    }

    const result = await this.queryWorker(dto.message, lastSpecies);
    this.contextByConversation.set(contextKey, {
      lastSpecies: result.lastSpecies ?? null,
      updatedAt: Date.now(),
    });

    return {
      conversationId,
      answer: result.answer,
      contextSpecies: result.lastSpecies ?? null,
    };
  }

  async reset(userId: number, conversationId?: string) {
    if (conversationId) {
      const normalized = this.normalizeConversationId(conversationId);
      this.contextByConversation.delete(this.makeContextKey(userId, normalized));
      return { reset: true, conversationId: normalized };
    }

    const prefix = `${userId}:`;
    for (const key of [...this.contextByConversation.keys()]) {
      if (key.startsWith(prefix)) {
        this.contextByConversation.delete(key);
      }
    }

    return { reset: true, conversationId: null };
  }

  private makeContextKey(userId: number, conversationId: string): string {
    return `${userId}:${conversationId}`;
  }

  private normalizeConversationId(conversationId?: string): string {
    const trimmed = conversationId?.trim();
    if (!trimmed) {
      return 'default';
    }
    return trimmed.slice(0, 80);
  }

  private async findSpeciesNameForSighting(sightingId: number): Promise<string | null> {
    const sighting = await this.prisma.sighting.findFirst({
      where: { id: sightingId, deleted: false },
      select: {
        species: {
          select: { name: true },
        },
      },
    });

    const speciesName = sighting?.species?.name?.trim();
    return speciesName && speciesName.length > 0 ? speciesName : null;
  }

  private getWorkerScriptPath(): string {
    const configuredPath = process.env.CHATBOT_WORKER_PATH?.trim();
    if (configuredPath) {
      return configuredPath;
    }
    return path.join(process.cwd(), 'chatbot', 'worker.py');
  }

  private getPythonBin(): string {
    const configuredBin = process.env.CHATBOT_PYTHON_BIN?.trim();
    return configuredBin && configuredBin.length > 0 ? configuredBin : 'python3';
  }

  private startWorker(): void {
    if (this.worker && !this.worker.killed) {
      return;
    }

    const scriptPath = this.getWorkerScriptPath();
    const pythonBin = this.getPythonBin();
    this.logger.log(`Avvio worker chatbot: ${pythonBin} ${scriptPath}`);

    this.worker = spawn(pythonBin, ['-u', scriptPath], {
      cwd: path.dirname(scriptPath),
      env: { ...process.env, PYTHONUNBUFFERED: '1' },
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    this.workerReady = false;
    this.workerOutputBuffer = '';

    this.worker.stdout.setEncoding('utf8');
    this.worker.stdout.on('data', (chunk: string) => this.handleWorkerStdout(chunk));

    this.worker.stderr.setEncoding('utf8');
    this.worker.stderr.on('data', (chunk: string) => {
      const message = chunk.trim();
      if (message) {
        this.logger.warn(`[chatbot-worker] ${message}`);
      }
    });

    this.worker.on('error', (error) => {
      this.logger.error(`Errore worker chatbot: ${error.message}`);
      this.rejectAllPending(
        new ServiceUnavailableException('Chatbot non disponibile: errore avvio worker'),
      );
      this.workerReady = false;
      this.worker = null;
    });

    this.worker.on('exit', (code, signal) => {
      this.logger.error(`Worker chatbot terminato (code=${code}, signal=${signal ?? 'none'})`);
      this.rejectAllPending(new ServiceUnavailableException('Chatbot non disponibile'));
      this.workerReady = false;
      this.worker = null;
    });
  }

  private stopWorker(reason?: Error): void {
    if (!this.worker) {
      return;
    }

    if (reason) {
      this.rejectAllPending(reason);
    }

    this.worker.removeAllListeners();
    this.worker.stdout.removeAllListeners();
    this.worker.stderr.removeAllListeners();
    this.worker.kill();
    this.workerReady = false;
    this.worker = null;
  }

  private restartWorker(): void {
    this.stopWorker(new ServiceUnavailableException('Assistente riavviato. Riprova.'));
    this.startWorker();
  }

  private ensureWorkerRunning(): void {
    if (!this.worker || this.worker.killed) {
      this.startWorker();
    }

    if (!this.worker || this.worker.killed || this.worker.stdin.destroyed) {
      throw new ServiceUnavailableException(
        'Chatbot non disponibile. Verifica dipendenze Python e Ollama.',
      );
    }

    if (!this.workerReady) {
      throw new ServiceUnavailableException(
        'Assistente in avvio. Riprova tra pochi secondi.',
      );
    }
  }

  private queryWorker(query: string, lastSpecies: string | null): Promise<WorkerResponseSuccess> {
    this.ensureWorkerRunning();
    const worker = this.worker;
    if (!worker) {
      throw new ServiceUnavailableException('Chatbot non disponibile');
    }

    return new Promise<WorkerResponseSuccess>((resolve, reject) => {
      const requestId = this.nextRequestId++;
      const timer = setTimeout(() => {
        this.pendingRequests.delete(requestId);
        reject(new ServiceUnavailableException('Risposta troppo lenta. Riprova.'));
        this.restartWorker();
      }, WORKER_TIMEOUT_MS);

      this.pendingRequests.set(requestId, { resolve, reject, timer });

      const payload = JSON.stringify({
        id: requestId,
        query,
        lastSpecies,
      });

      worker.stdin.write(`${payload}\n`, (error) => {
        if (!error) {
          return;
        }

        clearTimeout(timer);
        this.pendingRequests.delete(requestId);
        reject(new ServiceUnavailableException('Errore di comunicazione con il chatbot'));
      });
    });
  }

  private handleWorkerStdout(chunk: string): void {
    this.workerOutputBuffer += chunk;

    let newlineIndex = this.workerOutputBuffer.indexOf('\n');
    while (newlineIndex !== -1) {
      const line = this.workerOutputBuffer.slice(0, newlineIndex).trim();
      this.workerOutputBuffer = this.workerOutputBuffer.slice(newlineIndex + 1);
      if (line) {
        this.handleWorkerLine(line);
      }
      newlineIndex = this.workerOutputBuffer.indexOf('\n');
    }
  }

  private handleWorkerLine(line: string): void {
    let payload: WorkerResponse;
    try {
      payload = JSON.parse(line) as WorkerResponse;
    } catch {
      this.logger.warn(`Output non JSON dal worker chatbot: ${line}`);
      return;
    }

    if ('ready' in payload && payload.ready) {
      this.workerReady = true;
      this.logger.log('Worker chatbot pronto');
      return;
    }

    if (!('id' in payload) || typeof payload.id !== 'number') {
      this.logger.warn(`Risposta worker senza id valido: ${line}`);
      return;
    }

    const pending = this.pendingRequests.get(payload.id);
    if (!pending) {
      return;
    }

    clearTimeout(pending.timer);
    this.pendingRequests.delete(payload.id);

    if ('error' in payload) {
      pending.reject(new ServiceUnavailableException(payload.error || 'Errore chatbot'));
      return;
    }

    pending.resolve(payload);
  }

  private rejectAllPending(error: Error): void {
    for (const pending of this.pendingRequests.values()) {
      clearTimeout(pending.timer);
      pending.reject(error);
    }
    this.pendingRequests.clear();
  }

  private cleanupExpiredContexts(): void {
    const now = Date.now();
    for (const [key, value] of this.contextByConversation.entries()) {
      if (now - value.updatedAt > CONTEXT_TTL_MS) {
        this.contextByConversation.delete(key);
      }
    }
  }
}
