# Sources of bits for `pract_test()`

A source tells
[`pract_test()`](https://pedrobtz.github.io/zurngtest/reference/pract_test.md)
where the bits to test come from. `pract_raw()` reads raw bytes, from a
raw vector or a binary connection, in order. `pract_fun()` calls an R
function for more bits each time the test needs them.
[`pract_rng()`](https://pedrobtz.github.io/zurngtest/reference/pract_rng.md)
draws from one of R's own generators, and
[`pract_interleave()`](https://pedrobtz.github.io/zurngtest/reference/pract_interleave.md)
combines sources word by word.

## Usage

``` r
pract_raw(x)

pract_fun(f, bits = 32)
```

## Arguments

- x:

  A raw vector, or a connection to read bytes from.

- f:

  A function of one argument, `n`, returning `n` words of `bits` bits:
  an integer vector of length `n` when `bits` is 32, or a raw vector of
  `n * bits / 8` bytes for any `bits`. Integers are taken as their
  32-bit patterns, so `NA` is the word `0x80000000`.

- bits:

  The size in bits of the words `f` returns: 8, 16, 32 or 64.
  'PractRand' folds its tests to the word size; `pract_raw()` sources
  have no word size, as with 'PractRand”s `RNG_test stdin`.

## Value

An object of class `zurngtest_source`.

## Details

A raw vector or connection that ends before the test does ends the run
early; see
[`pract_test()`](https://pedrobtz.github.io/zurngtest/reference/pract_test.md).
A raw vector source can be used for several runs, each reading from the
start. A connection that is not open is opened in binary mode for the
run and closed after it, which destroys it, as
[`readLines()`](https://rdrr.io/r/base/readLines.html) does, so it
serves one run; an open connection is read from where it is and left
open.

## See also

Other sources:
[`pract_interleave()`](https://pedrobtz.github.io/zurngtest/reference/pract_interleave.md),
[`pract_rng()`](https://pedrobtz.github.io/zurngtest/reference/pract_rng.md)

## Examples

``` r
pract_raw(as.raw(sample(0:255, 1024, replace = TRUE)))
#> <zurngtest_source> raw vector of 1024 bytes

# R's own generator, as bytes
pract_fun(function(n) as.raw(sample.int(256L, n, TRUE) - 1L), bits = 8)
#> <zurngtest_source> function function(n) as.raw(sample.int(256L, n, TRUE) - 1L), 8-bit words
```
