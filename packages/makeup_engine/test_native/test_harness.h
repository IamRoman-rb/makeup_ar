// Mini arnés de tests de host (sin dependencias): TEST registra una función,
// CHECK / CHECK_NEAR registran fallos sin abortar el test.
#pragma once

#include <cmath>
#include <cstdio>

namespace test {

using TestFn = void (*)();

struct Registration {
  Registration(const char* name, TestFn fn);
};

void fail(const char* file, int line, const char* message);

}  // namespace test

#define TEST(name)                                         \
  static void name();                                      \
  static ::test::Registration name##_registration(#name, name); \
  static void name()

#define CHECK(cond)                                         \
  do {                                                      \
    if (!(cond)) ::test::fail(__FILE__, __LINE__, #cond);   \
  } while (0)

#define CHECK_NEAR(actual, expected, tolerance)                                          \
  do {                                                                                   \
    const double checkActual = static_cast<double>(actual);                              \
    const double checkExpected = static_cast<double>(expected);                          \
    if (!(std::fabs(checkActual - checkExpected) <= static_cast<double>(tolerance))) {   \
      char checkMessage[256];                                                            \
      std::snprintf(checkMessage, sizeof(checkMessage), "%s = %.6g, esperado %.6g ± %.3g", \
                    #actual, checkActual, checkExpected, static_cast<double>(tolerance)); \
      ::test::fail(__FILE__, __LINE__, checkMessage);                                    \
    }                                                                                    \
  } while (0)
