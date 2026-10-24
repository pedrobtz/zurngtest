# Interleave sources word by word

`pract_interleave()` combines sources into one stream that takes one
word from each in turn, for seeding studies: two seeds of one generator,
substreams, or several generators whose combination, rather than any one
of them, may be what fails.

## Usage

``` r
pract_interleave(...)
```

## Arguments

- ...:

  Two or more sources, from
  [`pract_raw()`](https://pedrobtz.github.io/zurngtest/reference/pract_raw.md),
  [`pract_fun()`](https://pedrobtz.github.io/zurngtest/reference/pract_raw.md),
  [`pract_rng()`](https://pedrobtz.github.io/zurngtest/reference/pract_rng.md)
  or `pract_interleave()`.

## Value

An object of class `zurngtest_source`.

## Details

All sources must have the same word size: the words are those of
[`pract_fun()`](https://pedrobtz.github.io/zurngtest/reference/pract_raw.md)
and
[`pract_rng()`](https://pedrobtz.github.io/zurngtest/reference/pract_rng.md)
sources, or single bytes for
[`pract_raw()`](https://pedrobtz.github.io/zurngtest/reference/pract_raw.md)
sources and Knuth generators. The stream ends when any source ends.

## Examples

``` r
seeds <- pract_interleave(pract_rng(seed = 1), pract_rng(seed = 2))
pract_test(seeds, min_bytes = 2^16, max_bytes = 2^17)
#> PractRand 0.96 test of interleaving of R's Mersenne-Twister generator (seed 1), its 32-bit integers; R's Mersenne-Twister generator (seed 2), its 32-bit integers
#> length= 64 kilobytes (2^16 bytes)
#>   no anomalies in 47 test result(s)
#> length= 128 kilobytes (2^17 bytes)
#>   no anomalies in 56 test result(s)
#> No failure, time= 0.3 seconds
```
