// R entry points. R_NO_REMAP comes first, before zurngtest.h includes R's
// headers, so R's macros cannot rename anything in the standard library or
// PractRand.
#define R_NO_REMAP
#include "PractRand.h"
#include "zurngtest.h"

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <R_ext/Visibility.h>

extern "C" {

SEXP zrt_driver_new(SEXP battery, SEXP folding, SEXP bits, SEXP seed,
                    SEXP max_bytes);
SEXP zrt_driver_free(SEXP driver);
SEXP zrt_driver_feed(SEXP driver, SEXP data);
SEXP zrt_driver_results(SEXP driver);
SEXP zrt_issue_error_for_tests(void);
SEXP zrt_test_cfun(zurngtest_fill_fn fill, void *state, SEXP options);
SEXP zrt_cfun_fill(SEXP ptr, SEXP nbytes);
SEXP zrt_test_cfun_counter(SEXP start, SEXP options);
SEXP zrt_test_generator(SEXP name, SEXP seed, SEXP options);

// The PractRand version compiled in, for zurngtest_info().
SEXP zrt_practrand_version(void) {
  return Rf_mkString(PractRand::version_str);
}

static const R_CallMethodDef call_methods[] = {
    {"zrt_driver_new", (DL_FUNC)&zrt_driver_new, 5},
    {"zrt_driver_free", (DL_FUNC)&zrt_driver_free, 1},
    {"zrt_driver_feed", (DL_FUNC)&zrt_driver_feed, 2},
    {"zrt_driver_results", (DL_FUNC)&zrt_driver_results, 1},
    {"zrt_issue_error_for_tests", (DL_FUNC)&zrt_issue_error_for_tests, 0},
    {"zrt_cfun_fill", (DL_FUNC)&zrt_cfun_fill, 2},
    {"zrt_test_cfun_counter", (DL_FUNC)&zrt_test_cfun_counter, 2},
    {"zrt_test_generator", (DL_FUNC)&zrt_test_generator, 3},
    {"zrt_practrand_version", (DL_FUNC)&zrt_practrand_version, 0},
    {NULL, NULL, 0}};

void attribute_visible R_init_zurngtest(DllInfo *dll) {
  R_registerRoutines(dll, NULL, call_methods, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
  R_forceSymbols(dll, TRUE);
  R_RegisterCCallable("zurngtest", "zurngtest_test_cfun",
                      (DL_FUNC)&zrt_test_cfun);
}

} // extern "C"
