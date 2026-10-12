// Triple buffer lock-free de un escritor y un lector ("último valor gana"):
// el escritor nunca espera al lector y el lector nunca ve un valor a medio
// escribir. Sin allocations: los tres T viven dentro del objeto.
#pragma once

#include <array>
#include <atomic>
#include <cstdint>

namespace makeup {

template <typename T>
class TripleBuffer {
 public:
  // Escritor: buffer libre para escribir el próximo valor.
  T& writeBuffer() { return buffers_[back_]; }

  // Escritor: publica lo escrito en writeBuffer().
  void publish() {
    const uint32_t previous = middle_.exchange(back_ | kDirty, std::memory_order_acq_rel);
    back_ = previous & kIndexMask;
  }

  // Lector: si hay un valor nuevo lo toma y devuelve true. readBuffer() queda
  // válido hasta la próxima llamada a acquire().
  bool acquire() {
    if ((middle_.load(std::memory_order_relaxed) & kDirty) == 0) return false;
    const uint32_t previous = middle_.exchange(front_, std::memory_order_acq_rel);
    front_ = previous & kIndexMask;
    return true;
  }

  const T& readBuffer() const { return buffers_[front_]; }

 private:
  static constexpr uint32_t kDirty = 0x4;
  static constexpr uint32_t kIndexMask = 0x3;

  std::array<T, 3> buffers_{};
  uint32_t back_ = 0;                // solo escritor
  std::atomic<uint32_t> middle_{1};  // compartido: índice | kDirty
  uint32_t front_ = 2;               // solo lector
};

}  // namespace makeup
