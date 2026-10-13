// Paridad del esquema: los mismos casos que el validador Dart
// (test/features/ar/domain/recipe_validator_test.dart) y Python
// (tools/studio/validate_recipe_cases.py).
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';

import { isValidRecipe } from '../src/recipeSchema';

interface Case {
  id: string;
  valid: boolean;
  recipe: unknown;
}

const fixtures = join(__dirname, '..', '..', '..', 'test', 'fixtures', 'recipe_v2_cases.json');
const cases: Case[] = JSON.parse(readFileSync(fixtures, 'utf-8')).cases;

test('hay casos de paridad', () => {
  assert.ok(cases.length >= 44);
});

for (const c of cases) {
  test(`paridad: ${c.id}`, () => {
    assert.equal(isValidRecipe(c.recipe), c.valid);
  });
}
