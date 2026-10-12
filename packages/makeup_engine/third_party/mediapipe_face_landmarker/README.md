# MediaPipe Face Landmarker (modelos de terceros)

Modelos de Google MediaPipe usados por el tracker facial del motor. Se redistribuyen sin modificar bajo **Apache License 2.0** (texto completo en `LICENSE`).

| Archivo (en `android/src/main/assets/makeup_engine/models/`) | Qué es | Entrada | Salida | SHA-256 |
|---|---|---|---|---|
| `face_detector.tflite` | BlazeFace short-range (detector) | 1×128×128×3 float32 | `regressors` 1×896×16, `classificators` 1×896×1 | `b4578f35940bf5a1a655214a1cce5cab13eba73c1297cd78e1a04c2380b0152f` |
| `face_landmarks_detector.tflite` | FaceMesh-V2 (landmarks) | 1×256×256×3 float32 (recorte de la cara con 25 % de margen) | 1434 = 478 puntos × (x, y, z), puntaje de presencia | `c7d54204ce0448474c7f3fa9af494787c0965cbdd6f20fc72867e43046bd43d5` |

- **Origen:** extraídos del bundle oficial `face_landmarker.task` (float16), descargado el 2026-10-12 de `https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/latest/face_landmarker.task` (SHA-256 del bundle: `64184e229b263107bc2b804c6625db1341ff2bb731874b0bcc2fe6544e0bc9ff`, Last-Modified 2023-05-03). Los otros dos archivos del bundle (`face_blendshapes.tflite`, `geometry_pipeline_metadata_landmarks.binarypb`) no se usan.
- **Licencia:** el model card de FaceMesh-V2 dice "Licensed under Apache License, Version 2.0". La documentación de MediaPipe Face Landmarker indica lo mismo para el bundle.
- **Model cards:** [FaceMesh-V2](https://storage.googleapis.com/mediapipe-assets/Model%20Card%20MediaPipe%20Face%20Mesh%20V2.pdf) · [BlazeFace short-range](https://storage.googleapis.com/mediapipe-assets/MediaPipe%20BlazeFace%20Model%20Card%20(Short%20Range).pdf). El de FaceMesh-V2 incluye la evaluación de equidad por tono de piel (Fitzpatrick 1–6) y por región.
- **Nota:** la documentación del bundle dice que el detector usa 192×192, pero el archivo real espera 128×128 (verificado leyendo el tensor de entrada).

Para actualizar los modelos, reemplazá los archivos, actualizá los hashes de esta tabla y volvé a correr el benchmark (`lib/main_benchmark.dart`).
