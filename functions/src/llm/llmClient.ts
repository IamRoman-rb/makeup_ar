// Interfaz del modelo de lenguaje: la validación y la cuota no dependen del
// proveedor (hoy Gemini en Vertex AI, src/llm/geminiClient.ts).

export interface LlmRequest {
  system: string;
  user: string;
}

export interface LlmResponse {
  text: string;
  model: string;
}

export interface LlmClient {
  // Tira LlmUnavailableError si el modelo no respondió (timeout, 5xx, cuota
  // del proveedor) después del reintento.
  generate(request: LlmRequest): Promise<LlmResponse>;
}

export class LlmUnavailableError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'LlmUnavailableError';
  }
}
