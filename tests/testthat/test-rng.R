test_that("pract_rng() recovers each 32-bit kind's integers exactly", {
  # unif_rand() is the integer times these constants, from R's
  # src/main/RNG.c (MT_genrand(), i2_32m1 and normc), so each word must be
  # the integer that gives back runif()'s number.
  constants <- c(
    "Mersenne-Twister" = 2.3283064365386963e-10,
    "Marsaglia-Multicarry" = 2.328306437080797e-10,
    "Super-Duper" = 2.328306437080797e-10,
    "L'Ecuyer-CMRG" = 2.328306549295727688e-10
  )
  for (kind in names(constants)) {
    got <- draws(kind, 1000)
    expect_nearest(unsigned(got$words), got$u, constants[[kind]], kind)
  }
})

test_that("pract_rng() takes Wichmann-Hill's 32 most significant bits", {
  got <- draws("Wichmann-Hill", 1000)
  expect_identical(unsigned(got$words), floor(got$u * 2^32))
})

test_that("pract_rng() packs the Knuth kinds' 30-bit integers exactly", {
  for (kind in c("Knuth-TAOCP", "Knuth-TAOCP-2002")) {
    got <- draws(kind, 8, bytes_each = 30 / 8)
    # Unpack 8 values of 30 bits, most significant bit first.
    bits <- unlist(lapply(as.integer(got$words), function(b) {
      rev(as.integer(intToBits(b))[1:8])
    }))
    values <- colSums(matrix(bits, nrow = 30) * 2^(29:0))
    # unif_rand() is the integer times KT (R's src/main/RNG.c), not 2^-30.
    expect_nearest(values, got$u, 9.31322574615479e-10, kind)
  }
})

test_that("pract_rng() leaves the user's stream as it was", {
  withr::local_seed(11, .rng_kind = "Mersenne-Twister")
  before <- .Random.seed
  res <- pract_test(
    pract_rng("Wichmann-Hill", seed = 1),
    min_bytes = 2^16,
    max_bytes = 2^16,
    folding = FALSE
  )
  expect_equal(.Random.seed, before)
  expect_equal(RNGkind()[[1]], "Mersenne-Twister")
})

test_that("pract_rng() leaves the session's generator alone between draws", {
  withr::local_seed(11, .rng_kind = "Mersenne-Twister")
  before <- .Random.seed
  reader <- pract_rng("Super-Duper", seed = 1)$open()
  expect_equal(.Random.seed, before)
  reader$fill(8)
  expect_equal(.Random.seed, before)
  expect_equal(RNGkind()[[1]], "Mersenne-Twister")
  reader$close()
  expect_equal(.Random.seed, before)
})

test_that("a run that fails at the source leaves the session's generator", {
  withr::local_seed(11, .rng_kind = "Mersenne-Twister")
  before <- .Random.seed
  # The raw source ends after one block, while pract_rng() is mid-run; a
  # Knuth kind's packed bits, like raw bytes, have no word size.
  source <- pract_interleave(pract_rng("Knuth-TAOCP"), pract_raw(raw(1024)))
  expect_error(
    pract_test(source, min_bytes = 2^16),
    class = "zurngtest_source_error"
  )
  expect_equal(.Random.seed, before)
  expect_equal(RNGkind()[[1]], "Mersenne-Twister")
})

test_that("a failure to set the generator puts the session's back", {
  withr::local_seed(11, .rng_kind = "Wichmann-Hill")
  before <- .Random.seed
  expect_error(suppressWarnings(switch_rng("Super-Duper", 2^31)))
  expect_equal(.Random.seed, before)
  expect_equal(RNGkind()[[1]], "Wichmann-Hill")
})

test_that("pract_rng() removes a .Random.seed it created", {
  withr::local_seed(1, .rng_kind = "Mersenne-Twister")
  rm(".Random.seed", envir = globalenv())
  reader <- pract_rng("Super-Duper")$open()
  reader$fill(8)
  reader$close()
  # R seeds its current kind on the next draw, so it must be the session's.
  expect_equal(RNGkind()[[1]], "Mersenne-Twister")
  expect_false(exists(".Random.seed", envir = globalenv(), inherits = FALSE))
})

test_that("pract_rng() checks the kind and the seed", {
  expect_error(pract_rng("Unknown"), class = "zurngtest_invalid_argument")
  expect_error(pract_rng(seed = "a"), class = "zurngtest_invalid_argument")
  expect_error(pract_rng(seed = NA), class = "zurngtest_invalid_argument")
  for (seed in c(1.5, 2^31, -2^31, 1e10)) {
    expect_error(
      pract_rng("Wichmann-Hill", seed = seed),
      class = "zurngtest_invalid_argument"
    )
  }
  expect_s3_class(pract_rng(seed = -.Machine$integer.max), "zurngtest_source")
})

test_that("pract_rng() reports a kind R cannot set as a source error", {
  # No user-supplied generator is loaded, so RNGkind() refuses it.
  withr::local_seed(11, .rng_kind = "Mersenne-Twister")
  before <- .Random.seed
  expect_error(
    pract_test(pract_rng("user-supplied"), min_bytes = 2^16),
    class = "zurngtest_source_error"
  )
  expect_equal(.Random.seed, before)
})

test_that("pract_rng() describes how each kind's bits are taken", {
  expect_snapshot({
    for (kind in names(rng_kinds)) {
      print(pract_rng(kind))
    }
  })
})

test_that("Mersenne-Twister passes a short run", {
  res <- pract_test(pract_rng(), min_bytes = 2^18, max_bytes = 2^18)
  expect_true(is.na(attr(res, "failed_at")))
})
