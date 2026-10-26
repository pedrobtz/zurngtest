# pract_rng() describes how each kind's bits are taken

    Code
      for (kind in names(rng_kinds)) {
        print(pract_rng(kind))
      }
    Output
      <zurngtest_source> R's Mersenne-Twister generator (seed 1), its 32-bit integers
      <zurngtest_source> R's Marsaglia-Multicarry generator (seed 1), its 32-bit integers
      <zurngtest_source> R's Super-Duper generator (seed 1), its 32-bit integers
      <zurngtest_source> R's L'Ecuyer-CMRG generator (seed 1), its integers, 1 to 4294967087
      <zurngtest_source> R's Knuth-TAOCP generator (seed 1), its 30-bit integers, packed into a bit stream
      <zurngtest_source> R's Knuth-TAOCP-2002 generator (seed 1), its 30-bit integers, packed into a bit stream
      <zurngtest_source> R's Wichmann-Hill generator (seed 1), the 32 most significant bits of each double
      <zurngtest_source> R's user-supplied generator (seed 1), the 32 most significant bits of each double

