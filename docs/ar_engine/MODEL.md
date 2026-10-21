# Fase 3: modelo propio de landmarks (infraestructura)

Estado: **infraestructura lista, sin datos ni entrenamiento.** Mientras tanto la app sigue con FaceMesh-V2 (Apache 2.0). Lo que falta lo tiene que hacer una persona: juntar datos con consentimiento y entrenar en una máquina con GPU.

Decisión (2026-10-15): solo infraestructura. El código vive en `tools/model/` y sus dependencias son solo de herramientas (`requirements.txt`); nada entra en la app.

## Piezas

| Archivo | Qué hace |
|---|---|
| `CONSENT.md` | Protocolo de recolección: consentimiento firmado y revocable, minimización, retención, diversidad, plantilla de release. **Leer antes de grabar.** |
| `dataset.py` | Manifiesto JSONL (video, persona seudónima, `consent_id`, Fitzpatrick, luz, estático); excluye `revoked.txt`; split train/val/test **por persona** (hash), así el NME de validación no se infla; cobertura por tono y luz. |
| `geometry.py` | Port del tracker: ROI rotado, anclas y NMS de BlazeFace, regiones de la malla (labios, ojos, cejas, contorno, iris). Lee las constantes de `engine_config.h`. |
| `teacher_label.py` | Etiquetas de destilación con el maestro, FaceMesh-V2: BlazeFace → ROI → landmarks → ROI de los puntos → landmarks, igual que el motor. Escribe cuadros y etiquetas **solo fuera del repo**. |
| `student.py` | MobileNetV3-Small escrita a mano (sin torchvision ni pesos de ImageNet), entrada de 192 px, salida 478×3 + presencia; ~3 M parámetros. |
| `train.py` | Pérdida Wing (px del recorte) + forma (aristas de la malla) + presencia; jitter de ROI y de color; negativos sin cara; entrenamiento float y después QAT int8. |
| `metrics.py` / `evaluate.py` | NME por región (normalizado por la distancia entre ojos, con máscara para etiquetas a mano parciales), jitter en videos quietos (sin la deriva lenta), y el criterio de salida del §7. |
| `export.py` | A `.tflite` con ai-edge-torch, envuelto para que tenga la misma entrada y salida que `face_landmarks_detector.tflite` (int8 opcional, calibrado con validación). |
| `dense.py` | Modelo más denso (opción 5 de precisión, 2026-10-21). Contornos densos de labios (64 + 48) y ojos (32 + 32) remuestreados por largo de arco; pseudo-etiquetas del maestro con spline Catmull-Rom; métrica punto-a-contorno (`contour_nme`) para polilíneas marcadas a mano; espejo horizontal (`mirror_map` desde la malla canónica, iris reordenado por ángulo). |

Tests (sin datos ni modelos): `python -m unittest discover -s tools/model`.

## Cómo seguir cuando haya datos

1. **Instalar:** `pip install -r tools/model/requirements.txt`.
2. **Grabar** según `CONSENT.md` y armar `../makeup_data/manifest.jsonl`. Revisar la cobertura con `dataset.coverage()`: los 6 tonos y las luces.
3. **Etiquetar:** `python tools/model/teacher_label.py --data ../makeup_data --every 3`.
4. **Etiquetar a mano un subconjunto de validación** (unos 300 cuadros, de personas que estén en `val`). No hace falta marcar los 478 puntos: alcanza con contornos de labios, ojos, iris y óvalo, con `mask`. Es la única forma de saber si el alumno es **mejor** que el maestro y no solo parecido.
5. **Entrenar:** `python tools/model/train.py --data ../makeup_data --out ../makeup_runs/r1` (GPU; horas a días).
6. **Evaluar:** `python tools/model/evaluate.py --truth … --teacher … --student …`. Sale con código 0 si el NME del alumno es menor o igual que el del maestro en cada región.
7. **Exportar** (`export.py`, `--int8`), reemplazar el `.tflite` en una rama y medir en el E20 con `lib/main_benchmark.dart`: latencia p50/p95 y térmica a 5 minutos, más el jitter con el arnés del tracker. El criterio de salida del §7 pide **NME ≤ el del modelo abierto y la misma latencia p95**.

## Limitaciones y decisiones

- **El maestro marca el techo.** La destilación aprende a imitar a FaceMesh-V2: para superarlo hacen falta las etiquetas a mano (paso 4) y entrenar también contra ellas, o datos sintéticos propios con geometría exacta.
- **La QAT usa `torch.ao.quantization` (FX)**, que está deprecado a favor de torchao. Hoy funciona con la versión instalada (los tests lo corren); si se retira, hay que pasar al flujo PT2E de ai-edge-torch, que `export.py` ya usa para int8.
- **Espejo horizontal en el aumento de datos (resuelto el 2026-10-21):** `dense.mirror_map()` saca el mapa izquierda↔derecha de los 468 puntos de la malla canónica (el vértice más cercano a (−x, y, z)) e intercambia los iris. El anillo de cada iris se reordena por ángulo en cada muestra, así que no importa cómo los numere el maestro. `train.py` espeja la mitad de los cuadros (`--flip`).
- **Cabezal denso (opción 5, `train.py --dense`, `export.py --dense`):**
  - El alumno aprende además 176 puntos sobre los contornos de labios y ojos. Al principio son pseudo-etiquetas del maestro con spline; con polilíneas marcadas a mano (paso 4: alcanza con dibujar el borde, sin marcar puntos) aprende el borde real.
  - `contour_nme` mide la distancia de esos puntos al borde marcado: es la métrica que dice si el modelo propio ve el borde mejor que FaceMesh-V2.
  - El `.tflite` exportado sigue dando los 478 puntos que espera el motor.
  - Para que el motor use los puntos densos hay que sumarlos a la malla, con su UV, por ejemplo en lugar de los puntos nuevos del contorno de la malla suave (`TRACKER.md` §9). Se decide con números del alumno contra el maestro.
- **Red de labios (oclusión, fase 4):** sería un cabezal más sobre el mismo backbone, con una máscara de 64×64 del ROI de la boca. Las etiquetas iniciales saldrían de los contornos de labios del maestro (`FACEMESH_LIPS`), corregidas a mano en los casos de oclusión (mano, taza, micrófono). No se entrena hasta que el set tenga oclusiones grabadas. Mientras tanto queda la oclusión heurística de P8–P9.
- **Esfuerzo:** del orden de meses (informe §6.2), dominado por datos y evaluación, no por la red.
