# argument errors name the function called

    Code
      pract_test(raw(10))
    Condition
      Error in `pract_test()`:
      ! `source` must come from pract_raw(), pract_fun(), pract_rng() or pract_interleave().
    Code
      pract_test(pract_raw(raw(1024)), min_bytes = 1000)
    Condition
      Error in `pract_test()`:
      ! `min_bytes` must be a power of two of at least 1024.
    Code
      pract_raw(1)
    Condition
      Error in `pract_raw()`:
      ! `x` must be a raw vector or a connection.
    Code
      pract_fun(function(n) integer(n), bits = 7)
    Condition
      Error in `pract_fun()`:
      ! `bits` must be 8, 16, 32 or 64.
    Code
      pract_rng("Unknown")
    Condition
      Error in `pract_rng()`:
      ! `kind` must be one of "Mersenne-Twister", "Marsaglia-Multicarry", "Super-Duper", "L'Ecuyer-CMRG", "Knuth-TAOCP", "Knuth-TAOCP-2002", "Wichmann-Hill", "user-supplied".
    Code
      pract_interleave(pract_raw(raw(4)))
    Condition
      Error in `pract_interleave()`:
      ! Interleaving needs at least two sources.

# source errors name pract_test()

    Code
      pract_test(pract_raw(raw(2^12)), min_bytes = 2^16)
    Condition
      Error in `pract_test()`:
      ! The source ended after 4096 bytes, before `min_bytes` (65536).
    Code
      pract_test(short, min_bytes = 2^16)
    Condition
      Error in `pract_test()`:
      ! `f` returned 1 elements where 16384 were asked for.

# C callable errors name pract_test() without the source

    Code
      .Call(zrt_test_cfun_counter, 0, list(maxbytes = 2^20))
    Condition
      Error in `zurngtest_test_cfun()`:
      ! `options` must be NULL or a list of pract_test() arguments by name: battery, min_bytes, max_bytes, stop_on_failure, folding, seed.
    Code
      .Call(zrt_test_cfun_counter, 0, list(min_bytes = 1))
    Condition
      Error in `pract_test()`:
      ! `min_bytes` must be a power of two of at least 1024.

