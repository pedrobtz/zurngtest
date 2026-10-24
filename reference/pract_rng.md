# A source of bits from one of R's random number generators

`pract_rng()` tests the generator behind
[`runif()`](https://rdrr.io/r/stats/Uniform.html), as chosen by
[`RNGkind()`](https://rdrr.io/r/base/Random.html), with its own bits
wherever they can be recovered: the 32-bit integers of Mersenne-Twister,
Marsaglia-Multicarry, Super-Duper and L'Ecuyer-CMRG, and the 30-bit
integers of the Knuth generators, packed into a continuous bit stream.
Wichmann-Hill, which adds three fractions, and user-supplied generators
are tested on the 32 most significant bits of each number.

## Usage

``` r
pract_rng(kind = "Mersenne-Twister", seed = 1)
```

## Arguments

- kind:

  The generator, as named by
  [`RNGkind()`](https://rdrr.io/r/base/Random.html).

- seed:

  The seed passed to [`set.seed()`](https://rdrr.io/r/base/Random.html).

## Value

An object of class `zurngtest_source`.

## Details

The source draws from its own copy of the generator's state, set with
`RNGkind(kind)` and `set.seed(seed)`: the session's `.Random.seed` and
kind are restored after every draw, so testing does not change the
random numbers the session draws, and several `pract_rng()` sources, for
example two seeds in
[`pract_interleave()`](https://pedrobtz.github.io/zurngtest/reference/pract_interleave.md),
each keep their own stream.

## See also

[`pract_raw()`](https://pedrobtz.github.io/zurngtest/reference/pract_raw.md)
and
[`pract_fun()`](https://pedrobtz.github.io/zurngtest/reference/pract_raw.md)
for other sources.

## Examples

``` r
pract_test(pract_rng("Mersenne-Twister"), min_bytes = 2^16, max_bytes = 2^17)
#> PractRand 0.96 test of R's Mersenne-Twister generator (seed 1), its 32-bit integers
#> length= 64 kilobytes (2^16 bytes)
#>   no anomalies in 47 test result(s)
#> length= 128 kilobytes (2^17 bytes)
#>   no anomalies in 56 test result(s)
#> No failure, time= 0.3 seconds
```
