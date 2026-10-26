# Generators with known PractRand results. Each length is the one PractRand's
# own RNG_test reports for the same stream (roadmap, Stage 4).

test_that("a full-output 32-bit LCG fails at 4 KiB", {
  res <- known_generator("lcg32", min_bytes = 2^10, max_bytes = 2^16)
  expect_equal(attr(res, "failed_at"), 2^12)
})

test_that("xorshift32 fails at 16 KiB", {
  res <- known_generator("xorshift32", min_bytes = 2^10, max_bytes = 2^16)
  expect_equal(attr(res, "failed_at"), 2^14)
})

test_that("hc256 passes to 256 MiB", {
  skip_unless_long_tests()
  res <- known_generator("hc256", min_bytes = 2^20, max_bytes = 2^28)
  expect_true(is.na(attr(res, "failed_at")))
  expect_equal(max(res$bytes), 2^28)
  expect_equal(attr(res, "stopped"), NA_character_)
})

test_that("std::mt19937 passes to 1 GiB", {
  # It fails PractRand's binary-rank tests only at 256 GiB, too long to run.
  skip_unless_long_tests()
  res <- known_generator("mt19937", min_bytes = 2^20, max_bytes = 2^30)
  expect_true(is.na(attr(res, "failed_at")))
  expect_equal(max(res$bytes), 2^30)
  expect_equal(attr(res, "stopped"), NA_character_)
})

test_that("R's Mersenne-Twister passes to 64 MiB through pract_rng()", {
  skip_unless_long_tests()
  res <- pract_test(pract_rng(), min_bytes = 2^20, max_bytes = 2^26)
  expect_true(is.na(attr(res, "failed_at")))
  expect_equal(max(res$bytes), 2^26)
  expect_equal(attr(res, "stopped"), NA_character_)
})
