#include <cstdio>
#include <cstring>

#include "test_harness.h"

namespace test {

namespace {

struct Entry {
  const char* name;
  TestFn fn;
};

constexpr int kMaxTests = 256;
Entry gTests[kMaxTests];
int gTestCount = 0;
int gFailures = 0;

}  // namespace

Registration::Registration(const char* name, TestFn fn) {
  if (gTestCount < kMaxTests) gTests[gTestCount++] = Entry{name, fn};
}

void fail(const char* file, int line, const char* message) {
  ++gFailures;
  std::printf("    FALLO %s:%d: %s\n", file, line, message);
}

}  // namespace test

// Uso: makeup_engine_host_tests [filtro]  (corre los tests cuyo nombre contiene el filtro)
int main(int argc, char** argv) {
  const char* filter = argc > 1 ? argv[1] : nullptr;
  int failedTests = 0;
  int ran = 0;
  for (int i = 0; i < test::gTestCount; ++i) {
    const auto& entry = test::gTests[i];
    if (filter != nullptr && std::strstr(entry.name, filter) == nullptr) continue;
    const int before = test::gFailures;
    entry.fn();
    ++ran;
    const bool ok = test::gFailures == before;
    if (!ok) ++failedTests;
    std::printf("%s %s\n", ok ? "ok  " : "FAIL", entry.name);
  }
  std::printf("\n%d tests, %d fallidos\n", ran, failedTests);
  return failedTests == 0 && ran > 0 ? 0 : 1;
}
