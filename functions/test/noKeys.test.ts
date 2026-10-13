// Ninguna key de LLM en el repo (CLAUDE.md: "Ninguna API key dentro de la
// app"). Solo lista archivos, nunca imprime el valor encontrado. Las keys de
// Firebase de firebase_options.dart y google-services.json no son secretas
// (checklist de seguridad de Firebase) y se excluyen.
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { join } from 'node:path';
import { test } from 'node:test';

const root = join(__dirname, '..', '..', '..');
// Google (Gemini, AIza...), Groq (gsk_), Anthropic (sk-ant-) y OpenAI (sk-proj-).
const pattern = 'AIza[0-9A-Za-z_-]{35}|gsk_[A-Za-z0-9]{20,}|sk-ant-[A-Za-z0-9_-]{20,}|sk-proj-[A-Za-z0-9_-]{20,}';

test('sin keys de LLM en archivos versionados', () => {
  let files = '';
  try {
    files = execFileSync('git', ['grep', '-lE', pattern, '--', '.', ':!lib/firebase_options.dart',
      ':!**/google-services.json', ':!**/GoogleService-Info.plist'], { cwd: root, encoding: 'utf-8' });
  } catch (error) {
    // git grep sale con 1 cuando no encuentra nada.
    if ((error as { status?: number }).status !== 1) throw error;
  }
  assert.equal(files.trim(), '', `posibles keys en: ${files.trim()} (revisar y revocar)`);
});
