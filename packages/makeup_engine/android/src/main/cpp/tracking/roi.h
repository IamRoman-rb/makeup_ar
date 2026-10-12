// Región de interés (ROI) del tracker: un cuadrado rotado en la imagen.
//
// Espacio "imagen": el frame de cámara derecho y SIN espejar (como lo vería
// otra persona), en píxeles de la salida (p. ej. 720×1280), y con y hacia abajo.
// Espacio "recorte": [0,1]² del tensor de entrada del modelo; u a lo largo de
// la línea de los ojos y v hacia el mentón.
//
//   imagen = centro + (u - 0.5)·size·(cos θ, sin θ) + (v - 0.5)·size·(-sin θ, cos θ)
#pragma once

namespace makeup {

struct Point2 {
  float x;
  float y;
};

struct Roi {
  float centerX = 0.0f;
  float centerY = 0.0f;
  float size = 0.0f;      // lado del cuadrado, px de imagen
  float rotation = 0.0f;  // rad; 0 = cara derecha

  bool valid() const { return size > 0.0f; }
};

// Recorte (u, v) -> imagen (px).
Point2 roiToImage(const Roi& roi, float u, float v);

// Imagen (px) -> recorte (u, v).
Point2 imageToRoi(const Roi& roi, float x, float y);

// Matriz afín 3×3 column-major que lleva [0,1]² del recorte a [0,1]² de la
// imagen (dividida por width/height). La usa el shader de recorte.
void roiCropMatrix(const Roi& roi, float imageWidth, float imageHeight, float out[9]);

// ROI del detector: toda la imagen centrada en un cuadrado (letterbox).
Roi letterboxRoi(float imageWidth, float imageHeight);

// ROI a partir de puntos en px de imagen (receta de MediaPipe): ángulo por la
// línea [eyeA] -> [eyeB] (A = ojo a la izquierda de la imagen con la cara
// derecha), caja de los puntos en el marco rotado, lado = max(ancho, alto)·scale.
// [stride] = floats por punto (2 o 3). Devuelve un Roi inválido si count == 0.
Roi roiFromPoints(const float* points, int count, int stride, int eyeA, int eyeB, float scale);

// ROI a partir de una caja alineada a ejes (px de imagen) y dos ojos (px).
Roi roiFromBox(float xMin, float yMin, float width, float height, Point2 eyeA, Point2 eyeB,
               float scale);

}  // namespace makeup
