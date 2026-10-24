# CLAUDE.md

<!-- markdownlint-disable-next-line MD013 -->
This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

zurngtest runs PractRand, Chris Doty-Humphrey's statistical test suite for
random number generators, from R. It feeds PractRand a generator's own bits
at doubling lengths and reports the length at which the generator first
fails. Its callers are authors of generator packages (`zurand` first, through
a registered C callable), users checking R's own `RNGkind()` generators, and
simulation work that combines streams. PractRand is vendored (C++); there are
no hard runtime dependencies. It never certifies cryptographic quality, and it
adds no verdicts of its own on top of PractRand's.

The specification is [`.agents/design.md`](.agents/design.md), adopted from
[RFC 0016](https://github.com/pedrobtz/packages/blob/main/rfcs/started/0016-zupract-practrand-rng-testing.md).
It outranks this file: `CLAUDE.md` orients, the design doc decides. Its open
questions (the name, which PractRand upstream, TestU01) are still open.

## Current state

Scaffolded 2026-10-23 with `create-pkg.sh`. As of 2026-10-24 every
roadmap stage is done and the version is 0.1.0: `pract_test()` runs
PractRand 0.96's core and expanded batteries over `pract_raw()`,
`pract_fun()`, `pract_rng()` and `pract_interleave()` sources, and C code
reaches it through `zurngtest_test_cfun()`. Its results equal `RNG_test`'s
on the same bytes. The guide is a pkgdown article
(`vignettes/articles/`), not shipped. `zurand` left `Suggests` until it is
on CRAN. Only the CRAN submission is left (issue #10); the open `review`
issues are for after 0.1.0.

## Stage tracking

Progress toward the next version is tracked as GitHub sub-issues, so the
parent issue shows a progress bar such as "6 of 7".

- **One parent issue per target version**, titled with the bare version, for
  example `v0.1.0`. `v0.1.0` issue: created by `pkg-roadmap`.
- **One sub-issue per roadmap stage**, titled as the roadmap titles it, for
  example `Stage 3 — R interface`, and linking to that section. The number of
  stages is whatever the roadmap has; there is no fixed scale.
- **Every tracking issue carries the `stage` label**, so it can be told apart
  from bug and feature issues and left out of open-issue counts.
- **Close a stage by merging its pull request.** Put `Closes #<n>` in the
  body of the stage's pull request. Never close a stage whose exit criteria
  are not met; record a deviation in the roadmap first.
- **The roadmap stays authoritative.** The issues record which stages are
  done, not what a stage requires. Adding, removing or renaming a stage
  means editing the roadmap and the sub-issues in the same change.
- **Each stage has a CI tier, `quick` or `full`.** The roadmap sets it, and
  `quick` is the default. See Continuous integration for what each means.
  The second-to-last stage, `Full CI`, runs the full set and fixes what it
  finds before `v0.1.0 readiness`.
- Close the parent issue when CRAN accepts the version and it is tagged.
  Opening a parent issue implies at least one stage sub-issue; a parent with
  no sub-issues shows no progress on the board.

## Versioning

A new package develops at `0.0.0.9000` and targets `0.1.0` for its first CRAN
release. Set `Version: 0.1.0` and the matching `NEWS.md` heading when the
package enters `Pre-flight`. Bump to `0.1.0.9000` only after CRAN accepts it,
never before: a `.9000` version above an unreleased `0.1.0` heading is wrong.

Until the first release the R API may change freely. Sibling packages can
still depend on this one before CRAN does, through `Remotes:` or `LinkingTo:`.
`zurand` will call the registered C callable `zurngtest_test_cfun` from its
tests. A change to that function's signature, or to the `zurngtest_fill_fn`
type, breaks it even before 0.1.0. A package that others wait on should
reach CRAN first.

## Commands

Run from the package root.

```sh
Rscript -e 'devtools::load_all()'                # compile src/ and load
Rscript -e 'devtools::document()'                # roxygen -> NAMESPACE, man/
Rscript -e 'devtools::test()'                    # full testthat suite
Rscript -e 'devtools::test(filter = "<name>")'   # one test file
Rscript -e 'devtools::test(shuffle = TRUE)'      # order independence
Rscript -e 'devtools::check()'                   # R CMD check
air format .                                     # format R sources
```

Occasional, and in the `equivalence` workflow:

```sh
tools/equivalence/build-rng-test /tmp/pr      # RNG_test, unpatched, from the pin
Rscript tools/equivalence/compare.R /tmp/pr/RNG_test   # needs zurngtest installed
ZURNGTEST_LONG_TESTS=true Rscript -e 'devtools::test(filter = "known-results")'
```

Time throughput with an installed build: `devtools::load_all()` compiles at
`-O0`.

## Architecture

To be completed as stages land; see `.agents/design.md`.

- `src/practrand/` is the vendored PractRand library (see Vendored native
  code). `src/Makevars` lists its 21 objects, adds
  `-Ipractrand/include` and builds everything with hidden visibility.
  Windows has no visibility flag; `src/zurngtest-win.def` limits the DLL's
  exports to `R_init_zurngtest`.
- `src/init.cpp` is the R boundary: `R_init_zurngtest` (the one visible
  symbol) registers the `.Call` entry points, disables dynamic symbol
  lookup and forces symbols, so R code calls them through the objects
  `@useDynLib zurngtest, .registration = TRUE` creates, as in
  `.Call(zrt_practrand_version)`.
- PractRand's `issue_error()` throws `std::runtime_error` (patch 0001).
  Every entry point that calls into PractRand must catch it before
  returning to R. No handler can catch a throw from a destructor or from
  static initialisation, so `issue_error()` must never be reachable there
  (patch 0005; see `src/practrand/PROVENANCE`).
- `src/driver.cpp` is the test driver, a port of PractRand's
  `tools/TestManager.h`: the tests, the known-good hc256 they use, and the
  block buffer with its repeated prefix, behind an external pointer whose
  finalizer deletes them. `R/pract-test.R` drives it: it reads the source
  in chunks, feeds whole 1 KiB blocks and collects results at each length,
  so interrupts and source errors are plain R.
- `src/callable.cpp` is the C API: `zurngtest_test_cfun()`, registered with
  `R_RegisterCCallable()` and declared in `inst/include/zurngtest.h`, runs
  `pract_test()` on a source whose chunks the caller's fill function writes
  natively. `R/rng.R`'s readers keep their own `.Random.seed` and swap it in
  only while they draw.

## Invariants that are easy to break

- **No C++ object with a destructor is alive in a frame that calls an R
  API function that can longjmp.** The `.Call` entries in `src/driver.cpp`
  do their C++ work in `try` blocks on state the external pointer owns, copy
  an exception's message into a `char` buffer, and only then call R. A
  longjmp past a live `std::vector` leaks it and skips its destructor.
- **Test helpers belong in `tests/testthat/helper-*.R`.** A helper defined
  at the top of a test file breaks `devtools::test(shuffle = TRUE)`; this
  happened twice.
The design fixes these before any code exists:

- **Only `R_init_zurngtest` is exported** from the shared library, with hidden
  visibility from Stage 0. `zurngtest_test_cfun` is registered with
  `R_RegisterCCallable()`, not exported. Generator packages reach it only
  through `R_GetCCallable()`.
- **R sources run on the main thread only.** An R function source is called
  between battery calls to fill a buffer, never from a worker. Only the C
  callable source may be filled off the main thread.
- **PractRand's labels and thresholds are reported unchanged.** The number
  users compare across papers is PractRand's; zurngtest adds no evaluation of
  its own.
- **Testing R's generator does not change the user's stream.** The R RNG
  state is saved and restored around a run.
- **Every condition inherits `zurngtest_error`.**

Add each further one when a stage establishes it.

## Testing conventions

- **Self-sufficient.** Every test builds its own inputs inside the
  `test_that()` block. No file-scope objects.
- **Self-contained.** Global state goes through `withr::local_*()`, randomised
  input through `withr::local_seed()`. Tests write only under `tempdir()`.
- **Assert on condition classes, never message text.** Use
  `expect_error(..., class = "<pkg>_<kind>_error")`. Wording belongs in
  snapshot tests.
- **Order independence.** `devtools::test(shuffle = TRUE)` is part of the
  definition of done.
- **Borrow a conformance suite before writing one.** Mainstream
  implementations in Python, Java, Go or Node usually ship a test corpus.
  Use it as an oracle rather than inventing cases by hand. Here the oracle is
  PractRand's own `RNG_test` tool, built from the same sources in CI, plus
  generators with published failure lengths; neither is wired up yet.
- **Helpers live in `tests/testthat/helper-*.R`.** `helper-symbols.R` reads
  the library's exports (nm, or `objdump -p` on Windows) and undefined
  symbols, fails when the tool is missing or fails (outside CRAN), and
  builds the banned list from R's own `tools:::so_symbol_names_table`.
- **Keep the suite inside the CRAN time budget.** The design budgets under
  15 s, with short lengths only; long runs are CI-only.

## Definition of done

`devtools::document()` and `devtools::check()` clean, meaning 0 errors, 0
warnings and 0 notes. The one allowed note is "New submission" before the first
release. `devtools::test(shuffle = TRUE)` green. CI green at the change's
tier: the quick profile for a `quick` roadmap stage or an ordinary pull
request, the full profile for a `full` stage, `Full CI`, and every release.
A user-facing change also needs a test, roxygen documentation and a `NEWS.md`
entry.

## Releasing to CRAN

- **CI is the pre-submission check.** The `pedrobtz/r-actions` R CMD check runs
  `--as-cran` on the CRAN-like runners and containers, and it replaces
  win-builder, the macOS builder and R-hub. None of them is a release step,
  and `cran-comments.md` lists the CI legs as its test environments.
- **Entering `Pre-flight`.** The roadmap's feature stages are done, the
  version is set as in Versioning, `NEWS.md` and `cran-comments.md` are
  written, and CI is green. Only submission work remains.
- **Before submitting,** run `pkg-critical-review` once the roadmap is
  implemented and fix what it files, then `pkg-cran-review`, and resolve
  every finding. Both skills are in `pedrobtz/r-skills`.
- **The pretest is automated and does not read `cran-comments.md`.** A NOTE
  that is explained but not fixed gets the upload archived. Fix the NOTE, as
  under Vendored native code, instead of justifying it.
- **After acceptance,** `pkg-post-cran` tags the submitted commit with the
  bare version, `0.1.0` (no `v`), publishes the GitHub release, bumps to
  `0.1.0.9000`, closes the version's parent issue and moves the board card.

## Editing rules

- roxygen comments are the source. Never edit `man/` or `NAMESPACE` by hand.
- Edit `README.Rmd`, not the generated `README.md`.
- Keep prose simple and short. One idea per sentence.
- Wrap roxygen text at 80 characters and run `air format .` on R sources.
- Use `lower_snake_case`, and prefix internal native symbols with `zrt_`
  (design §3).
- Keep hard runtime dependencies at zero unless a recorded design decision
  says otherwise.
- Export and document public functions. Do not create roxygen topics for
  internal ones.

## Continuous integration

Workflows come from `pedrobtz/r-actions`. Call those reusable workflows instead
of writing bespoke ones, and pin a released tag rather than `main`. Pin a
workflow that holds a write token, such as `coverage.yml`, to a commit, with
the tag in a comment. The `R-CMD-check` workflow must call `r-cmd-check.yml`,
because a hand-rolled one does not count as the pre-submission check. This
package calls `r-cmd-check.yml@v1` (`R-CMD-check.yaml`) and `coverage.yml@v1`
(`coverage.yaml`); the pkgdown site is built by its own `pkgdown.yaml`.

Small edits get a small run. The shared workflows look at the files a pull
request changes, compared with its merge base:

- **Markdown only**, such as `README.md`, `NEWS.md` or `cran-comments.md`,
  skips every check. Only coverage and the pkgdown site run.
- **`DESCRIPTION` or `README.Rmd` as well**, and nothing else, adds one R CMD
  check on Ubuntu R-release.
- **Any other file** runs everything.

So put a README or `DESCRIPTION` touch-up in its own pull request. Once a pull
request changes code, every later push to it runs every workflow.

### Quick by default, full by exception

The full profile is slow. gctorture at step 20 alone has taken 36 to 107
minutes on sibling packages. Waiting on it between roadmap stages was the
main thing slowing roadmaps down, so:

- **Pull requests run the quick profile.** It should finish in under five
  minutes. If it doesn't, raise gctorture's `quick-step` or trim
  `quick-containers` in the caller workflows; never cut the full profile.
- **A `full` roadmap stage takes the `full-ci` label** and merges only on a
  green full run. The roadmap gives the reason in the stage's `**CI.**`
  line, for example first compiled code, a `PROTECT` or finalizer change, a
  vendored library, or a Windows-only path.
- **Don't wait on the full run a merge starts** on the default branch, and
  cancel older full runs it supersedes. A failure that only the full set
  shows goes on the `Full CI` stage issue as a comment with the run link,
  and is fixed there. A failure the quick profile also shows is fixed now.
- **`Full CI` and `v0.1.0 readiness` wait** for a green full run on their
  merge commit, and the release commit always needs one.
- Locally, run `gctorture(TRUE)` on the code a C change touches when it is
  cheap; the full run is the authority.

## Vendored native code

PractRand 0.96 (C++), by Chris Doty-Humphrey, public domain with a CC0
fallback, from the SourceForge release archive (SHA-256 `e4caf7fd…`; no
tag or commit exists upstream). `src/practrand/PROVENANCE` holds the pin,
the patch list and the reasons for both; `inst/COPYRIGHTS` and
`DESCRIPTION` credit the author.

- `tools/vendor/derive` rebuilds the tree from the archive and
  `tools/patches/`; `tools/vendor/update` writes it into `src/practrand/`;
  `tools/vendor/verify` is the gate, and `tools/vendor/check` (the gate,
  then `verify --canary`) is what `vendor.yaml` runs. Patches apply with
  zero fuzz; `derive` exits 3 when one does not apply.
  Never edit `src/practrand/` by hand: change a patch and run `update`.
- `0001-no-stdio.patch` is generated by `tools/vendor/make-no-stdio-patch`;
  `0002-cran-warnings.patch` is hand-made. Both are described in
  PROVENANCE.
- Measure warnings the way R CMD check does: build the tarball and run
  `R CMD check --as-cran` with `-Wall -pedantic` in `R_MAKEVARS_USER`.
  `devtools::check()` overrides `R_MAKEVARS_USER`, so its install log
  understates them. Judge them by R-devel's list of significant warnings
  (`src/library/tools/R/check.R`), not the installed R's, and compile
  as C++20 and for arm64 as well: R-devel adds C++20 deprecations, R
  builds C++20 by default, and CRAN's macOS builds are arm64.

- Pin a stable upstream release, never `master` or a release candidate.
- Record the tag, the commit and the checksums, and write down the update
  procedure so the next bump is mechanical.
- Keep upstream `LICENSE` and `NOTICE` under `src/vendor/<lib>/`, declare the
  vendored code in `DESCRIPTION` and `inst/COPYRIGHTS`.
- Keep the vendor tree clearly separated from first-party source, and record
  every local patch and why it exists.
- **CRAN's compiled-code check applies to vendored code too.** No `stdout` or
  `stderr`, no `printf`, `abort`, `exit` or system RNG may be linked, even
  behind a debug switch that never runs. Remove them with a patch in
  `tools/patches/`, list it in `src/vendor/PROVENANCE`, and make the
  vendor-verify script check "upstream plus exactly these patches". Avoid
  diagnostic-suppressing pragmas too, because they draw their own NOTE. zuhtml
  is the reference: `tools/patches/0002-no-stdio.patch` and
  `tools/verify-vendor`. zuxml's first upload was archived because it
  justified such a symbol instead of patching it.
- Guard against regressions in CI: run `nm -u` on the built objects and fail
  on any of those symbols, so an upstream bump cannot bring them back.

## Commits and pull requests

Short, imperative, sentence-case commit subjects, optionally scoped. Keep each
commit focused and do not sweep in unrelated files. A pull request explains the
user-visible outcome and the rationale, links related issues, lists the checks
that were run and the tests that were skipped, and flags platform-sensitive or
vendored changes. Performance claims need evidence.

Never commit or push to the default branch. Work on a branch, open a pull
request, and leave it for review. Do not merge a pull request unless you are
told to.

When you find a defect, in this package or in an upstream tool, open an issue
for it rather than only working around it.

## Working with skills

The portfolio's workflow skills live in `pedrobtz/r-skills` (`pkg-init`,
`pkg-roadmap`, `pkg-implement`, `pkg-critical-review`, `pkg-cran-review`,
`pkg-post-cran`, `pkg-readme`); the general process skills are
[Superpowers](https://github.com/obra/superpowers). `building-a-package.md`
in `pedrobtz/packages` walks through them in order. Both sets defer to this
file where they overlap, so the settlements are recorded here.

- **One design.** The specification is `.agents/design.md`, adopted from the
  package's RFC in `pedrobtz/packages/rfcs`. A package with an adopted design
  is past `brainstorming`; a design change goes through the RFC, not a new
  spec. Superpowers' default `docs/superpowers/specs/` is not used.
- **Plans at two levels.** `.agents/roadmap.md` holds the stages, one
  mergeable pull request each, with exit criteria and a CI tier
  (`pkg-roadmap`). Inside a stage, `writing-plans` breaks the work into
  tasks of one test cycle each, saved as `.agents/plans/stage-<n>.md`. The
  roadmap stays authoritative; a plan is scratch and is not kept in sync.
- **Build and merge.** `pkg-implement` runs the stage loop: branch
  `stage-<n>-<slug>` from the stage issue, implement the plan with
  `test-driven-development` (`Rscript -e 'devtools::test(filter = "<name>")'`
  is the red/green command), open the pull request, merge on green at the
  stage's CI tier. The confirmation the user gives at the start of that
  loop is the "told to merge" that Commits and pull requests requires, so
  the `finishing-a-development-branch` menu is not presented for stage
  pull requests. Any other pull request still waits for review.
- **Failures and claims.** A failing check or test goes through
  `systematic-debugging` before a fix. "Green", "done" and "ready for CRAN"
  are claimed only after `verification-before-completion`: run the command,
  read the output.
- **Review.** `requesting-code-review` gates tasks inside a stage.
  `pkg-critical-review` reviews the whole package once the roadmap is
  implemented, with Posit's reviewers, and files issues. CRAN's reviewer
  email and GitHub review threads go through `receiving-code-review`.
- **Keep scratch out of the tarball.** `R CMD build` reads `.Rbuildignore`,
  not `.gitignore`. It must list `^\.agents$`, `^\.superpowers$` (the
  Superpowers task ledger), `^\.worktrees$` (if git worktrees are kept in
  the package directory; a sibling directory avoids the question),
  `^\.claude$`, `^CLAUDE\.md$`, `^AGENTS\.md$`, `^CRAN-SUBMISSION$` and
  `^cran-comments\.md$`. A stray top-level file is a NOTE, and the pretest
  archives on NOTEs.
