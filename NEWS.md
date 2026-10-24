# zurngtest 0.1.0

* Initial CRAN submission.
* `pract_test()` runs the core or expanded battery of PractRand 0.96, by Chris
  Doty-Humphrey, on a source of bits at doubling lengths. It returns one row
  per test result and length, with PractRand's own evaluation, and the first
  length at which the source failed. With the core battery its results equal
  those of PractRand's `RNG_test` on the same bytes.
* Sources of bits: `pract_raw()` for raw vectors and connections,
  `pract_fun()` for R functions, `pract_rng()` for R's own generators, tested
  on the integers behind `runif()` wherever they can be recovered and without
  changing the session's random numbers, and `pract_interleave()` to combine
  sources word by word.
* Generator packages can test a generator written in C through the registered
  C callable `zurngtest_test_cfun()`, declared in `inst/include/zurngtest.h`,
  at about the speed of `RNG_test`.
* `zurngtest_info()` reports the package and PractRand versions and the
  batteries.
