// Gemini en Vertex AI con las credenciales de la cuenta de servicio de la
// función (ADC): no hay API key que guardar. Salida JSON, temperatura baja,
// timeout corto y un reintento ante errores transitorios.
import { GoogleGenAI } from '@google/genai';

import { LlmClient, LlmRequest, LlmResponse, LlmUnavailableError } from './llmClient';

export interface GeminiOptions {
  project: string;
  location: string;
  model: string;
  timeoutMs?: number;
  temperature?: number;
}

const DEFAULT_TIMEOUT_MS = 15000;
const DEFAULT_TEMPERATURE = 0.3;

// Errores en los que vale reintentar una vez: timeout, red, 429 y 5xx.
function isTransient(error: unknown): boolean {
  const status = (error as { status?: unknown }).status;
  if (typeof status === 'number') return status === 429 || status >= 500;
  return true;
}

export class GeminiClient implements LlmClient {
  private readonly ai: GoogleGenAI;

  constructor(private readonly options: GeminiOptions) {
    this.ai = new GoogleGenAI({
      vertexai: true,
      project: options.project,
      location: options.location,
      httpOptions: { timeout: options.timeoutMs ?? DEFAULT_TIMEOUT_MS },
    });
  }

  async generate(request: LlmRequest): Promise<LlmResponse> {
    let lastError: unknown;
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        const response = await this.ai.models.generateContent({
          model: this.options.model,
          contents: request.user,
          config: {
            systemInstruction: request.system,
            responseMimeType: 'application/json',
            temperature: this.options.temperature ?? DEFAULT_TEMPERATURE,
          },
        });
        return { text: response.text ?? '', model: this.options.model };
      } catch (error) {
        lastError = error;
        if (!isTransient(error)) break;
      }
    }
    const status = (lastError as { status?: unknown }).status;
    throw new LlmUnavailableError(`Gemini no respondió (status ${String(status ?? 'sin status')})`);
  }
}
