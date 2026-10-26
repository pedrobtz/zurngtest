# Sources for the pract_test() tests.

# A source that fails at once: a 256-byte pattern, repeated.
repeating <- function(bytes) {
  pract_raw(rep(as.raw(0:255), length.out = bytes))
}

# A source that passes short runs: bytes from R's generator.
r_bytes <- function() {
  pract_fun(function(n) as.raw(sample.int(256L, n, TRUE) - 1L), bits = 8)
}

# pract_test() without the standard foldings, which triple a short run's
# cost; for tests that are not about folding.
quick_test <- function(source, ...) {
  pract_test(source, folding = FALSE, ...)
}

# A result as pract_test() returns it, with chosen rows, so that print() is
# checked on fixed numbers.
fixed_result <- function(bytes, evaluation, failed_at = NA_real_) {
  p_value <- c(
    normal = 0.5,
    normalish = 0.3,
    unusual = 0.01,
    FAIL = 1e-12
  )[evaluation]
  structure(
    data.frame(
      bytes = bytes,
      test = sprintf("Test%d", seq_along(bytes)),
      p_value = unname(p_value),
      evaluation = evaluation,
      stringsAsFactors = FALSE
    ),
    class = c("zurngtest_result", "data.frame"),
    failed_at = failed_at,
    stopped = NA_character_,
    source = "a fixed source",
    elapsed = 0
  )
}
