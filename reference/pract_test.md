# Test a source of random bits with 'PractRand'

Runs a 'PractRand' battery on the bits from `source`, reporting results
at doubling lengths from `min_bytes` to `max_bytes`, as 'PractRand”s
`RNG_test` does.

## Usage

``` r
pract_test(
  source,
  battery = c("core", "expanded"),
  min_bytes = 2^20,
  max_bytes = 2^34,
  stop_on_failure = TRUE,
  folding = TRUE,
  seed = NULL
)
```

## Arguments

- source:

  A source of bits, from
  [`pract_raw()`](https://pedrobtz.github.io/zurngtest/reference/pract_raw.md)
  or
  [`pract_fun()`](https://pedrobtz.github.io/zurngtest/reference/pract_raw.md).

- battery:

  The 'PractRand' battery: `"core"`, the recommended set of tests, or
  `"expanded"`, a wider and slower set.

- min_bytes, max_bytes:

  The shortest and longest lengths tested, in bytes: powers of two of at
  least 1024.

- stop_on_failure:

  If `TRUE`, stop at the first length where the source fails.

- folding:

  If `TRUE`, also run the tests on 'PractRand”s standard foldings of the
  data (for example its low bits), by the source's word size.

- seed:

  The seed of the generator 'PractRand' uses inside some tests, a whole
  number from 0 to 2^53. `NULL` uses 0, so runs are reproducible.

## Value

A data frame of class `zurngtest_result`, with one row per test result
at each length: `bytes` (the length), `test` (the test name), `p_value`
and `evaluation` ('PractRand”s label). Its attributes are `failed_at`,
the first length with a failure or `NA`, `source`, a description of the
source, and `elapsed`, the run time in seconds.

## Details

Each test result is evaluated with 'PractRand”s own labels and
thresholds, as its `RNG_test` evaluates them; see the Evaluations
section. A source has failed at the first length with any result
labelled "FAIL".

## Evaluations

'PractRand' scores each result in decimal digits: about
\\\log\_{10}(1/p)\\ for its p-value \\p\\, less \\\log\_{10}(1/w)\\ for
its share \\w\\ of the weight of all the results, so the more results a
run has, the more improbable one must be to stand out. With 100 equally
weighted results, a p-value of \\10^{-5}\\ scores about 3. The labels,
by score, are:

|                                         |                         |
|-----------------------------------------|-------------------------|
| Score                                   | Evaluation              |
| 0                                       | normal                  |
| above 0                                 | normalish               |
| above 1                                 | unusual                 |
| above 2                                 | mildly suspicious       |
| above 3                                 | suspicious              |
| above 4                                 | very suspicious         |
| above 6                                 | VERY SUSPICIOUS         |
| above 8.5                               | FAIL                    |
| above 12, 17, 25, 45, 85, 165, 325, 999 | FAIL ! to FAIL !!!!!!!! |

"unusual" results are expected now and then in a long run of a good
generator; a "FAIL" is not.

A result with no valid p-value has `NA` for `p_value` and `evaluation`,
and is left out of the evaluation of the others. 'PractRand' 0.96's
expanded battery gives such results from its NS3 tests even on good
input; `RNG_test` stops on them.

A source that ends early (a raw vector or connection with fewer bytes
than `max_bytes`) ends the run: the last rows are at the number of bytes
tested, rounded down to a whole kilobyte. If it ends before `min_bytes`,
that is an error. An interrupt also ends the run, and returns the
results of the lengths completed before it, as does an error raised by
'PractRand' itself, which the NS3 tests of the expanded battery can
raise on heavily failing input; that is reported in a warning of class
`zurngtest_stopped`.

## Examples

``` r
# A repeating pattern fails at once
pattern <- pract_raw(rep(as.raw(0:255), 2^8))
pract_test(pattern, min_bytes = 2^16, max_bytes = 2^16)
#> PractRand 0.96 test of raw vector of 65536 bytes
#> length= 64 kilobytes (2^16 bytes)
#>   Test Name                         p-value       Evaluation
#>   BCFN(2+0,13-9U)                    0.00e+00     FAIL !!!!!!!
#>   BCFN(2+1,13-9U)                    0.00e+00     FAIL !!!!!!!
#>   BCFN(2+2,13-9U)                   1.87e-244     FAIL !!!!!!
#>   DC6-9x1Bytes-1                     0.00e+00     FAIL !!!!!!!!
#>   Gap-16:A                           0.00e+00     FAIL !!!!!!!!
#>   Gap-16:B                           0.00e+00     FAIL !!!!!!!!
#>   Gap-16:C                           1.00e+00     FAIL !!!!!!
#>   FPF/16:(1,14-8)                    1.00e+00     very suspicious
#>   FPF/16:(2,14-8)                    0.00e+00     FAIL !!!!!!!!
#>   FPF/16:(3,14-9)                    0.00e+00     FAIL !!!!!!!
#>   FPF/16:(4,14-10)                   0.00e+00     FAIL !!!!!!!
#>   FPF/16:(5,14-11)                  1.53e-233     FAIL !!!!!!
#>   FPF/16:(6,14-11)                  1.53e-233     FAIL !!!!!!
#>   FPF/16:all                         0.00e+00     FAIL !!!!!!!!
#>   FPF/16:cross                       0.00e+00     FAIL !!!!!!!!
#>   BDayS2(4,24)[18]                  6.01e-200     FAIL !!!!!!
#>   BRank(12):score:64(7)              1.00e+00     FAIL !!!!!!!!
#>   mod3n(5):(0,9-6)                   0.00e+00     FAIL !!!!!!!
#>   mod3n(5):(1,9-6)                   0.00e+00     FAIL !!!!!!!
#>   mod3n(5):(2,9-6)                  7.09e-218     FAIL !!!!!!
#>   mod3n(5):(3,9-6)                  4.43e-102     FAIL !!!!!
#>   [Low1/8]BCFN(2+0,13-9U)            0.00e+00     FAIL !!!!!!!
#>   [Low1/8]DC6-9x1Bytes-1             0.00e+00     FAIL !!!!!!!!
#>   [Low1/8]Gap-16:A                   0.00e+00     FAIL !!!!!!!!
#>   [Low1/8]Gap-16:B                   0.00e+00     FAIL !!!!!!!!
#>   [Low1/8]Gap-16:C                   1.00e+00     FAIL !!!!!
#>   [Low1/8]FPF/16:(1,14-10)           0.00e+00     FAIL !!!!!!!!
#>   [Low1/8]FPF/16:all                 0.00e+00     FAIL !!!!!!!!
#>   [Low1/8]FPF/16:cross               0.00e+00     FAIL !!!!!!!!
#>   [Low1/8]mod3n(5):(0,9-6)           0.00e+00     FAIL !!!!!!!
#>   [Low1/8]mod3n(5):(1,9-6)          8.40e-217     FAIL !!!!!!
#>   [Low1/8]mod3n(5):(2,9-6)          3.13e-106     FAIL !!!!!
#>   [Low4/32]BCFN(2+0,13-9U)           0.00e+00     FAIL !!!!!!!
#>   [Low4/32]DC6-9x1Bytes-1            0.00e+00     FAIL !!!!!!!!
#>   [Low4/32]Gap-16:A                  0.00e+00     FAIL !!!!!!!!
#>   [Low4/32]Gap-16:B                  0.00e+00     FAIL !!!!!!!!
#>   [Low4/32]Gap-16:C                  1.00e+00     FAIL !!!!!
#>   [Low4/32]FPF/16:cross              0.00e+00     FAIL !!!!!!!!
#>   [Low4/32]mod3n(5):(0,9-6)          0.00e+00     FAIL !!!!!!!
#>   [Low4/32]mod3n(5):(1,9-6)         8.57e-217     FAIL !!!!!!
#>   [Low4/32]mod3n(5):(2,9-6)         3.13e-106     FAIL !!!!!
#>   [Low1/32]DC6-9x1Bytes-1            0.00e+00     FAIL !!!!!!!
#>   [Low1/32]FPF/16:cross              0.00e+00     FAIL !!!!!!!!
#>   [Low1/32]mod3n(5):(0,9-6)          0.00e+00     FAIL !!!!!!!
#>   [Low1/32]mod3n(5):(1,9-6)         8.57e-217     FAIL !!!!!!
#>   [Low1/32]mod3n(5):(2,9-6)         3.13e-106     FAIL !!!!!
#> Failed at 64 kilobytes (2^16 bytes), time= 0.2 seconds

# R's own generator, as bytes
bytes <- pract_fun(function(n) as.raw(sample.int(256L, n, TRUE) - 1L), bits = 8)
pract_test(bytes, min_bytes = 2^16, max_bytes = 2^17)
#> PractRand 0.96 test of function function(n) as.raw(sample.int(256L, n, TRUE) - 1L), 8-bit words
#> length= 64 kilobytes (2^16 bytes)
#>   no anomalies in 36 test result(s)
#> length= 128 kilobytes (2^17 bytes)
#>   no anomalies in 42 test result(s)
#> No failure, time= 0.2 seconds
```
