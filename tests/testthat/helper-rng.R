# Helpers for the pract_rng() tests.

# The words a reader gives, as unsigned 32-bit values.
unsigned <- function(words) {
  x <- as.double(words)
  x[is.na(words)] <- 2^31
  x + ifelse(!is.na(words) & words < 0, 2^32, 0)
}

# Each of `k` is the integer that times `constant` gives `u`: any other
# integer is a whole `constant` away, far beyond rounding error (valgrind
# was seen to change the last bit of one product).
expect_nearest <- function(k, u, constant, kind) {
  expect_identical(k, round(k), label = kind)
  expect_lt(max(abs(k * constant - u)), constant / 4, label = kind)
}

# A kind's first n numbers from runif() and from a pract_rng() reader.
draws <- function(kind, n, bytes_each = 4) {
  reader <- pract_rng(kind, seed = 3)$open()
  words <- reader$fill(n * bytes_each)
  reader$close()
  list(
    words = words,
    # RNGkind() warns that Marsaglia-Multicarry is poor.
    u = suppressWarnings(withr::with_seed(3, stats::runif(n), .rng_kind = kind))
  )
}
