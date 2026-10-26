test_that("pract_interleave() takes one word from each source in turn", {
  a <- pract_fun(function(n) seq_len(n), bits = 32)
  b <- pract_fun(function(n) -seq_len(n), bits = 32)
  source <- pract_interleave(a, b)
  expect_equal(source$bits, 32L)
  bytes <- source$open()$fill(16)
  expected <- writeBin(c(1L, -1L, 2L, -2L), raw(), endian = .Platform$endian)
  expect_equal(bytes, expected)
})

test_that("pract_interleave() interleaves raw bytes byte by byte", {
  source <- pract_interleave(pract_raw(as.raw(1:4)), pract_raw(as.raw(11:14)))
  expect_equal(source$open()$fill(6), as.raw(c(1, 11, 2, 12, 3, 13)))
})

test_that("pract_interleave() serves requests that are not whole rounds", {
  parts <- lapply(1:3, function(k) pract_fun(function(n) rep(k, n), bits = 32))
  reader <- do.call(pract_interleave, parts)$open()
  first <- reader$fill(1024)
  second <- reader$fill(1024)
  words <- readBin(
    c(first, second),
    "integer",
    n = 512,
    endian = .Platform$endian
  )
  expect_equal(words, rep_len(1:3, 512))
})

test_that("pract_interleave() ends when a source ends", {
  source <- pract_interleave(pract_raw(as.raw(1:3)), pract_raw(as.raw(11:20)))
  reader <- source$open()
  expect_equal(reader$fill(100), as.raw(c(1, 11, 2, 12, 3, 13)))
})

test_that("pract_interleave() needs sources of one word size", {
  expect_error(
    pract_interleave(pract_raw(raw(4)), pract_fun(function(n) integer(n))),
    class = "zurngtest_invalid_argument"
  )
})

test_that("pract_interleave() needs two or more sources", {
  expect_error(
    pract_interleave(pract_raw(raw(4))),
    class = "zurngtest_invalid_argument"
  )
  expect_error(
    pract_interleave(pract_raw(raw(4)), raw(4)),
    class = "zurngtest_invalid_argument"
  )
})

test_that("two seeds of one generator interleave into a testable stream", {
  source <- pract_interleave(pract_rng(seed = 1), pract_rng(seed = 2))
  expect_snapshot(print(source))
  res <- pract_test(source, min_bytes = 2^16, max_bytes = 2^16, folding = FALSE)
  expect_true(is.na(attr(res, "failed_at")))
})

test_that("pract_interleave() closes what it opened when a later open() fails", {
  path <- withr::local_tempfile()
  writeBin(raw(1024), path)
  con <- file(path)
  failing <- new_source(
    function() zurngtest_abort("cannot open", "zurngtest_source_error"),
    bits = 0L,
    description = "a source that cannot open"
  )
  source <- pract_interleave(pract_raw(con), failing)
  expect_error(source$open(), class = "zurngtest_source_error")
  # The connection was opened for the run, so closing destroyed it.
  expect_error(isOpen(con))
})
