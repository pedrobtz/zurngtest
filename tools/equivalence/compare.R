# Compare pract_test() with PractRand's own RNG_test on the same bytes.
#
#   Rscript tools/equivalence/compare.R <path-to-RNG_test>
#
# Run from the package root with zurngtest installed. For each case below
# both tools test the same bytes with the core battery and standard folding
# at every length from 64 KiB to the case's maximum (-tlmaxonly: on past a
# failure); at every length the test names, the evaluations and the p-values
# (to the precision RNG_test prints) must agree. Exits non-zero on any
# difference, on an RNG_test that fails, and on a length either tool did not
# report.
args <- commandArgs(TRUE)
rng_test <- normalizePath(args[[1]])
suppressMessages(library(zurngtest))

# 32-bit words in native order, as RNG_test stdin32 reads them, served by an
# R function as pract_fun() calls it.
word_reader <- function(words) {
  pos <- 0
  function(n) {
    out <- words[pos + seq_len(n)]
    pos <<- pos + n
    out
  }
}

mersenne <- function(bytes) {
  withr::local_seed(1, .rng_kind = "Mersenne-Twister")
  as.raw(sample.int(256L, bytes, TRUE) - 1L)
}

counter <- seq_len(2^18) - 1L

cases <- list(
  # Fails at once, and hard.
  pattern = list(bytes = rep(as.raw(0:255), length.out = 2^20)),
  # Passes.
  mersenne = list(bytes = mersenne(2^20)),
  # 32-bit counter words as bytes: fails, on some tests only.
  counter = list(bytes = writeBin(counter, raw())),
  # The same words with 32-bit folding, as pract_fun(), pract_rng() and the
  # C callable fold them.
  counter32 = list(
    bytes = writeBin(counter, raw()),
    mode = "stdin32",
    source = pract_fun(word_reader(counter), bits = 32)
  ),
  # Past the driver's 16 MiB chunk, so its carried-over blocks are compared.
  long = list(bytes = mersenne(2^25), max_bytes = 2^25)
)

# RNG_test -a lines: "  Name (34 chars)  R= +1.2  p = 0.5  evaluation", or
# "pass"/"fail" in place of the p-value for pass/fail results.
row_pattern <- paste0(
  "^  (.{34})R[=<>]\\s*(\\S+)\\s+",
  "(p\\s*~?=\\s*\\S+|\"pass\"|\"fail\")",
  "\\s+(\\S.*?)\\s*$"
)

parse_rng_test <- function(lines) {
  rows <- list()
  bytes <- NA_real_
  for (line in lines) {
    if (startsWith(line, "length= ")) {
      bytes <- 2^as.numeric(sub(".*\\(2\\^([0-9.]+) bytes\\).*", "\\1", line))
      next
    }
    m <- regmatches(line, regexec(row_pattern, line))[[1]]
    if (length(m) == 5) {
      rows[[length(rows) + 1]] <- data.frame(
        bytes = bytes,
        test = trimws(m[[2]]),
        p_text = m[[4]],
        evaluation = trimws(m[[5]]),
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

# p as RNG_test prints it, with the half-unit of its last printed digit:
# "8.0e-797" (0 in a double), "1-2.3e-9", "0.5", "0", and "pass" or "fail"
# for pass/fail results, whose p-value is non-zero for a pass.
parse_p <- function(text) {
  value <- sub("^p\\s*~?=\\s*", "", text)
  pass_fail <- value %in% c("\"pass\"", "\"fail\"")
  one_minus <- startsWith(value, "1-")
  num <- sub("^1-", "", value)
  mantissa <- sub("e.*", "", num)
  decimals <- ifelse(
    grepl(".", mantissa, fixed = TRUE),
    nchar(sub(".*\\.", "", mantissa)),
    0
  )
  exponent <- ifelse(
    grepl("e", num),
    suppressWarnings(as.numeric(sub(".*e", "", num))),
    0
  )
  x <- suppressWarnings(as.numeric(num))
  data.frame(
    p = ifelse(
      pass_fail,
      as.numeric(value == "\"pass\""),
      ifelse(one_minus, 1 - x, x)
    ),
    # One unit of the last digit: RNG_test truncates some mantissas.
    tol = ifelse(pass_fail, NA, 1.0001 * 10^(exponent - decimals) + 1e-12),
    pass_fail = pass_fail
  )
}

# Agreement to printed precision; values beyond what a double holds agree
# when both are at the same end.
same_p <- function(parsed, ours) {
  theirs <- parsed$p
  tiny <- theirs < 1e-290 & ours < 1e-290
  huge <- theirs > 1 - 1e-12 & ours > 1 - 1e-12
  ifelse(
    parsed$pass_fail,
    (ours > 0) == (theirs > 0),
    tiny | huge | abs(theirs - ours) <= parsed$tol
  )
}

failures <- 0
fail <- function(name, ...) {
  cat(sprintf("%-9s %s\n", name, paste0(...)))
  failures <<- failures + 1
}
for (name in names(cases)) {
  case <- cases[[name]]
  max_bytes <- if (is.null(case$max_bytes)) 2^20 else case$max_bytes
  mode <- if (is.null(case$mode)) "stdin" else case$mode
  source <- if (is.null(case$source)) pract_raw(case$bytes) else case$source
  lengths <- 2^(16:log2(max_bytes))
  file <- tempfile(fileext = ".bin")
  writeBin(case$bytes, file)
  out <- suppressWarnings(system2(
    rng_test,
    c(
      mode,
      "-a",
      "-tlmin",
      "64KB",
      "-tlmax",
      sprintf("%.0fKB", max_bytes / 1024),
      "-tlmaxonly"
    ),
    stdin = file,
    stdout = TRUE,
    stderr = TRUE
  ))
  status <- attr(out, "status")
  if (!is.null(status) && status != 0) {
    fail(name, "RNG_test exited with status ", status, ":")
    cat(paste0("  ", tail(out, 5), "\n"), sep = "")
    next
  }
  theirs <- parse_rng_test(out)
  ours <- pract_test(
    source,
    min_bytes = 2^16,
    max_bytes = max_bytes,
    stop_on_failure = FALSE
  )
  if (is.null(theirs) || !setequal(theirs$bytes, lengths)) {
    fail(name, "RNG_test did not report every length from 64 KiB")
    next
  }
  if (!setequal(ours$bytes, lengths)) {
    fail(name, "pract_test() did not report every length from 64 KiB")
    next
  }
  for (len in lengths) {
    t <- theirs[theirs$bytes == len, ]
    o <- ours[ours$bytes == len, ]
    problems <- character()
    if (!setequal(t$test, o$test)) {
      problems <- c(
        problems,
        paste(
          "only in RNG_test:",
          paste(setdiff(t$test, o$test), collapse = ", ")
        ),
        paste(
          "only in pract_test:",
          paste(setdiff(o$test, t$test), collapse = ", ")
        )
      )
    }
    common <- intersect(t$test, o$test)
    t <- t[match(common, t$test), ]
    o <- o[match(common, o$test), ]
    differ <- t$evaluation != o$evaluation
    if (any(differ)) {
      problems <- c(
        problems,
        sprintf(
          "evaluation of %s: RNG_test %s, pract_test %s",
          common[differ],
          t$evaluation[differ],
          o$evaluation[differ]
        )
      )
    }
    off <- which(!same_p(parse_p(t$p_text), o$p_value))
    if (length(off)) {
      problems <- c(
        problems,
        sprintf(
          "p-value of %s: RNG_test %s, pract_test %.3g",
          common[off],
          t$p_text[off],
          o$p_value[off]
        )
      )
    }
    if (length(problems)) {
      fail(name, sprintf("%8.0f bytes: %d results, DIFFERENT", len, nrow(t)))
      cat(paste0("  ", problems, "\n"), sep = "")
    } else {
      cat(sprintf("%-9s %8.0f bytes: %d results, same\n", name, len, nrow(t)))
    }
  }
}
if (failures > 0) {
  quit(status = 1)
}
