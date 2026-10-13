// Validador de recetas makeup-recipe/2 con el mismo esquema JSON que la app
// (docs/ar_engine/recipe_v2.schema.json, copiado por scripts/copy-schema.mjs).
// Ajv usa regex ECMA-262, como exige JSON Schema: "#B3122D\n" se rechaza
// (motor_ar_propio.md §10.11). Paridad: test/schema.test.ts con los mismos
// casos que Dart y Python (test/fixtures/recipe_v2_cases.json).
import Ajv2020 from 'ajv/dist/2020';

import schema from './generated/recipe_v2.schema.json';

const ajv = new Ajv2020({ allErrors: false, strict: true });
const validateFn = ajv.compile(schema);

export const recipeSchema: Readonly<Record<string, unknown>> = schema;

export function isValidRecipe(recipe: unknown): boolean {
  return validateFn(recipe) === true;
}
