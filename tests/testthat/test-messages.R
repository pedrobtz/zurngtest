# What users read: one error per exported function, and the errors raised
# from inside a source or the C callable, which name pract_test().

test_that("argument errors name the function called", {
  expect_snapshot(error = TRUE, {
    pract_test(raw(10))
    pract_test(pract_raw(raw(1024)), min_bytes = 1000)
    pract_raw(1)
    pract_fun(function(n) integer(n), bits = 7)
    pract_rng("Unknown")
    pract_interleave(pract_raw(raw(4)))
  })
})

test_that("source errors name pract_test()", {
  short <- pract_fun(function(n) integer(1))
  expect_snapshot(error = TRUE, {
    pract_test(pract_raw(raw(2^12)), min_bytes = 2^16)
    pract_test(short, min_bytes = 2^16)
  })
})

test_that("C callable errors name pract_test() without the source", {
  expect_snapshot(error = TRUE, {
    .Call(zrt_test_cfun_counter, 0, list(maxbytes = 2^20))
    .Call(zrt_test_cfun_counter, 0, list(min_bytes = 1))
  })
})
