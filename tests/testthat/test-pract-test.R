test_that("pract_test() returns results per length with their attributes", {
  res <- quick_test(repeating(2^16), min_bytes = 2^16, max_bytes = 2^16)
  expect_s3_class(res, c("zurngtest_result", "data.frame"))
  expect_named(res, c("bytes", "test", "p_value", "evaluation"))
  expect_equal(unique(res$bytes), 2^16)
  expect_equal(attr(res, "source"), "raw vector of 65536 bytes")
  expect_type(attr(res, "elapsed"), "double")
})

test_that("a weak source fails at the first length and stops there", {
  res <- quick_test(repeating(2^18), min_bytes = 2^16, max_bytes = 2^18)
  expect_equal(attr(res, "failed_at"), 2^16)
  expect_equal(unique(res$bytes), 2^16)
  expect_true(any(startsWith(res$evaluation, "FAIL")))
})

test_that("stop_on_failure = FALSE tests every length", {
  res <- quick_test(
    repeating(2^18),
    min_bytes = 2^16,
    max_bytes = 2^18,
    stop_on_failure = FALSE
  )
  expect_equal(unique(res$bytes), c(2^16, 2^17, 2^18))
  expect_equal(attr(res, "failed_at"), 2^16)
})

test_that("a good source passes a short run", {
  withr::local_seed(1)
  res <- pract_test(r_bytes(), min_bytes = 2^18, max_bytes = 2^20)
  expect_true(is.na(attr(res, "failed_at")))
  expect_equal(unique(res$bytes), c(2^18, 2^19, 2^20))
  expect_false(any(startsWith(res$evaluation, "FAIL")))
})

test_that("seed reaches the tests that use it", {
  skip_on_cran() # the expanded battery, whose tests use it: seconds each
  run <- function(seed) {
    res <- pract_test(
      repeating(2^16),
      battery = "expanded",
      min_bytes = 2^16,
      max_bytes = 2^16,
      seed = seed
    )
    res$p_value
  }
  expect_identical(run(1), run(1))
  expect_false(identical(run(1), run(2)))
})

test_that("the same seed gives the same results", {
  run <- function() {
    quick_test(repeating(2^16), min_bytes = 2^16, max_bytes = 2^16, seed = 7)
  }
  without_time <- function(x) {
    attr(x, "elapsed") <- NULL
    x
  }
  expect_equal(without_time(run()), without_time(run()))
})

test_that("a source that ends early ends the run at the bytes it gave", {
  source <- pract_raw(rep(as.raw(0:255), length.out = 3 * 2^16 + 500))
  res <- quick_test(
    source,
    min_bytes = 2^16,
    max_bytes = 2^20,
    stop_on_failure = FALSE
  )
  # Two whole lengths, then the 3 * 2^16 bytes tested; the 500-byte tail is
  # less than a block and is dropped.
  expect_equal(unique(res$bytes), c(2^16, 2^17, 3 * 2^16))
})

test_that("a source that ends before min_bytes is a source error", {
  expect_error(
    pract_test(pract_raw(raw(2^12)), min_bytes = 2^16),
    class = "zurngtest_source_error"
  )
  con <- rawConnection(raw(2^12))
  withr::defer(close(con))
  expect_error(
    pract_test(pract_raw(con), min_bytes = 2^16),
    class = "zurngtest_source_error"
  )
})

test_that("pract_test() closes a connection it opened, on success and on error", {
  path <- withr::local_tempfile()
  writeBin(as.raw(rep(0:255, 2^8)), path)
  con <- file(path)
  quick_test(pract_raw(con), min_bytes = 2^16, max_bytes = 2^16)
  # Closing destroys the connection.
  expect_error(isOpen(con))
  con <- file(path)
  expect_error(
    quick_test(pract_raw(con), min_bytes = 2^17),
    class = "zurngtest_source_error"
  )
  expect_error(isOpen(con))
})

test_that("pract_test() leaves an open connection open", {
  con <- rawConnection(as.raw(rep(0:255, 2^8)))
  withr::defer(close(con))
  quick_test(pract_raw(con), min_bytes = 2^16, max_bytes = 2^16)
  expect_true(isOpen(con))
})

test_that("pract_test() frees its driver on success and on error", {
  freed <- list()
  free <- driver_free
  local_mocked_bindings(driver_free = function(driver) {
    freed[[length(freed) + 1]] <<- driver
    free(driver)
  })
  quick_test(repeating(2^16), min_bytes = 2^16, max_bytes = 2^16)
  expect_error(
    quick_test(repeating(2^12), min_bytes = 2^16),
    class = "zurngtest_source_error"
  )
  expect_length(freed, 2)
  for (driver in freed) {
    expect_error(driver_results(driver), class = "zurngtest_internal_error")
  }
})

test_that("an error while feeding PractRand ends the run with a warning", {
  # No input is known to make PractRand 0.96 fail while testing, so a
  # stand-in error takes the place of one (src/driver.cpp).
  calls <- 0
  feed <- driver_feed
  local_mocked_bindings(driver_feed = function(driver, data) {
    calls <<- calls + 1
    if (calls == 2) {
      zurngtest_abort("a stand-in", "zurngtest_practrand_error")
    }
    feed(driver, data)
  })
  expect_warning(
    res <- quick_test(
      repeating(2^18),
      min_bytes = 2^16,
      max_bytes = 2^18,
      stop_on_failure = FALSE
    ),
    class = "zurngtest_stopped"
  )
  expect_equal(unique(res$bytes), 2^16)
  expect_equal(attr(res, "stopped"), "practrand")
})

test_that("an error that is not PractRand's is an error, not a warning", {
  feed <- driver_feed
  local_mocked_bindings(driver_feed = function(driver, data) {
    zurngtest_abort("a failed allocation", "zurngtest_internal_error")
  })
  expect_error(
    quick_test(repeating(2^16), min_bytes = 2^16, max_bytes = 2^16),
    class = "zurngtest_internal_error"
  )
})

test_that("an interrupt returns the lengths already completed", {
  calls <- 0
  source <- pract_fun(
    function(n) {
      calls <<- calls + 1
      if (calls == 3) {
        signalCondition(structure(
          class = c("interrupt", "condition"),
          list(message = "", call = NULL)
        ))
      }
      as.raw(rep(0:255, length.out = n))
    },
    bits = 8
  )
  expect_warning(
    res <- pract_test(
      source,
      min_bytes = 2^16,
      max_bytes = 2^20,
      stop_on_failure = FALSE
    ),
    class = "zurngtest_stopped"
  )
  expect_equal(unique(res$bytes), c(2^16, 2^17))
  expect_equal(attr(res, "stopped"), "interrupt")
})

test_that("a run says why it ended early, and not otherwise", {
  full <- quick_test(repeating(2^17), min_bytes = 2^16, max_bytes = 2^17)
  expect_equal(attr(full, "stopped"), NA_character_)
  short <- quick_test(
    repeating(3 * 2^16),
    min_bytes = 2^16,
    max_bytes = 2^20,
    stop_on_failure = FALSE
  )
  expect_equal(attr(short, "stopped"), "source")
})

test_that("a source ending on a length reports that length once", {
  # The source ends at exactly 2^17: the next length has no data of its own,
  # so 2^17 is not reported again as a partial length.
  res <- quick_test(
    repeating(2^17),
    min_bytes = 2^16,
    max_bytes = 2^20,
    stop_on_failure = FALSE
  )
  expect_equal(unique(res$bytes), c(2^16, 2^17))
  expect_equal(attr(res, "stopped"), "source")
  # One block more, and the partial length is reported.
  res <- quick_test(
    repeating(2^17 + 2^10),
    min_bytes = 2^16,
    max_bytes = 2^20,
    stop_on_failure = FALSE
  )
  expect_equal(unique(res$bytes), c(2^16, 2^17, 2^17 + 2^10))
})

test_that("pract_test() checks its arguments", {
  source <- repeating(2^16)
  expect_error(pract_test(raw(10)), class = "zurngtest_invalid_argument")
  expect_error(
    pract_test(source, battery = "big"),
    class = "zurngtest_invalid_argument"
  )
  expect_error(
    pract_test(source, battery = character()),
    class = "zurngtest_invalid_argument"
  )
  expect_error(
    pract_test(source, min_bytes = 1000),
    class = "zurngtest_invalid_argument"
  )
  expect_error(
    pract_test(source, min_bytes = 512),
    class = "zurngtest_invalid_argument"
  )
  expect_error(
    pract_test(source, min_bytes = 2^20, max_bytes = 2^16),
    class = "zurngtest_invalid_argument"
  )
  expect_error(
    pract_test(source, stop_on_failure = NA),
    class = "zurngtest_invalid_argument"
  )
  expect_error(
    pract_test(source, folding = "yes"),
    class = "zurngtest_invalid_argument"
  )
  expect_error(
    pract_test(source, seed = -1),
    class = "zurngtest_invalid_argument"
  )
  expect_error(
    pract_test(source, seed = 2^53),
    class = "zurngtest_invalid_argument"
  )
  expect_s3_class(
    quick_test(source, min_bytes = 2^16, max_bytes = 2^16, seed = 2^53 - 1),
    "zurngtest_result"
  )
})

test_that("pract_test()'s batteries are the ones zurngtest_info() reports", {
  expect_equal(eval(formals(pract_test)$battery), zurngtest_info()$batteries)
})

test_that("the expanded battery runs, with NA for results without a p-value", {
  skip_on_cran() # about 3 s and 400 MB
  res <- pract_test(
    repeating(2^16),
    battery = "expanded",
    min_bytes = 2^16,
    max_bytes = 2^16
  )
  expect_gt(nrow(res), 100)
  # PractRand 0.96's NS3 tests give NaN p-values; they are NA, unlabelled.
  no_p <- is.na(res$p_value)
  expect_true(any(no_p))
  expect_equal(is.na(res$evaluation), no_p)
  expect_equal(attr(res, "failed_at"), 2^16)
})

test_that("an error PractRand raises ends the run with a warning", {
  skip_on_cran() # the expanded battery: seconds and 400 MB
  # NS3 raises "threshold dropped below 0" on this pattern when reporting
  # at 1 MiB.
  expect_warning(
    res <- pract_test(
      repeating(2^20),
      battery = "expanded",
      min_bytes = 2^16,
      max_bytes = 2^20,
      stop_on_failure = FALSE
    ),
    class = "zurngtest_stopped"
  )
  expect_equal(unique(res$bytes), 2^(16:19))
})

test_that("print() reports a failing run", {
  x <- fixed_result(
    rep(2^16, 3),
    c("FAIL", "normal", "normalish"),
    failed_at = 2^16
  )
  expect_snapshot(print(x))
})

test_that("print() reports a passing run that ended short", {
  x <- fixed_result(
    c(2^20, 2^20, 2^21, 2^21, 2^21, 3 * 2^20),
    c("normal", "normalish", "unusual", "normal", NA, "normal")
  )
  attr(x, "stopped") <- "source"
  expect_snapshot(print(x))
})

test_that("print() says when a run was interrupted", {
  x <- fixed_result(2^16, "normal")
  attr(x, "stopped") <- "interrupt"
  expect_snapshot(print(x))
})

test_that("print() shows the source, the lengths and the anomalies", {
  res <- pract_test(repeating(2^16), min_bytes = 2^16, max_bytes = 2^16)
  out <- capture.output(print(res))
  expect_match(out[[1]], "raw vector of 65536 bytes", fixed = TRUE)
  expect_true(any(grepl("length= 64 kilobytes", out, fixed = TRUE)))
  expect_true(any(grepl("FAIL", out, fixed = TRUE)))
  # Every result line starts with exactly two spaces.
  rows <- grep("FAIL", out, value = TRUE)
  expect_true(all(grepl("^  [^ ]", rows)))
})
