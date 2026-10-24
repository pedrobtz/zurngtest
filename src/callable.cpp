// The C callable for generator packages (inst/include/zurngtest.h).
// zurngtest_test_cfun() wraps the caller's fill function and state in an
// external pointer and calls pract_test() through an R function whose
// source fills each chunk here, natively: R only orchestrates lengths, one
// call per chunk of up to 16 MiB. The callable is registered with
// R_RegisterCCallable() in init.cpp and reached through R_GetCCallable();
// its symbol is hidden like every other.
#include <cstddef>
#include <cstdint>

#include "zurngtest.h"

namespace {

struct Generator {
  zurngtest_fill_fn fill;
  void *state;
};

// zurngtest.h includes R's headers without R_NO_REMAP, so no name here may
// be one R remaps (eval, length, error, ...).
struct Call {
  SEXP call;
  SEXP env;
};

SEXP eval_call(void *data) {
  Call *todo = static_cast<Call *>(data);
  return Rf_eval(todo->call, todo->env);
}

void clear_generator(void *ptr) { R_ClearExternalPtr(static_cast<SEXP>(ptr)); }

}  // namespace

extern "C" {

// Registered as "zurngtest_test_cfun". The Generator lives on this frame,
// which outlives the pract_test() call that uses it. The external pointer
// can outlive the frame (a condition's call, a kept frame), so it is
// cleared on every exit, an error's longjmp included.
SEXP zrt_test_cfun(zurngtest_fill_fn fill, void *state, SEXP options) {
  Generator generator = {fill, state};
  SEXP ptr = PROTECT(R_MakeExternalPtr(&generator, R_NilValue, R_NilValue));
  SEXP ns = PROTECT(R_FindNamespace(PROTECT(Rf_mkString("zurngtest"))));
  SEXP call = PROTECT(Rf_lang3(Rf_install("test_cfun"), ptr, options));
  Call todo = {call, ns};
  SEXP result = R_ExecWithCleanup(eval_call, &todo, clear_generator, ptr);
  UNPROTECT(4);
  return result;
}

// Fills `nbytes` (a multiple of 4) bytes from the generator in `ptr`, or
// returns NULL once its zurngtest_test_cfun() call has returned.
SEXP zrt_cfun_fill(SEXP ptr, SEXP nbytes) {
  Generator *generator = static_cast<Generator *>(R_ExternalPtrAddr(ptr));
  if (generator == NULL) return R_NilValue;
  R_xlen_t n = R_xlen_t(Rf_asReal(nbytes));
  SEXP out = PROTECT(Rf_allocVector(RAWSXP, n));
  generator->fill(generator->state, reinterpret_cast<std::uint32_t *>(RAW(out)),
                  std::size_t(n / 4));
  UNPROTECT(1);
  return out;
}

// For the tests: a 32-bit counter, tested through the public header the way
// a generator package would.
static void fill_counter(void *state, std::uint32_t *out, std::size_t n) {
  std::uint32_t *next = static_cast<std::uint32_t *>(state);
  for (std::size_t i = 0; i < n; i++) out[i] = (*next)++;
}

SEXP zrt_test_cfun_counter(SEXP start, SEXP options) {
  std::uint32_t next = std::uint32_t(Rf_asReal(start));
  return zurngtest_test_cfun(fill_counter, &next, options);
}

}  // extern "C"
