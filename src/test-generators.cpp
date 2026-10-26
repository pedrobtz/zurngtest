// Generators with known PractRand results, for the known-result tests
// (tests/testthat/test-known-results.R). They run through the public C
// callable, as a generator package's would.
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <random>

#include "PractRand.h"
#include "PractRand/RNGs/hc256.h"
#define R_NO_REMAP
#include "zurngtest.h"

// Each generator lives on the stack of zrt_test_generator(); R may longjmp
// past it if the run errors, which is safe because none holds heap memory.
namespace {

struct Lcg32 {
  std::uint32_t x;
};
void fill_lcg32(void *state, std::uint32_t *out, std::size_t n) {
  // Numerical Recipes' 32-bit LCG, every bit of the state as output.
  Lcg32 *g = static_cast<Lcg32 *>(state);
  for (std::size_t i = 0; i < n; i++) out[i] = g->x = g->x * 1664525u + 1013904223u;
}

struct Xorshift32 {
  std::uint32_t x;
};
void fill_xorshift32(void *state, std::uint32_t *out, std::size_t n) {
  // Marsaglia (2003), shifts 13, 17, 5.
  Xorshift32 *g = static_cast<Xorshift32 *>(state);
  for (std::size_t i = 0; i < n; i++) {
    g->x ^= g->x << 13;
    g->x ^= g->x >> 17;
    g->x ^= g->x << 5;
    out[i] = g->x;
  }
}

void fill_mt19937(void *state, std::uint32_t *out, std::size_t n) {
  std::mt19937 *g = static_cast<std::mt19937 *>(state);
  for (std::size_t i = 0; i < n; i++) out[i] = std::uint32_t((*g)());
}

void fill_hc256(void *state, std::uint32_t *out, std::size_t n) {
  PractRand::RNGs::Raw::hc256 *g = static_cast<PractRand::RNGs::Raw::hc256 *>(state);
  for (std::size_t i = 0; i < n; i++) out[i] = g->raw32();
}

}  // namespace

extern "C" SEXP zrt_test_generator(SEXP name, SEXP seed, SEXP options) {
  const char *which = CHAR(STRING_ELT(name, 0));
  std::uint32_t s = std::uint32_t(Rf_asReal(seed));
  if (std::strcmp(which, "lcg32") == 0) {
    Lcg32 g = {s};
    return zurngtest_test_cfun(fill_lcg32, &g, options);
  }
  if (std::strcmp(which, "xorshift32") == 0) {
    Xorshift32 g = {s ? s : 2463534242u};
    return zurngtest_test_cfun(fill_xorshift32, &g, options);
  }
  if (std::strcmp(which, "mt19937") == 0) {
    std::mt19937 g(s);
    return zurngtest_test_cfun(fill_mt19937, &g, options);
  }
  if (std::strcmp(which, "hc256") == 0) {
    PractRand::RNGs::Raw::hc256 g;
    g.seed(PractRand::Uint64(s));
    return zurngtest_test_cfun(fill_hc256, &g, options);
  }
  Rf_error("unknown test generator");
  return R_NilValue;
}
