#' Sources of bits for `pract_test()`
#'
#' A source tells [pract_test()] where the bits to test come from.
#' `pract_raw()` reads raw bytes, from a raw vector or a binary connection,
#' in order. `pract_fun()` calls an R function for more bits each time the
#' test needs them. [pract_rng()] draws from one of R's own generators, and
#' [pract_interleave()] combines sources word by word.
#'
#' A raw vector or connection that ends before the test does ends the run
#' early; see [pract_test()]. A raw vector source can be used for several
#' runs, each reading from the start. A connection that is not open is opened
#' in binary mode for the run and closed after it, which destroys it, as
#' [readLines()] does, so it serves one run; an open connection is read from
#' where it is and left open.
#'
#' @param x A raw vector, or a connection to read bytes from.
#' @param f A function of one argument, `n`, returning `n` words of `bits`
#'   bits: an integer vector of length `n` when `bits` is 32, or a raw vector
#'   of `n * bits / 8` bytes for any `bits`. Integers are taken as their
#'   32-bit patterns, so `NA` is the word `0x80000000`.
#' @param bits The size in bits of the words `f` returns: 8, 16, 32 or 64.
#'   'PractRand' folds its tests to the word size; `pract_raw()` sources have
#'   no word size, as with 'PractRand''s `RNG_test stdin`.
#' @return An object of class `zurngtest_source`.
#' @family sources
#' @export
#' @examples
#' pract_raw(as.raw(sample(0:255, 1024, replace = TRUE)))
#'
#' # R's own generator, as bytes
#' pract_fun(function(n) as.raw(sample.int(256L, n, TRUE) - 1L), bits = 8)
pract_raw <- function(x) {
  if (is.raw(x)) {
    description <- sprintf("raw vector of %s bytes", format(length(x)))
    open <- function() {
      pos <- 0
      list(
        fill = function(nbytes) {
          take <- min(nbytes, length(x) - pos)
          out <- x[pos + seq_len(take)]
          pos <<- pos + take
          out
        },
        close = function() invisible()
      )
    }
  } else if (inherits(x, "connection")) {
    description <- sprintf("connection %s", summary(x)$description)
    open <- function() {
      opened <- !isOpen(x)
      if (opened) {
        base::open(x, "rb")
      }
      list(
        fill = function(nbytes) readBin(x, "raw", nbytes),
        close = function() {
          if (opened) {
            close(x)
          }
          invisible()
        }
      )
    }
  } else {
    zurngtest_abort(
      "`x` must be a raw vector or a connection.",
      "zurngtest_invalid_argument"
    )
  }
  new_source(open, bits = 0L, description = description)
}

#' @rdname pract_raw
#' @export
pract_fun <- function(f, bits = 32) {
  if (!is.function(f)) {
    zurngtest_abort("`f` must be a function.", "zurngtest_invalid_argument")
  }
  if (!(is.numeric(bits) && length(bits) == 1 && bits %in% c(8, 16, 32, 64))) {
    zurngtest_abort(
      "`bits` must be 8, 16, 32 or 64.",
      "zurngtest_invalid_argument"
    )
  }
  bits <- as.integer(bits)
  word_bytes <- bits %/% 8L
  description <- sprintf(
    "function %s, %d-bit words",
    paste(deparse(substitute(f)), collapse = " "),
    bits
  )
  open <- function() {
    list(
      fill = function(nbytes) {
        n <- nbytes %/% word_bytes
        words <- f(n)
        if (is.integer(words) && bits == 32L) {
          check_length(words, n)
        } else if (is.raw(words)) {
          check_length(words, nbytes)
        } else {
          zurngtest_abort(
            sprintf(
              "`f` must return %s, not %s.",
              if (bits == 32L) "an integer or raw vector" else "a raw vector",
              class(words)[[1]]
            ),
            "zurngtest_source_error"
          )
        }
        words
      },
      close = function() invisible()
    )
  }
  new_source(open, bits = bits, description = description)
}

check_length <- function(words, expected) {
  if (length(words) != expected) {
    zurngtest_abort(
      sprintf(
        "`f` returned %s elements where %s were asked for.",
        format(length(words)),
        format(expected)
      ),
      "zurngtest_source_error",
      expected = expected,
      actual = length(words)
    )
  }
}

new_source <- function(open, bits, description) {
  structure(
    list(open = open, bits = bits, description = description),
    class = "zurngtest_source"
  )
}

#' @export
print.zurngtest_source <- function(x, ...) {
  cat("<zurngtest_source> ", x$description, "\n", sep = "")
  invisible(x)
}
