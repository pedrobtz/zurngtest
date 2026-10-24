test_that("the shared library exports only R_init_zurngtest", {
  skip_unless_symbol_checks()
  # libstdc++ declares namespace std with default visibility, so the
  # instantiations of std::vector, std::string and the like that the library
  # uses stay exported on Linux under -fvisibility=hidden, as do the inline
  # placement forms of operator new and delete from <new>. They are not the
  # package's symbols; every other one must be hidden. The first pattern
  # matches mangled names in std or __gnu_cxx, with their typeinfo, guard
  # variables and local entities.
  std_symbol <- paste0(
    "^_Z(T[A-Z]|GVZ?|Z)?N?[rVKRO]*(St|9__gnu_cxx)",
    "|^_Z(nw|na)[jm]Pv$|^_Z(dl|da)PvS_$"
  )
  exported <- exported_symbols()
  expect_equal(
    grep(std_symbol, exported, value = TRUE, invert = TRUE),
    "R_init_zurngtest"
  )
})

test_that("compiled code links nothing that writes to the console or ends R", {
  skip_unless_symbol_checks()
  # A DLL's imports are not in nm's listing; R CMD check covers Windows.
  skip_on_os("windows")
  undefined <- undefined_symbols()
  # nm must have read the library: the R API calls in init.cpp are there.
  expect_contains(undefined, c("Rf_mkString", "R_registerRoutines"))
  expect_equal(intersect(undefined, banned_symbols()), character())
})

test_that("the .Call entry points are registered and found only as symbols", {
  routines <- getDLLRegisteredRoutines("zurngtest")[[".Call"]]
  expect_setequal(
    names(routines),
    c(
      "zrt_cfun_fill",
      "zrt_driver_feed",
      "zrt_driver_free",
      "zrt_driver_new",
      "zrt_driver_results",
      "zrt_issue_error_for_tests",
      "zrt_practrand_version",
      "zrt_test_cfun_counter",
      "zrt_test_generator"
    )
  )
  # R_useDynamicSymbols(FALSE) and R_forceSymbols(TRUE): no lookup by name.
  expect_error(.Call("zrt_practrand_version", PACKAGE = "zurngtest"))
})
