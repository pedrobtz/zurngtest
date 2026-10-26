# Changelog

## zurngtest 0.1.0

- Initial CRAN submission.
- [`pract_test()`](https://pedrobtz.github.io/zurngtest/reference/pract_test.md)
  runs the core or expanded battery of PractRand 0.96, by Chris
  Doty-Humphrey, on a source of bits at doubling lengths. It returns one
  row per test result and length, with PractRand’s own evaluation, and
  the first length at which the source failed. With the core battery its
  results equal those of PractRand’s `RNG_test` on the same bytes. A run
  cut short by the source ending, an interrupt or an error PractRand
  raises returns the lengths completed, and its `stopped` attribute says
  why.
- Sources of bits:
  [`pract_raw()`](https://pedrobtz.github.io/zurngtest/reference/pract_raw.md)
  for raw vectors and connections,
  [`pract_fun()`](https://pedrobtz.github.io/zurngtest/reference/pract_raw.md)
  for R functions,
  [`pract_rng()`](https://pedrobtz.github.io/zurngtest/reference/pract_rng.md)
  for R’s own generators, tested on the integers behind
  [`runif()`](https://rdrr.io/r/stats/Uniform.html) wherever they can be
  recovered and without changing the session’s random numbers, and
  [`pract_interleave()`](https://pedrobtz.github.io/zurngtest/reference/pract_interleave.md)
  to combine sources word by word.
- Generator packages can test a generator written in C through the
  registered C callable `zurngtest_test_cfun()`, declared in
  `inst/include/zurngtest.h`, at about the speed of `RNG_test`.
- [`zurngtest_info()`](https://pedrobtz.github.io/zurngtest/reference/zurngtest_info.md)
  reports the package and PractRand versions and the batteries.
