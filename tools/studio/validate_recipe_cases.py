"""Valida test/fixtures/recipe_v2_cases.json contra docs/ar_engine/recipe_v2.schema.json.

Es la mitad Python de la prueba de paridad: el test Dart
(test/features/ar/domain/recipe_validator_test.dart) usa el mismo archivo de
casos. Si alguien cambia el esquema o los casos, uno de los dos lados falla.

Uso (desde la raíz del repo):  python tools/studio/validate_recipe_cases.py
Requiere: pip install jsonschema
"""
import json
import pathlib
import re
import sys

from jsonschema import Draft202012Validator, FormatChecker
from jsonschema.validators import extend

ROOT = pathlib.Path(__file__).resolve().parents[2]
SCHEMA = json.loads((ROOT / "docs/ar_engine/recipe_v2.schema.json").read_text(encoding="utf-8"))
CASES = json.loads((ROOT / "test/fixtures/recipe_v2_cases.json").read_text(encoding="utf-8"))["cases"]


def _ecma_pattern(validator, pattern, instance, schema):
    """JSON Schema exige regex ECMA-262: '$' solo coincide al final del texto.
    El 're' de Python también acepta antes de un salto de línea final, así que
    se usa \\Z para reproducir ECMA."""
    if not validator.is_type(instance, "string"):
        return
    ecma = pattern[:-1] + r"\Z" if pattern.endswith("$") and not pattern.endswith(r"\$") else pattern
    if not re.search(ecma, instance):
        from jsonschema.exceptions import ValidationError
        yield ValidationError(f"{instance!r} does not match {pattern!r}")


EcmaValidator = extend(Draft202012Validator, {"pattern": _ecma_pattern})


def main() -> int:
    Draft202012Validator.check_schema(SCHEMA)
    validator = EcmaValidator(SCHEMA, format_checker=FormatChecker())
    plain = Draft202012Validator(SCHEMA)
    failures = 0
    for case in CASES:
        ok = validator.is_valid(case["recipe"])
        status = "OK " if ok == case["valid"] else "MAL"
        if ok != case["valid"]:
            failures += 1
        divergence = ""
        if plain.is_valid(case["recipe"]) != ok:
            divergence = "  (re de Python sin ajuste ECMA daría otro resultado)"
        print(f"[{status}] {case['group']:8s} {case['id']:28s} esperado={'válida' if case['valid'] else 'inválida':8s}{divergence}")
    informe = [c for c in CASES if c["group"] == "informe"]
    print(f"\n{len(CASES)} casos ({len(informe)} del informe), {failures} con resultado distinto al esperado.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
