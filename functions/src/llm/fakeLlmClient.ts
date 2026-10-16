// LLM falso para el emulador de Functions (index.ts lo usa solo con
// FUNCTIONS_EMULATOR=true): permite probar en el teléfono todo el camino de
// las callables sin Vertex AI ni plan Blaze. Determinista: el mismo pedido da
// las mismas 3 variantes. Responde texto JSON como Gemini, así pasa por la
// misma validación (validVariants + Ajv). Ver docs/ar_engine/F2_PLAN.md.
import { createHash } from 'node:crypto';

import { LlmClient, LlmRequest, LlmResponse, LlmUnavailableError } from './llmClient';

export const FAKE_MODEL = 'fake-emulator';
// Marca en el texto del pedido para simular el modelo caído (fallback a preset).
export const FAKE_UNAVAILABLE_TAG = '#unavailable';

interface Palette {
  lips: string;
  finish: 'matte' | 'satin' | 'gloss' | 'shimmer';
  cheeks: string;
  shadow: string;
}

const PALETTES: readonly Palette[] = [
  { lips: '#B3122D', finish: 'satin', cheeks: '#D9727A', shadow: '#6B3A2E' },
  { lips: '#B07A6A', finish: 'matte', cheeks: '#D8957F', shadow: '#8C6A55' },
  { lips: '#C2436B', finish: 'gloss', cheeks: '#E58FA5', shadow: '#7A4E7E' },
  { lips: '#8E2F3C', finish: 'matte', cheeks: '#B5655E', shadow: '#4A3A3A' },
  { lips: '#D9665B', finish: 'shimmer', cheeks: '#F0A07E', shadow: '#B07D4F' },
  { lips: '#9C4F63', finish: 'satin', cheeks: '#C7848C', shadow: '#5E5A73' },
  { lips: '#E07A7A', finish: 'gloss', cheeks: '#F2A3A0', shadow: '#C9A27A' },
  { lips: '#6E1F2B', finish: 'matte', cheeks: '#A65A55', shadow: '#2F2A33' },
];

export class FakeLlmClient implements LlmClient {
  async generate(request: LlmRequest): Promise<LlmResponse> {
    if (request.user.includes(FAKE_UNAVAILABLE_TAG)) {
      throw new LlmUnavailableError('LLM falso: caída simulada');
    }
    const seed = createHash('sha256').update(request.user).digest().readUInt32BE(0);
    const variants = [0, 1, 2].map((i) => {
      const palette = PALETTES[(seed + i * 3) % PALETTES.length];
      return {
        schema: 'makeup-recipe/2',
        name: `Emulador ${i + 1}`,
        lips: { color: palette.lips, opacity: 0.8, finish: palette.finish },
        cheeks: { color: palette.cheeks, opacity: 0.35, placement: 'apple' },
        eyes: { shadow: [{ color: palette.shadow, opacity: 0.5, region: 'lid' }] },
      };
    });
    return { text: JSON.stringify({ variants }), model: FAKE_MODEL };
  }
}
