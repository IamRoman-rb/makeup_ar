---
paths:
  - "lib/features/ar/**/*.dart"
  - "packages/makeup_engine/lib/**/*.dart"
---
# Dart del módulo AR
- Null-safety estricta: nada de `!` sin comprobación previa en la misma función; preferí `?.` y valores por defecto.
- Prohibido instanciar objetos pesados (Paint, Path, Shader, listas) dentro de `paint()` o de loops por frame: crealos una vez y reutilizalos.
- Un solo `ValueNotifier`/`Listenable` por flujo; nada de `setState` por frame.
- Todo `StreamSubscription`, `Timer`, controller y `Isolate` se cancela en `dispose()`.
- Los frames se descartan con una bandera tipo `_frameInFlight`; nunca se encolan.
- Código nuevo con test unitario; comentarios en español, identificadores en inglés.
