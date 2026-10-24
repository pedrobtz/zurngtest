test_that("the C callable gives the same results as pract_test() on the same words", {
  options <- list(
    min_bytes = 2^16,
    max_bytes = 2^17,
    stop_on_failure = FALSE,
    folding = FALSE
  )
  from_c <- .Call(zrt_test_cfun_counter, 0, options)
  counter <- local({
    next_word <- 0L
    function(n) {
      words <- next_word + seq_len(n) - 1L
      next_word <<- next_word + as.integer(n)
      words
    }
  })
  from_r <- do.call(pract_test, c(list(pract_fun(counter)), options))
  expect_s3_class(from_c, "zurngtest_result")
  expect_equal(attr(from_c, "source"), "C function, 32-bit words")
  strip <- function(x) {
    attributes(x)[c("elapsed", "source")] <- NULL
    x
  }
  expect_equal(strip(from_c), strip(from_r))
  # A counter fails at once.
  expect_equal(attr(from_c, "failed_at"), 2^16)
})

test_that("the C callable takes NULL options", {
  res <- .Call(zrt_test_cfun_counter, 0, NULL)
  expect_s3_class(res, "zurngtest_result")
  # The defaults run to 16 GiB, so this checks they stop at the failure.
  expect_equal(attr(res, "failed_at"), 2^20)
})

test_that("the C callable takes only pract_test() arguments, by name", {
  bad <- list(
    list(1),
    list(maxbytes = 2^20),
    list(source = 1),
    list(min_bytes = 2^16, 2^20),
    list(min_bytes = 2^16, min_bytes = 2^17),
    "core"
  )
  for (options in bad) {
    expect_error(
      .Call(zrt_test_cfun_counter, 0, options),
      class = "zurngtest_invalid_argument"
    )
  }
  expect_error(
    .Call(zrt_test_cfun_counter, 0, list(battery = "x")),
    class = "zurngtest_invalid_argument"
  )
})

test_that("a C generator's source is gone once its call has returned", {
  # The source outlives the call through anything that keeps it, here a
  # calling handler; its generator lived on the C stack.
  kept <- NULL
  expect_error(
    withCallingHandlers(
      .Call(zrt_test_cfun_counter, 0, list(min_bytes = 1)),
      zurngtest_error = function(cnd) kept <<- dynGet("source")
    ),
    class = "zurngtest_invalid_argument"
  )
  expect_s3_class(kept, "zurngtest_source")
  expect_error(
    pract_test(kept, min_bytes = 2^16, max_bytes = 2^16),
    class = "zurngtest_source_error"
  )
})

test_that("an error from the C callable names pract_test(), not the source", {
  cnd <- expect_error(
    .Call(zrt_test_cfun_counter, 0, list(min_bytes = 1)),
    class = "zurngtest_invalid_argument"
  )
  expect_equal(conditionCall(cnd), quote(pract_test(source, min_bytes = 1)))
})

test_that("the test generators reject an unknown name", {
  expect_error(known_generator("none"), "unknown test generator")
})

test_that("the C header is installed", {
  # LinkingTo users find it here; under load_all() this is inst/include.
  header <- system.file("include", "zurngtest.h", package = "zurngtest")
  expect_true(nzchar(header))
})

test_that("inst/include/zurngtest.h compiles standalone as C99 and C++", {
  skip_on_cran()
  header <- system.file("include", "zurngtest.h", package = "zurngtest")
  r <- file.path(R.home("bin"), "R")
  cc <- system2(r, c("CMD", "config", "CC"), stdout = TRUE)
  cxx <- system2(r, c("CMD", "config", "CXX"), stdout = TRUE)
  includes <- paste0("-I", c(R.home("include"), dirname(header)))
  check <- function(compiler, ext, std) {
    src <- withr::local_tempfile(fileext = ext)
    writeLines(c('#include "zurngtest.h"', "int zurngtest_header_ok;"), src)
    args <- c(std, "-Wall", "-pedantic", "-fsyntax-only", includes, src)
    parts <- strsplit(compiler, " ", fixed = TRUE)[[1]]
    out <- suppressWarnings(system2(
      parts[[1]],
      c(parts[-1], args),
      stdout = TRUE,
      stderr = TRUE
    ))
    expect_null(attr(out, "status"))
    # R's own headers draw C99 -pedantic warnings (R_ext/Complex.h); only
    # this header's count.
    expect_equal(
      grep("zurngtest\\.h:[0-9]+:[0-9]+: (warning|error)", out, value = TRUE),
      character()
    )
  }
  check(cc, ".c", "-std=c99")
  check(cxx, ".cpp", "-std=c++11")
})
