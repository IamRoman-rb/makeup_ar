---
paths:
  - "packages/makeup_engine/android/**/*.{cpp,h,hpp,kt}"
  - "packages/makeup_engine/ios/**/*"
---
# Motor nativo (C++/GLES)
- OpenGL ES 3.0 como mínimo común; nada de Vulkan sin spike aprobado.
- Cero allocations por frame en el hilo de render: buffers y texturas se crean al iniciar y se reutilizan.
- Un hilo dueño del contexto GL; la inferencia corre en otro hilo y se comunica por una cola de un solo elemento (último valor gana).
- Recursos GL con RAII; en debug, comprobar `glGetError` tras cada bloque de llamadas.
- Nada de cruces JNI/FFI por frame: Dart envía recetas y lee métricas.
- Toda constante de rendimiento (resoluciones, Hz de inferencia) en un único header de configuración.
