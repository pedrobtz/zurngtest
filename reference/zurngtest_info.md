# Information about zurngtest

Reports the package version, the vendored 'PractRand' version and the
test batteries zurngtest supports.

## Usage

``` r
zurngtest_info()
```

## Value

A list with elements `version` (the package version, a string),
`practrand` (the version of the vendored 'PractRand' library, a string)
and `batteries` (a character vector of battery names).

## Examples

``` r
zurngtest_info()
#> $version
#> [1] "0.1.0"
#> 
#> $practrand
#> [1] "0.96"
#> 
#> $batteries
#> [1] "core"     "expanded"
#> 
```
