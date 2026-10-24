# zurngtest: roadmap

Status: draft 2026-10-23. Implements [design.md](design.md).
Target: v0.1.0, the first CRAN release.
Tracking: [v0.1.0 (#1)](https://github.com/pedrobtz/zurngtest/issues/1), with one
sub-issue per stage;
[CRAN-submission (#10)](https://github.com/pedrobtz/zurngtest/issues/10).

The design's own roadmap (§15) has five stages. Here its Stage 0 is split in
two, so that vendoring PractRand, the riskiest unknown, is a stage of its own,
and its last stage is split into documentation, `Full CI` and readiness.

## Stages

| Stage | Title | CI | Issue | Pull request | Done |
| --- | --- | --- | --- | --- | --- |
| 0 | [Package identity](#stage-0--package-identity) | quick | [#2](https://github.com/pedrobtz/zurngtest/issues/2) | [#12](https://github.com/pedrobtz/zurngtest/pull/12) | 2026-10-23 |
| 1 | [Vendor PractRand](#stage-1--vendor-practrand) | full | [#3](https://github.com/pedrobtz/zurngtest/issues/3) | [#14](https://github.com/pedrobtz/zurngtest/pull/14) | 2026-10-24 |
| 2 | [Driver and core battery](#stage-2--driver-and-core-battery) | full | [#4](https://github.com/pedrobtz/zurngtest/issues/4) | [#39](https://github.com/pedrobtz/zurngtest/pull/39) | 2026-10-24 |
| 3 | [R generators, interleaving and the C callable](#stage-3--r-generators-interleaving-and-the-c-callable) | quick | [#5](https://github.com/pedrobtz/zurngtest/issues/5) | [#40](https://github.com/pedrobtz/zurngtest/pull/40) | 2026-10-24 |
| 4 | [Known results and RNG_test equivalence](#stage-4--known-results-and-rng_test-equivalence) | quick | [#6](https://github.com/pedrobtz/zurngtest/issues/6) | [#41](https://github.com/pedrobtz/zurngtest/pull/41) | 2026-10-24 |
| 5 | [Documentation and zurand](#stage-5--documentation-and-zurand) | quick | [#7](https://github.com/pedrobtz/zurngtest/issues/7) | [#42](https://github.com/pedrobtz/zurngtest/pull/42) | 2026-10-24 |
| 6 | [Full CI](#stage-6--full-ci) | full | [#8](https://github.com/pedrobtz/zurngtest/issues/8) | [#43](https://github.com/pedrobtz/zurngtest/pull/43) | 2026-10-24 |
| 7 | [v0.1.0 readiness](#stage-7--v010-readiness) | full | [#9](https://github.com/pedrobtz/zurngtest/issues/9) | | |

## Stage 0 — Package identity

**Issue.** [#2](https://github.com/pedrobtz/zurngtest/issues/2), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zurngtest/issues/1).

**CI.** `quick`.

**Goal.** The package has its real name, metadata and CI, and a pull request
gets a quick-profile result in under five minutes.

**Work.**

- Settle the name (open question 1): `zurngtest`, free on CRAN as of
  2026-10-23. The GitHub repository was renamed from `zupract` the same day.
- `DESCRIPTION`: real Title and Description, `Authors@R` with `cre`, `aut`
  and `cph`, `Depends: R (>= 4.1)`, `Language: en-GB`,
  `Version: 0.0.0.9000`.
- `.Rbuildignore` with every entry the "Working with skills" section of
  `CLAUDE.md` lists.
- `R-CMD-check.yaml` keeps calling `r-cmd-check.yml@v1` and adds the Windows
  R-devel runner row.
- `coverage.yaml` pinned to a commit of `coverage.yml`, with the tag in a
  comment, as `CLAUDE.md` requires for a workflow holding a write token.
- `CLAUDE.md` present (written by `pkg-init`, 2026-10-23).
- `zurngtest_info()` stub and the `zurngtest_error` condition hierarchy
  (`zurngtest_invalid_argument`, `zurngtest_source_error`,
  `zurngtest_internal_error`) with tests asserting on class.

**Exit criteria.**

- `R CMD check` passes on the quick r-actions profile, with no notes other
  than "New submission".
- Every check on the stage's pull request finishes in under five minutes;
  any tuning of `quick-step` or `quick-containers` is recorded here.
- `.Rbuildignore` lists `^\.agents$`, `^\.superpowers$`, `^\.worktrees$`,
  `^\.claude$`, `^CLAUDE\.md$`, `^AGENTS\.md$`, `^CRAN-SUBMISSION$` and
  `^cran-comments\.md$`.

**Design.** §3, §8.

## Stage 1 — Vendor PractRand

**Issue.** [#3](https://github.com/pedrobtz/zurngtest/issues/3), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zurngtest/issues/1).

**CI.** `full — vendored C++ library and the package's first compiled code:
sanitizers, valgrind, rchk and the platform legs`.

**Goal.** PractRand's library compiles inside the package on every CI leg,
with no compiled-code NOTE, and `zurngtest_info()` reports its version.

**Work.**

- Confirm PractRand's licence; record it in `inst/COPYRIGHTS` and
  `DESCRIPTION`.
- Compare the sourceforge 0.94 release with the most active fork (open
  question 2); vendor one under `src/practrand/`, pinned in
  `src/practrand/VERSION` with tag, commit and checksums.
- Replace the scaffold's C stub with C++ glue; measure the C++ standard
  PractRand needs and set it in `src/Makevars`.
- Patches in `tools/patches/` removing stdout/stderr writes and `exit()`
  from library code, listed in `src/vendor/PROVENANCE` (or the equivalent
  under `src/practrand/`), and a verify script checking upstream plus
  exactly those patches.
- Hidden symbol visibility; only `R_init_zurngtest` exported. A CI step runs
  `nm` on the built library and fails on any other export or on a banned
  symbol (`printf`, `puts`, `abort`, `exit`, `stdout`, `stderr`, `rand`).
- `zurngtest_info()` returns the PractRand version and the batteries.
- Record compile time and warnings under CRAN's gcc and clang flags in this
  section.

**Measured** (2026-10-24). PractRand 0.96 compiles as C++11, 14 and 17, so
`CXX_STD` is left at R's default. Under CRAN's `-Wall -pedantic` it gave
about 150 warnings that R CMD check counts as significant with each of
GCC 15 and Apple clang 17, plus diagnostic-suppressing pragmas; patch
`0002-cran-warnings.patch` takes both to none. Installing the package
compiles 22 translation units in about 27 s on a macOS machine.

**Deviations** (2026-10-24).

- The pin and the patch list live in `src/practrand/PROVENANCE`, read by
  `tools/vendor/derive`, rather than in a separate `VERSION` file.
- Upstream's `RNGs/other/` generators are not vendored: some of that code
  has no stated licence, and the library neither includes nor links it.
- There is no `vendor-upstream.yml`: it watches GitHub releases, and
  PractRand is released on SourceForge. `vendor.yml` runs the verifier.
- Two more patches were needed: 0002 for compiler warnings (above), and
  0003 for arm64 macOS and the C++20 deprecations R-devel counts as
  significant, which the first CI run found.
- The export criterion excludes libstdc++'s `std::` template
  instantiations. libstdc++ gives namespace `std` default visibility, so
  instantiations the library uses (`std::vector<double>`, `std::string`)
  stay exported on Linux under `-fvisibility=hidden`. They are not the
  package's symbols; `test-symbols.R` requires every other export to be
  `R_init_zurngtest`. Hiding them too would need a linker version script,
  which `Makevars` cannot pass portably.
  The test was seen to fail on Linux on 2026-10-24 (rocker/r-ver 4.5.1, the
  library built without `$(CXX_VISIBILITY)`): it lists PractRand's own
  symbols, so the libstdc++ filter does not hide them.
- Windows has no `-fvisibility`, and R's Windows link exports every global
  symbol unless `src/zurngtest-win.def` lists the exports; that file exports
  `R_init_zurngtest` only, and the export test reads the DLL's export table
  with `objdump -p`.

**Exit criteria.**

- A full-profile r-actions run is green on the pull request.
- `nm` on the built library shows `R_init_zurngtest` as the only exported
  symbol, and none of the banned symbols, in CI.
- The vendor-verify script passes in CI.
- `zurngtest_info()` reports the vendored version.

**Design.** §7, §11.

## Stage 2 — Driver and core battery

**Issue.** [#4](https://github.com/pedrobtz/zurngtest/issues/4), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zurngtest/issues/1).

**CI.** `full — first external pointers and finalizers holding native state,
and R called back from C++: gctorture at step 20, valgrind, ASan`.

**Goal.** `pract_test()` runs PractRand's core and expanded batteries at
doubling lengths over raw bytes and R-function sources, and returns a
`zurngtest_result`.

**Work.**

- zurngtest's own driver, a port of `TestManager.h` and `RNG_test.cpp`'s
  reporting: 1 KiB blocks, at most half a gigabyte per call, the repeated
  tail of blocks between calls.
- Block buffers owned by a finalised external pointer; test objects created
  and destroyed around each run.
- `pract_raw()` (raw vector or connection) and `pract_fun()` (32-bit words,
  integer or raw), filled on the main thread only.
- `pract_test()` with `battery`, `min_bytes`, `max_bytes`,
  `stop_on_failure`, `folding` and `seed`.
- One internal list of battery names, used by both `pract_test()`'s
  `match.arg()` and `zurngtest_info()`.
- `zurngtest_result`: the data frame, `failed_at`, `source`, `elapsed`, and a
  `print()` method reproducing `RNG_test`'s compact report.
- PractRand's labels and thresholds reported unchanged.
- Interrupts checked between battery calls; an interrupt returns results up
  to the last completed length.
- `zurngtest_source_error` for a wrong type or length from `pract_fun()` and
  a connection that ends early.
- Every `.Call` entry point catches the `std::runtime_error` PractRand's
  `issue_error()` throws (patch 0001) and signals
  `zurngtest_internal_error`; a test reaches that path through `.Call`.

**Exit criteria.**

- A full-profile r-actions run is green on the pull request.
- Tests cover both batteries on short raw inputs, `pract_fun()` type and
  length errors by class, an early-ending connection, and `stop_on_failure`.
- A known-weak source (a constant or a short LCG) reports `failed_at` within
  the first lengths.

**Deviations and decisions** (2026-10-24).

- R drives the loop and the C++ driver holds the tests behind a finalised
  external pointer: R reads each chunk (up to 16 MiB) from the source and
  feeds it, so no R code runs inside a C++ frame and an interrupt is an
  ordinary R condition.
- Lengths are powers of two from `min_bytes` to `max_bytes`, both at least
  1024 bytes, one PractRand block.
- `pract_raw()` has no word size, like `RNG_test stdin`, so it gets the
  generic folding; `pract_fun(f, bits)` folds by `bits`.
- `seed = NULL` seeds PractRand's known-good generator with 0, so runs are
  reproducible.
- A source that ends after `min_bytes` ends the run with a last row set at
  the bytes tested (whole blocks); before `min_bytes` it is a source error.
  A connection the run had to open is closed, and so destroyed, after it,
  as `readLines()` does.
- Design D9 and D10: results without a valid p-value are NA and left out
  of the verdict, and an error PractRand raises mid-run ends the run with a
  warning. Both work around PractRand 0.96's NS3 tests in the expanded
  battery.
- Integer words from `pract_fun()` are bit patterns, `NA` included: a
  32-bit generator produces `0x80000000`.

**Design.** §4, §5, §6, §8, §9.

## Stage 3 — R generators, interleaving and the C callable

**Issue.** [#5](https://github.com/pedrobtz/zurngtest/issues/5), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zurngtest/issues/1).

**CI.** `quick`.

**Goal.** Every source the design lists exists: R's own generators,
interleaved sources, and the registered C callable for generator packages.

**Work.**

- `pract_rng()`: exact 32-bit integers where `unif_rand()` is a scaled
  32-bit word (Mersenne-Twister); the 32 most significant bits of each double
  otherwise, stated in `source`. Each `RNGkind()` kind checked and its case
  recorded here.
- The user's `.Random.seed` saved and restored around a run.
- `pract_interleave(...)`, word by word.
- `zurngtest_test_cfun` and the `zurngtest_fill_fn` type, registered with
  `R_RegisterCCallable()`, in a header under `inst/include/` that compiles
  standalone.
- A test that calls the callable from C, through `R_GetCCallable()`, with a
  small fill function.

**Exit criteria.**

- `R CMD check` passes on the quick r-actions profile.
- Tests show exact integer recovery for Mersenne-Twister, `.Random.seed`
  unchanged after a run, byte-exact interleaving, and the C callable
  returning the same result as `pract_test()` on the same words.
- `R_init_zurngtest` is still the only exported symbol.

**Recorded** (2026-10-24): how each `RNGkind()` reaches `runif()`, from R's
`src/main/RNG.c`, checked on 1e5 draws of each kind.

| Kind | `unif_rand()` | Tested as |
| --- | --- | --- |
| Mersenne-Twister | y / 2^32 | exact 32-bit integers |
| Marsaglia-Multicarry, Super-Duper | x / (2^32 - 1) | exact 32-bit integers |
| L'Ecuyer-CMRG | x / (m1 + 1), x in 1..m1 | exact integers |
| Knuth-TAOCP, Knuth-TAOCP-2002 | x / 2^30 | exact 30-bit integers, bit-packed |
| Wichmann-Hill | sum of three fractions | 32 most significant bits |
| user-supplied | unknown | 32 most significant bits |

**Deviations** (2026-10-24).

- The design expected L'Ecuyer-CMRG to need its 32 most significant bits;
  its integers are exactly recoverable, so they are tested instead.
- Knuth-TAOCP's 30-bit integers are packed into a continuous bit stream
  rather than taken as the top 32 bits of the double, whose two constant
  low bits would fail on their own.
- Each `pract_rng()` reader keeps its own `.Random.seed` and swaps it in
  only while it draws, rather than holding the session's generator for the
  whole run. The session's stream is untouched between draws, and two
  `pract_rng()` sources can be interleaved.
- `pract_interleave()` needs sources of one word size (bytes for
  `pract_raw()` and Knuth sources).
- The C callable runs `pract_test()` with a source whose chunks the C fill
  function writes directly into a raw vector (`zrt_cfun_fill`), so R
  orchestrates one call per 16 MiB chunk rather than none.
- `Imports: stats` for `runif()`; `stats` ships with R, so there is still no
  hard dependency beyond R.

**Design.** §5.1, §5.2, §4 (D3, D4).

## Stage 4 — Known results and RNG_test equivalence

**Issue.** [#6](https://github.com/pedrobtz/zurngtest/issues/6), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zurngtest/issues/1).

**CI.** `quick`.

**Goal.** zurngtest's results are shown to equal PractRand's own tool, and
generators with published results fail, or pass, where they should.

**Work.**

- A CI workflow that builds `RNG_test` from the vendored sources, runs it on
  fixed byte files, and compares its output with `pract_test()`'s.
- Known-result regressions: a weak LCG, `xorshift32`, Mersenne-Twister's
  binary-rank failure, and a good generator passing to `max_bytes`, each
  with its recorded length. Long lengths run in CI only (`skip_on_cran()`).
- The CRAN-run suite kept under 15 s.
- The throughput targets measured and recorded here: the C callable at 90%
  or more of `RNG_test`, `pract_rng()` at 50% or more.

**Exit criteria.**

- `R CMD check` passes on the quick r-actions profile.
- The equivalence workflow is green.
- Every known-result generator fails, or passes, at its recorded length in
  CI.
- The CRAN suite runs in under 15 s on the quick profile's Ubuntu leg.

**Measured** (2026-10-24, macOS x86_64, single thread, an installed -O2
build; `devtools::load_all()` builds at -O0 and is about three times slower).

- **Equivalence.** `tools/equivalence/compare.R` runs `RNG_test -a`, built
  unpatched from the pinned archive, and `pract_test()` on the same bytes: a
  repeating pattern, R's Mersenne-Twister as bytes, and 32-bit counter words,
  at 64 KiB to 1 MiB. Every test name, evaluation and p-value (to the digits
  `RNG_test` prints, which it sometimes truncates) agrees at every length,
  so the six patches change none of these results.
- **Known results**, each length the one `RNG_test` reports for the same
  stream: a full-output 32-bit LCG (Numerical Recipes) fails at 4 KiB;
  xorshift32 (13, 17, 5) fails at 16 KiB. hc256 passes to 256 MiB,
  `std::mt19937` to 1 GiB and R's Mersenne-Twister (through `pract_rng()`)
  to 64 MiB; those three are long runs, made in the equivalence workflow
  (`ZURNGTEST_LONG_TESTS=true`).
- **Throughput**, 256 MiB with the core battery and standard folding:
  `RNG_test` hc256 4.44 s, mt19937 4.43 s; through the C callable, hc256
  4.49 s (99%) and mt19937 4.85 s (91%), against the 90% target;
  `pract_rng()` Mersenne-Twister 7.86 s (56%), against the 50% target.
- The CRAN-run suite takes about 5 s.

**Deviations** (2026-10-24).

- Mersenne-Twister's known failure, PractRand's binary-rank tests at
  256 GiB, is not run: it takes hours. The long runs check that it, and
  hc256, pass at the lengths they should.
- The C-callable generators for these tests (`src/test-generators.cpp`)
  are compiled into the package and reached through `.Call()`, as the
  callable's own test is.
- To agree with `RNG_test`, p-values below 0.01 and above 0.99 are now
  computed from each result's suspicion, as `RNG_test` prints them; the
  stored p-value loses precision near 1.

**Design.** §10, §12; acceptance criteria 2 and 3.

## Stage 5 — Documentation and zurand

**Issue.** [#7](https://github.com/pedrobtz/zurngtest/issues/7), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zurngtest/issues/1).

**CI.** `quick`.

**Goal.** A user can learn the package from its site, and `zurand` uses the
C callable in a test.

**Work.**

- roxygen documentation for every export, with examples at short lengths.
- PractRand's evaluation labels documented.
- `README.Rmd` (the `pkg-readme` skill) and a pkgdown reference index.
- A vignette testing a `zurand` stream through the C callable, with `zurand`
  in `Suggests` and the vignette guarded on it.
- A `zurand` pull request that uses `zurngtest_test_cfun` in a test.

**Exit criteria.**

- `R CMD check` passes on the quick r-actions profile; the pkgdown site
  builds.
- The vignette builds with and without `zurand` installed.
- The `zurand` pull request is merged, or recorded here as blocked with a
  reason.

**Deviations and status** (2026-10-24).

- The vignette tests zurand from R, through `pract_fun()` and
  `rng_bits()`, and shows the C callable as code that is not run: a zurand
  stream can reach the callable only from zurand's own C code, which is
  what the zurand pull request adds.
- The zurand pull request,
  [pedrobtz/zurand#65](https://github.com/pedrobtz/zurand/pull/65), is open
  for review. It adds a fixture package built against `zurand.h` and
  `zurngtest.h` and a test that runs one stream per engine through
  `zurngtest_test_cfun()`; all three pass to 16 MiB. It does not add
  zurngtest to zurand's `DESCRIPTION`, since zurand goes to CRAN first, so
  the test skips where zurngtest is not installed, including zurand's CI.
- zurand is in `Suggests` with `Remotes: pedrobtz/zurand`, since it is not
  on CRAN yet. **Before Stage 7 submits, zurand must be on CRAN, or leave
  `Suggests`;** CRAN does not accept a suggested package it cannot install.
- `print()` printed every result line after the first with an extra
  leading space; fixed, with a test.

**Design.** §3 (relationships); acceptance criterion 4.

## Stage 6 — Full CI

**Issue.** [#8](https://github.com/pedrobtz/zurngtest/issues/8), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zurngtest/issues/1).

**CI.** `full`. Always, by policy.

**Goal.** No new features. The full r-actions profile is green on the
default branch's code.

**Work.**

- Run the full profile (`full-ci` label) and fix everything it finds:
  gctorture at the sensitive step, valgrind, ASan, every platform leg,
  `nosuggests`, `nold`, cran-special.
- Close each failure recorded as a comment on this stage's issue.

**Exit criteria.**

- A full-profile run is green on the pull request and on the merge commit.

**Done** (2026-10-24). The full run on Stage 5's merge (`d8c45f5`) was green on
every job it ran, and the `Full CI` issue had no comments. But
`nosuggests` and `nold` are opt-in inputs of `r-cmd-check.yml` and had
never run. This stage turns both on. It also runs the test suite only where
testthat is installed: without its suggested packages the check failed on
`library(testthat)`. The full profile is green on the pull request
(`9ad16f8`): R CMD check on every runner and container plus `nosuggests`
and `nold`; native checks (ASan, UBSan, valgrind, gctorture, rchk, LTO,
`-fanalyzer`, cran-special); equivalence, vendor, coverage and pkgdown.

**Design.** §11; acceptance criterion 1.

## Stage 7 — v0.1.0 readiness

**Issue.** [#9](https://github.com/pedrobtz/zurngtest/issues/9), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zurngtest/issues/1).

**CI.** `full`. Always, by policy.

**Goal.** Only the submission itself is left.

**Work.**

- `Version: 0.1.0` and the matching `NEWS.md` heading.
- `cran-comments.md` listing the r-actions CI legs as test environments.
- The `pkg-critical-review` skill run; blocking and required findings fixed.
- The `pkg-cran-review` skill run; every finding resolved.
- `urlchecker::url_check()` and `spelling::spell_check_package()` clean.

**Exit criteria.**

- A full-profile r-actions run is green on the release commit.
- Both review skills' findings are closed.
- `urlchecker` and `spelling` report nothing.

**Design.** Acceptance criteria 1–4.

## After 0.1.0

- PractRand's own generators (`sfc64`, `jsf64`, `efiix`) as R generators via
  `RNGkind("user-supplied")`: "later, when asked" in §2.
- Multithreaded batteries (`MultithreadedTestManager`), once the
  single-threaded path is measured in Stage 4.
- A TestU01 binding: a sibling package if ever (open question 3).

## Open questions

1. **The name.** Resolved 2026-10-23: `zurngtest` (design D7). The R prefix
   stays `pract_`.
2. **Which upstream.** Resolved 2026-10-24: PractRand 0.96 from SourceForge,
   released 2025-12-26 and newer than every fork (design D8).
3. **TestU01** in this package or a sibling. Blocks nothing before 0.1.0.
