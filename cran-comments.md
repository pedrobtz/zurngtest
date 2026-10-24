## Submission

This is a new submission. zurngtest runs the PractRand statistical test suite
for random number generators, by Chris Doty-Humphrey, from R. PractRand 0.96
is bundled in `src/practrand/`; it is public domain (CC0 1.0 as a fallback),
and its provenance and the local patches are described in
`src/practrand/PROVENANCE` and `inst/COPYRIGHTS`.

## Test environments

GitHub Actions, through the shared workflows in
https://github.com/pedrobtz/r-actions:

* macOS (latest), R release
* Windows (latest), R release and R-devel
* Ubuntu (latest), R release and R oldrel-1
* R-devel in the R-hub containers that match CRAN's Debian flavors: clang 23
  with CRAN's flags, clang with libstdc++, and gcc 16
* CRAN's NOSUGGESTS and NOLD flavors (R-hub `nosuggests` and `nold`)
* AddressSanitizer and UndefinedBehaviorSanitizer with gcc and clang,
  valgrind, gctorture, rchk, link-time optimisation, gcc's `-fanalyzer`, and
  R-hub's rcnst and rlibro checks

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.

## Method References

PractRand has no published paper; its tests and their documentation are
those of the PractRand distribution, cited in the Description by its
author and URL (https://pracrand.sourceforge.net/).
