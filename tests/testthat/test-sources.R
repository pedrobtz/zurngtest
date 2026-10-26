test_that("pract_raw() reads a raw vector from the start on every open", {
  source <- pract_raw(as.raw(1:10))
  expect_s3_class(source, "zurngtest_source")
  expect_equal(source$bits, 0L)
  reader <- source$open()
  expect_equal(reader$fill(4), as.raw(1:4))
  expect_equal(reader$fill(100), as.raw(5:10))
  expect_equal(reader$fill(4), raw())
  expect_equal(source$open()$fill(2), as.raw(1:2))
})

test_that("pract_raw() reads a connection and closes what it opened", {
  path <- withr::local_tempfile()
  writeBin(as.raw(0:255), path)
  con <- file(path)
  source <- pract_raw(con)
  reader <- source$open()
  expect_equal(reader$fill(3), as.raw(0:2))
  reader$close()
  # close() destroys a connection, as readLines() does with one it opened.
  expect_error(isOpen(con))
})

test_that("pract_raw() rejects anything but raw bytes or a connection", {
  expect_error(pract_raw(1:10), class = "zurngtest_invalid_argument")
  expect_error(pract_raw("x"), class = "zurngtest_invalid_argument")
})

test_that("pract_fun() turns words into bytes", {
  source <- pract_fun(function(n) seq_len(n), bits = 32)
  expect_equal(source$bits, 32L)
  expect_equal(source$open()$fill(8), 1:2)
  source <- pract_fun(function(n) as.raw(seq_len(n * 2)), bits = 16)
  expect_equal(source$open()$fill(4), as.raw(1:4))
})

test_that("pract_fun() takes NA as the bit pattern it is", {
  source <- pract_fun(function(n) rep(NA_integer_, n))
  expect_equal(source$open()$fill(4), NA_integer_)
})

test_that("pract_fun() checks its arguments", {
  expect_error(pract_fun("f"), class = "zurngtest_invalid_argument")
  expect_error(
    pract_fun(function(n) raw(n), bits = 12),
    class = "zurngtest_invalid_argument"
  )
})

test_that("pract_fun() rejects a wrong type or length from f", {
  withr::local_seed(1)
  doubles <- pract_fun(function(n) runif(n))$open()
  expect_error(doubles$fill(8), class = "zurngtest_source_error")
  short <- pract_fun(function(n) integer(n - 1))$open()
  expect_error(short$fill(8), class = "zurngtest_source_error")
  listy <- pract_fun(function(n) as.list(seq_len(n)))$open()
  expect_error(listy$fill(8), class = "zurngtest_source_error")
  wide <- pract_fun(function(n) integer(n), bits = 64)$open()
  expect_error(wide$fill(16), class = "zurngtest_source_error")
})

test_that("a source error records what f returned", {
  short <- pract_fun(function(n) integer(n - 1))$open()
  cnd <- tryCatch(short$fill(8), zurngtest_source_error = identity)
  expect_equal(cnd$expected, 2)
  expect_equal(cnd$actual, 1)
})
