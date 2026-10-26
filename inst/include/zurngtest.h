/* The zurngtest C interface, for packages that generate random numbers in
 * C or C++ and want to test them with PractRand without R in the loop.
 *
 * Add `LinkingTo: zurngtest` and `Suggests: zurngtest` (or Imports) to the
 * package's DESCRIPTION, include this header, and call zurngtest_test_cfun()
 * from C code that R calls through .Call(), with zurngtest installed. The
 * function is looked up with R_GetCCallable(), so no symbol is linked.
 *
 * Compiles as C99 and as C++. The header includes <Rinternals.h>, so a file
 * that wants R's API without its short names (length, error, ...) defines
 * R_NO_REMAP before including this header, as before any R header.
 */
#ifndef ZURNGTEST_H
#define ZURNGTEST_H

#include <stddef.h>
#include <stdint.h>

#include <Rinternals.h>
#include <R_ext/Rdynload.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Writes the next n 32-bit words of the generator whose state is `state`
 * to out[0], ..., out[n - 1]. Called on the main thread, as often as the
 * test needs more data. */
typedef void (*zurngtest_fill_fn)(void *state, uint32_t *out, size_t n);

/* Tests the words `fill` writes with PractRand and returns the same
 * zurngtest_result data frame as pract_test(). `options` is a named list of
 * further pract_test() arguments (battery, min_bytes, max_bytes,
 * stop_on_failure, folding, seed), or R_NilValue for the defaults. Errors
 * are R errors.
 *
 * The function is looked up once per compilation unit and cached. If
 * zurngtest is unloaded and loaded again in the same session (for example
 * by devtools::load_all()), restart R or reload the calling package too. */
static inline SEXP zurngtest_test_cfun(zurngtest_fill_fn fill, void *state,
                                       SEXP options) {
  static SEXP (*fn)(zurngtest_fill_fn, void *, SEXP) = NULL;
  if (fn == NULL) {
    fn = (SEXP(*)(zurngtest_fill_fn, void *, SEXP))R_GetCCallable(
        "zurngtest", "zurngtest_test_cfun");
  }
  return fn(fill, state, options);
}

#ifdef __cplusplus
}
#endif

#endif /* ZURNGTEST_H */
