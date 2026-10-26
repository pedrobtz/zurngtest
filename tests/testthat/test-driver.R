test_that("an error inside PractRand reaches R as zurngtest_practrand_error", {
  expect_error(
    .Call(zrt_issue_error_for_tests),
    class = "zurngtest_practrand_error"
  )
})

test_that("the driver tests fed blocks and labels the results", {
  driver <- driver_new("core", folding = FALSE, bits = 0L, seed = 1)
  driver_feed(driver, as.raw(rep(0:255, 4096)))
  res <- driver_results(driver)
  expect_named(res, c("test", "p_value", "evaluation"))
  expect_gt(length(res$test), 0)
  expect_type(res$p_value, "double")
  # 1 MiB of a repeating 256-byte pattern fails at once.
  expect_true(any(startsWith(res$evaluation, "FAIL")))
})

test_that("the driver rejects data that is not whole blocks", {
  driver <- driver_new("core", folding = FALSE, bits = 0L, seed = 1)
  expect_error(
    driver_feed(driver, raw(1000)),
    class = "zurngtest_internal_error"
  )
  expect_error(
    driver_feed(driver, 1.5),
    class = "zurngtest_internal_error"
  )
})

test_that("integer words and their bytes give the same results", {
  words <- rep(c(1L, -1L, 7L, 123456789L), 2^16)
  run <- function(data) {
    driver <- driver_new("core", folding = TRUE, bits = 32L, seed = 1)
    driver_feed(driver, data)
    driver_results(driver)
  }
  expect_equal(
    run(words),
    run(writeBin(words, raw(), endian = .Platform$endian))
  )
})

test_that("a freed driver is not live", {
  driver <- driver_new("core", folding = FALSE, bits = 0L, seed = 1)
  driver_free(driver)
  expect_error(
    driver_feed(driver, raw(1024)),
    class = "zurngtest_internal_error"
  )
  expect_error(driver_results(driver), class = "zurngtest_internal_error")
  # Freeing twice, or leaving it to the finalizer after, does nothing.
  expect_silent(driver_free(driver))
  expect_silent(gc())
})

test_that("anything but a live driver is rejected", {
  expect_error(driver_feed(NULL, raw(1024)), class = "zurngtest_internal_error")
  expect_error(driver_results(NULL), class = "zurngtest_internal_error")
  # A serialized driver comes back with a NULL address.
  driver <- driver_new("core", folding = FALSE, bits = 0L, seed = 1)
  restored <- unserialize(serialize(driver, NULL))
  expect_error(driver_results(restored), class = "zurngtest_internal_error")
})

test_that("the driver's buffer holds runs shorter than a chunk", {
  driver <- driver_new("core", FALSE, bits = 0L, seed = 1, max_bytes = 2^16)
  # More than the buffer at once: fed in chunks of max_bytes.
  driver_feed(driver, as.raw(rep(0:255, 2^10)))
  expect_gt(length(driver_results(driver)$test), 0)
})
