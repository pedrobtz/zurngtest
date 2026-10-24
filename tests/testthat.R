# This file is part of the standard setup for testthat.
#
# Where should you do additional test configuration?
# Learn more about the roles of various files in:
# * https://r-pkgs.org/testing-design.html#sec-tests-files-overview
# * https://testthat.r-lib.org/articles/special-files.html
#
# testthat is suggested, not imported: CRAN's NOSUGGESTS flavor checks the
# package without it, so the suite runs only where it is installed.

if (requireNamespace("testthat", quietly = TRUE)) {
  library(testthat)
  library(zurngtest)
  test_check("zurngtest")
}
