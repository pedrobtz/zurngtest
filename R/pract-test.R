#' Test a source of random bits with 'PractRand'
#'
#' Runs a 'PractRand' battery on the bits from `source`, reporting results at
#' doubling lengths from `min_bytes` to `max_bytes`, as 'PractRand''s
#' `RNG_test` does.
#'
#' Each test result is evaluated with 'PractRand''s own labels and
#' thresholds, as its `RNG_test` evaluates them; see the Evaluations section.
#' A source has failed at the first length with any result labelled "FAIL".
#'
#' @section Evaluations:
#' 'PractRand' scores each result in decimal digits: about
#' \eqn{\log_{10}(1/p)} for its p-value \eqn{p}, less \eqn{\log_{10}(1/w)} for
#' its share \eqn{w} of the weight of all the results, so the more results a
#' run has, the more improbable one must be to stand out. With 100 equally
#' weighted results, a p-value of \eqn{10^{-5}} scores about 3. The labels,
#' by score, are:
#'
#' | Score | Evaluation |
#' | --- | --- |
#' | 0 | normal |
#' | above 0 | normalish |
#' | above 1 | unusual |
#' | above 2 | mildly suspicious |
#' | above 3 | suspicious |
#' | above 4 | very suspicious |
#' | above 6 | VERY SUSPICIOUS |
#' | above 8.5 | FAIL |
#' | above 12, 17, 25, 45, 85, 165, 325, 999 | FAIL ! to FAIL !!!!!!!! |
#'
#' "unusual" results are expected now and then in a long run of a good
#' generator; a "FAIL" is not.
#'
#' A result with no valid p-value has `NA` for `p_value` and `evaluation`,
#' and is left out of the evaluation of the others. 'PractRand' 0.96's
#' expanded battery gives such results from its NS3 tests even on good
#' input; `RNG_test` stops on them.
#'
#' A source that ends early (a raw vector or connection with fewer bytes
#' than `max_bytes`) ends the run: the last rows are at the number of bytes
#' tested, rounded down to a whole kilobyte. If it ends before `min_bytes`,
#' that is an error. An interrupt also ends the run, and returns the results
#' of the lengths completed before it, as does an error raised by 'PractRand'
#' itself, which the NS3 tests of the expanded battery can raise on heavily
#' failing input; that is reported in a warning of class
#' `zurngtest_stopped`.
#'
#' @param source A source of bits, from [pract_raw()], [pract_fun()],
#'   [pract_rng()] or [pract_interleave()].
#' @param battery The 'PractRand' battery: `"core"`, the recommended set of
#'   tests, or `"expanded"`, a wider and slower set.
#' @param min_bytes,max_bytes The shortest and longest lengths tested, in
#'   bytes: powers of two of at least 1024.
#' @param stop_on_failure If `TRUE`, stop at the first length where the
#'   source fails.
#' @param folding If `TRUE`, also run the tests on 'PractRand''s standard
#'   foldings of the data (for example its low bits), by the source's word
#'   size.
#' @param seed The seed of the generator 'PractRand' uses inside some tests,
#'   a whole number from 0 to 2^53. `NULL` uses 0, so runs are reproducible.
#' @return A data frame of class `zurngtest_result`, with one row per test
#'   result at each length: `bytes` (the length), `test` (the test name),
#'   `p_value` and `evaluation` ('PractRand''s label). Its attributes are
#'   `failed_at`, the first length with a failure or `NA`, `source`, a
#'   description of the source, and `elapsed`, the run time in seconds.
#' @export
#' @examples
#' # A repeating pattern fails at once
#' pattern <- pract_raw(rep(as.raw(0:255), 2^8))
#' pract_test(pattern, min_bytes = 2^16, max_bytes = 2^16)
#'
#' # R's own generator, as bytes
#' bytes <- pract_fun(function(n) as.raw(sample.int(256L, n, TRUE) - 1L), bits = 8)
#' pract_test(bytes, min_bytes = 2^16, max_bytes = 2^17)
pract_test <- function(
  source,
  battery = c("core", "expanded"),
  min_bytes = 2^20,
  max_bytes = 2^34,
  stop_on_failure = TRUE,
  folding = TRUE,
  seed = NULL
) {
  call <- sys.call()
  if (!inherits(source, "zurngtest_source")) {
    zurngtest_abort(
      paste(
        "`source` must come from pract_raw(), pract_fun(), pract_rng() or",
        "pract_interleave()."
      ),
      "zurngtest_invalid_argument"
    )
  }
  if (
    !(is.character(battery) &&
      length(battery) >= 1 &&
      all(battery %in% battery_names))
  ) {
    zurngtest_abort(
      sprintf(
        "`battery` must be one of %s.",
        paste0('"', battery_names, '"', collapse = ", ")
      ),
      "zurngtest_invalid_argument"
    )
  }
  battery <- battery[[1]]
  check_length_arg(min_bytes, "min_bytes")
  check_length_arg(max_bytes, "max_bytes")
  if (max_bytes < min_bytes) {
    zurngtest_abort(
      "`max_bytes` must be at least `min_bytes`.",
      "zurngtest_invalid_argument"
    )
  }
  check_flag(stop_on_failure, "stop_on_failure")
  check_flag(folding, "folding")
  if (is.null(seed)) {
    seed <- 0
  }
  if (
    !(is.numeric(seed) &&
      length(seed) == 1 &&
      is.finite(seed) &&
      seed >= 0 &&
      seed < 2^53 &&
      seed == floor(seed))
  ) {
    zurngtest_abort(
      "`seed` must be NULL or a whole number from 0 to 2^53.",
      "zurngtest_invalid_argument"
    )
  }

  lengths <- min_bytes * 2^(0:log2(max_bytes / min_bytes))
  start <- proc.time()[["elapsed"]]
  driver <- driver_new(battery, folding, source$bits, seed, max_bytes)
  on.exit(driver_free(driver), add = TRUE)

  # A source's errors name this call, not the source's own functions.
  from_source <- function(expr) {
    tryCatch(expr, zurngtest_source_error = function(cnd) {
      cnd$call <- call
      stop(cnd)
    })
  }
  reader <- from_source(source$open())
  on.exit(reader$close(), add = TRUE)

  chunk <- 2^24
  fed <- 0
  ended <- FALSE
  rows <- list()
  failed_at <- NA_real_

  # An error PractRand raises while testing or reporting (its NS3 tests can,
  # on heavily failing input) ends the run like an interrupt: the lengths
  # completed so far are returned, with a warning.
  halted <- FALSE
  halt <- function(error, bytes) {
    halted <<- TRUE
    warning(warningCondition(
      sprintf(
        "PractRand stopped the run after %s bytes: %s",
        format(bytes, scientific = FALSE),
        conditionMessage(error)
      ),
      class = "zurngtest_stopped",
      call = call
    ))
  }

  add_rows <- function(bytes) {
    res <- tryCatch(driver_results(driver), zurngtest_internal_error = identity)
    if (inherits(res, "condition")) {
      halt(res, bytes)
      return(invisible())
    }
    rows[[length(rows) + 1]] <<- data.frame(
      bytes = rep(bytes, length(res$test)),
      test = res$test,
      p_value = res$p_value,
      evaluation = res$evaluation,
      stringsAsFactors = FALSE
    )
    failed <- any(startsWith(res$evaluation, "FAIL"), na.rm = TRUE)
    if (is.na(failed_at) && failed) {
      failed_at <<- bytes
    }
  }

  tryCatch(
    for (len in lengths) {
      while (fed < len && !ended && !halted) {
        want <- min(len - fed, chunk)
        data <- from_source(reader$fill(want))
        got <- byte_length(data)
        if (got < want) {
          ended <- TRUE
          data <- whole_blocks(data)
          got <- byte_length(data)
        }
        if (got > 0) {
          error <- tryCatch(
            {
              driver_feed(driver, data)
              NULL
            },
            zurngtest_internal_error = identity
          )
          if (!is.null(error)) {
            halt(error, fed + got)
          }
        }
        fed <- fed + got
      }
      if (halted) {
        break
      }
      if (fed < len) {
        if (fed < min_bytes) {
          zurngtest_abort(
            sprintf(
              "The source ended after %s bytes, before `min_bytes` (%s).",
              format(fed, scientific = FALSE),
              format(min_bytes, scientific = FALSE)
            ),
            "zurngtest_source_error",
            bytes = fed,
            call = call
          )
        }
        if (fed > len / 2) {
          add_rows(fed)
        }
        break
      }
      add_rows(len)
      if (halted) {
        break
      }
      if (stop_on_failure && !is.na(failed_at)) {
        break
      }
    },
    interrupt = function(cnd) NULL
  )

  result <- do.call(rbind, c(rows, list(make.row.names = FALSE)))
  if (is.null(result)) {
    result <- data.frame(
      bytes = numeric(),
      test = character(),
      p_value = numeric(),
      evaluation = character(),
      stringsAsFactors = FALSE
    )
  }
  structure(
    result,
    class = c("zurngtest_result", "data.frame"),
    failed_at = failed_at,
    source = source$description,
    elapsed = proc.time()[["elapsed"]] - start
  )
}

# Bytes in a source's chunk: raw bytes, or 32-bit integer words.
byte_length <- function(data) {
  if (is.integer(data)) 4 * length(data) else length(data)
}

# The leading whole 1024-byte blocks of a chunk; the tail is dropped.
whole_blocks <- function(data) {
  keep <- byte_length(data) %/% 1024 * 1024
  if (is.integer(data)) data[seq_len(keep / 4)] else data[seq_len(keep)]
}

check_length_arg <- function(x, name) {
  ok <- is.numeric(x) &&
    length(x) == 1 &&
    is.finite(x) &&
    x >= 1024 &&
    log2(x) == round(log2(x))
  if (!ok) {
    zurngtest_abort(
      sprintf("`%s` must be a power of two of at least 1024.", name),
      "zurngtest_invalid_argument",
      call = sys.call(-1)
    )
  }
}

check_flag <- function(x, name) {
  if (!(is.logical(x) && length(x) == 1 && !is.na(x))) {
    zurngtest_abort(
      sprintf("`%s` must be TRUE or FALSE.", name),
      "zurngtest_invalid_argument",
      call = sys.call(-1)
    )
  }
}

#' @export
print.zurngtest_result <- function(x, ...) {
  cat(
    "PractRand ",
    zurngtest_info()$practrand,
    " test of ",
    attr(x, "source"),
    "\n",
    sep = ""
  )
  for (len in unique(x$bytes)) {
    at <- x[x$bytes == len, , drop = FALSE]
    cat("length= ", format_length(len), "\n", sep = "")
    no_p <- sum(is.na(at$evaluation))
    at <- at[!is.na(at$evaluation), , drop = FALSE]
    marked <- at[!at$evaluation %in% c("normal", "normalish"), , drop = FALSE]
    if (nrow(marked) > 0) {
      cat(sprintf("  %-34s%-14s%s\n", "Test Name", "p-value", "Evaluation"))
      cat(
        sprintf(
          "  %-34s%-14s%s\n",
          marked$test,
          format(marked$p_value, digits = 3),
          marked$evaluation
        ),
        sep = ""
      )
    }
    unmarked <- nrow(at) - nrow(marked)
    if (nrow(marked) == 0) {
      cat("  no anomalies in ", nrow(at), " test result(s)\n", sep = "")
    } else if (unmarked > 0) {
      cat(
        "  ...and ",
        unmarked,
        " test result(s) without anomalies\n",
        sep = ""
      )
    }
    if (no_p > 0) {
      cat("  ", no_p, " test result(s) without a p-value\n", sep = "")
    }
  }
  failed_at <- attr(x, "failed_at")
  cat(
    if (is.na(failed_at)) {
      "No failure"
    } else {
      paste0("Failed at ", format_length(failed_at))
    },
    sprintf(", time= %.1f seconds\n", attr(x, "elapsed")),
    sep = ""
  )
  invisible(x)
}

# A length as RNG_test prints it: "64 kilobytes (2^16 bytes)".
format_length <- function(bytes) {
  units <- c("kilobyte", "megabyte", "gigabyte", "terabyte", "petabyte")
  power <- log2(bytes)
  unit <- max(1, min(length(units), floor(power / 10)))
  amount <- bytes / 2^(10 * unit)
  if (power == round(power)) {
    sprintf(
      "%.0f %s%s (2^%.0f bytes)",
      amount,
      units[[unit]],
      if (amount == 1) "" else "s",
      power
    )
  } else {
    sprintf("%.3f %ss (2^%.3f bytes)", amount, units[[unit]], power)
  }
}
