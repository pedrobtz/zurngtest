# Changelog

## zurngtest 0.0.0.9000

- [`zurngtest_info()`](https://pedrobtz.github.io/zurngtest/reference/zurngtest_info.md)
  reports the package version and the test batteries.
- Every condition the package signals inherits `zurngtest_error`.
- Bundles PractRand 0.96, compiled without output to the console and
  without calls that end R;
  [`zurngtest_info()`](https://pedrobtz.github.io/zurngtest/reference/zurngtest_info.md)
  reports its version.
- [`pract_test()`](https://pedrobtz.github.io/zurngtest/reference/pract_test.md)
  runs PractRand’s core or expanded battery on a source at doubling
  lengths and returns a `zurngtest_result`: one row per test result per
  length, with PractRand’s evaluation, the first failing length and a
  [`print()`](https://rdrr.io/r/base/print.html) method in the style of
  `RNG_test`.
- [`pract_raw()`](https://pedrobtz.github.io/zurngtest/reference/pract_raw.md)
  and
  [`pract_fun()`](https://pedrobtz.github.io/zurngtest/reference/pract_raw.md)
  make sources from raw bytes, connections and R functions.
- [`pract_rng()`](https://pedrobtz.github.io/zurngtest/reference/pract_rng.md)
  tests one of R’s own generators on its own bits, recovering the
  integers behind [`runif()`](https://rdrr.io/r/stats/Uniform.html)
  where they exist, and leaves the session’s random number stream as it
  was.
- [`pract_interleave()`](https://pedrobtz.github.io/zurngtest/reference/pract_interleave.md)
  combines sources word by word, for seeding studies.
- Packages can test a generator written in C through the registered
  callable `zurngtest_test_cfun()`, declared in
  `inst/include/zurngtest.h`.
- [`pract_test()`](https://pedrobtz.github.io/zurngtest/reference/pract_test.md)
  gives the results PractRand’s own `RNG_test` gives for the same bytes,
  p-values near 0 and 1 included; a CI workflow checks this.
- [`?pract_test`](https://pedrobtz.github.io/zurngtest/reference/pract_test.md)
  documents PractRand’s evaluations and their thresholds; a new article,
  “Testing a generator package”, shows how to test a package’s
  generators from R and from C.
- [`print()`](https://rdrr.io/r/base/print.html) on a result no longer
  indents its second and later result lines by an extra space.
- The tests run only where testthat is installed, so the package checks
  cleanly without its suggested packages.
