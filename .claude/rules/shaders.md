---
paths:
  - "packages/makeup_engine/**/*.{frag,vert,glsl}"
---
# Shaders
- GLSL ES 3.00 (`#version 300 es`), `precision mediump float` por defecto; `highp` solo donde se justifique con un comentario.
- Las conversiones de color (sRGB↔lineal, OKLab) viven en un único include compartido.
- Máximo de lecturas de textura por fragmento: documentarlo en el encabezado del shader y no superarlo sin medir.
- Sin bucles de longitud variable ni ramas costosas en el fragment shader.
- Cada uniform se documenta (rango y unidad) en el encabezado.
