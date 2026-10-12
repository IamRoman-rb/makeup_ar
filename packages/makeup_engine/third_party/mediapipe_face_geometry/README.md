# MediaPipe face geometry (datos de terceros)

Malla canónica de la cara y metadatos de MediaPipe, usados por el tracker (pose por Procrustes) y por el compositor (triángulos y UV). Se redistribuyen sin modificar bajo **Apache License 2.0** (texto completo en `LICENSE`, copiado del mismo repo).

| Archivo | Ruta en el repo de MediaPipe | Qué se usa | SHA-256 |
|---|---|---|---|
| `canonical_face_model.obj` | `mediapipe/modules/face_geometry/data/` | 468 vértices (cm), UV por vértice y 898 triángulos | `8bac80443397e113f41a8b565ea72c59390bc031d9defab289dba7bc0c54e618` |
| `geometry_pipeline_metadata_landmarks.pbtxt` | `mediapipe/modules/face_geometry/data/` | `procrustes_landmark_basis`: 33 puntos estables y sus pesos | `55ca7c4c7bf195673b9d12a1b5d49d4b9c82b5ade8fed4b565496590866e359d` |
| `face_mesh_connections.py` | `mediapipe/python/solutions/` | `FACEMESH_LIPS`: contornos externo e interno de los labios. Se lee como datos (regex), nunca se ejecuta | `cc7171e44d0612db38720cb2fd2516c395992cdd7457efe341543be6f3c22d87` |
| `LICENSE` | raíz | licencia Apache 2.0 | `8707eef0533987efc5b155d64761eeb6e20793f50b9bd1a68dad1cf4719d0ed8` |

- **Origen:** `https://github.com/google-ai-edge/mediapipe`, rama `master` en el commit `88295bb98b7e53007763ba8a66b6f416dbbce99d`, descargados el 2026-10-12.
- **Uso:** `python tools/mesh/gen_canonical_mesh.py` genera `android/src/main/cpp/mesh/canonical_mesh.h`, que se versiona. Si cambian estos archivos, regenerá el header y corré los tests de host (`test_native/run_host_tests.cmd`).
- Los índices de la malla coinciden con los primeros 468 landmarks de FaceMesh-V2 (`../mediapipe_face_landmarker/`); los 10 restantes son iris.
