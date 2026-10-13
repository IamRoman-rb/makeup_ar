// Copia el esquema de recetas (fuente única: docs/ar_engine/recipe_v2.schema.json)
// adentro de functions/ antes de compilar: el deploy solo sube esta carpeta.
import { copyFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const source = join(here, '..', '..', 'docs', 'ar_engine', 'recipe_v2.schema.json');
const target = join(here, '..', 'src', 'generated', 'recipe_v2.schema.json');
mkdirSync(dirname(target), { recursive: true });
copyFileSync(source, target);
console.log('esquema copiado a src/generated/recipe_v2.schema.json');
