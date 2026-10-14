#include "studio/still_image.h"

#include <algorithm>
#include <cmath>

#include "engine_config.h"

namespace makeup {

namespace {

struct LinearLut {
  float value[256];
  LinearLut() {
    for (int i = 0; i < 256; ++i) value[i] = srgbToLinear(static_cast<float>(i) / 255.0f);
  }
};

const LinearLut& linearLut() {
  static const LinearLut lut;
  return lut;
}

}  // namespace

void argbToRgba(const int32_t* argb, int count, uint8_t* rgba) {
  for (int i = 0; i < count; ++i) {
    const uint32_t pixel = static_cast<uint32_t>(argb[i]);
    rgba[0] = static_cast<uint8_t>((pixel >> 16) & 0xFF);
    rgba[1] = static_cast<uint8_t>((pixel >> 8) & 0xFF);
    rgba[2] = static_cast<uint8_t>(pixel & 0xFF);
    rgba[3] = static_cast<uint8_t>((pixel >> 24) & 0xFF);
    rgba += 4;
  }
}

void stillImageFromArgb(const int32_t* argb, int width, int height, StillImage* out) {
  out->width = width;
  out->height = height;
  out->rgba.resize(static_cast<size_t>(width) * static_cast<size_t>(height) * 4);
  argbToRgba(argb, width * height, out->rgba.data());
}

float srgb8ToLinear(uint8_t value) { return linearLut().value[value]; }

bool sampleStill(const StillImage& image, float x, float y, float out[3]) {
  const float fx = x - 0.5f;
  const float fy = y - 0.5f;
  if (!(fx >= -0.5f && fy >= -0.5f && fx <= static_cast<float>(image.width) - 0.5f &&
        fy <= static_cast<float>(image.height) - 0.5f)) {
    out[0] = out[1] = out[2] = 0.0f;
    return false;
  }
  const int x0 = std::clamp(static_cast<int>(std::floor(fx)), 0, image.width - 1);
  const int y0 = std::clamp(static_cast<int>(std::floor(fy)), 0, image.height - 1);
  const int x1 = std::min(x0 + 1, image.width - 1);
  const int y1 = std::min(y0 + 1, image.height - 1);
  const float tx = std::clamp(fx - static_cast<float>(x0), 0.0f, 1.0f);
  const float ty = std::clamp(fy - static_cast<float>(y0), 0.0f, 1.0f);
  const uint8_t* p00 = &image.rgba[(static_cast<size_t>(y0) * image.width + x0) * 4];
  const uint8_t* p10 = &image.rgba[(static_cast<size_t>(y0) * image.width + x1) * 4];
  const uint8_t* p01 = &image.rgba[(static_cast<size_t>(y1) * image.width + x0) * 4];
  const uint8_t* p11 = &image.rgba[(static_cast<size_t>(y1) * image.width + x1) * 4];
  for (int c = 0; c < 3; ++c) {
    const float top = static_cast<float>(p00[c]) + (static_cast<float>(p10[c]) - p00[c]) * tx;
    const float bottom = static_cast<float>(p01[c]) + (static_cast<float>(p11[c]) - p01[c]) * tx;
    out[c] = (top + (bottom - top) * ty) / 255.0f;
  }
  return true;
}

Vec3 srgb8ToOklab(uint8_t r, uint8_t g, uint8_t b) {
  const float* lut = linearLut().value;
  return linearToOklab(Vec3{lut[r], lut[g], lut[b]});
}

Vec3 srgbFloatToOklab(const float rgb[3]) { return srgbToOklab(rgb[0], rgb[1], rgb[2]); }

bool fillStillTensor(const StillImage& image, const Roi& roi, int size, float scale, float offset, float* out,
                     int count) {
  if (!image.valid() || !roi.valid() || size <= 0 || count != size * size * 3) return false;
  // Un tap por píxel de foto que cae en un píxel del tensor (antialias).
  const int taps = std::clamp(static_cast<int>(std::ceil(roi.size / static_cast<float>(size))), 1,
                              EngineConfig::kStillMaxTaps);
  const float inv = 1.0f / static_cast<float>(size);
  const float tapStep = inv / static_cast<float>(taps);
  const float tapWeight = 1.0f / static_cast<float>(taps * taps);
  float rgb[3];
  for (int row = 0; row < size; ++row) {
    for (int col = 0; col < size; ++col) {
      float sum[3] = {0.0f, 0.0f, 0.0f};
      for (int ty = 0; ty < taps; ++ty) {
        const float v = static_cast<float>(row) * inv + (static_cast<float>(ty) + 0.5f) * tapStep;
        for (int tx = 0; tx < taps; ++tx) {
          const float u = static_cast<float>(col) * inv + (static_cast<float>(tx) + 0.5f) * tapStep;
          const Point2 p = roiToImage(roi, u, v);
          sampleStill(image, p.x, p.y, rgb);
          sum[0] += rgb[0];
          sum[1] += rgb[1];
          sum[2] += rgb[2];
        }
      }
      for (int c = 0; c < 3; ++c) *out++ = sum[c] * tapWeight * scale + offset;
    }
  }
  return true;
}

}  // namespace makeup
