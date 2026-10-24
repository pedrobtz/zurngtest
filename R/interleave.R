#' Interleave sources word by word
#'
#' `pract_interleave()` combines sources into one stream that takes one word
#' from each in turn, for seeding studies: two seeds of one generator,
#' substreams, or several generators whose combination, rather than any one
#' of them, may be what fails.
#'
#' All sources must have the same word size: the words are those of
#' [pract_fun()] and [pract_rng()] sources, or single bytes for
#' [pract_raw()] sources and Knuth generators. The stream ends when any
#' source ends.
#'
#' @param ... Two or more sources, from [pract_raw()], [pract_fun()],
#'   [pract_rng()] or `pract_interleave()`.
#' @return An object of class `zurngtest_source`.
#' @family sources
#' @export
#' @examples
#' seeds <- pract_interleave(pract_rng(seed = 1), pract_rng(seed = 2))
#' pract_test(seeds, min_bytes = 2^16, max_bytes = 2^17)
pract_interleave <- function(...) {
  sources <- list(...)
  if (length(sources) < 2) {
    zurngtest_abort(
      "Interleaving needs at least two sources.",
      "zurngtest_invalid_argument"
    )
  }
  if (!all(vapply(sources, inherits, logical(1), "zurngtest_source"))) {
    zurngtest_abort(
      paste(
        "Every argument must be a source, from pract_raw(), pract_fun(),",
        "pract_rng() or pract_interleave()."
      ),
      "zurngtest_invalid_argument"
    )
  }
  bits <- unique(vapply(sources, function(s) s$bits, integer(1)))
  if (length(bits) != 1) {
    zurngtest_abort(
      "The sources must have the same word size.",
      "zurngtest_invalid_argument"
    )
  }
  word <- if (bits == 0L) 1L else bits %/% 8L
  k <- length(sources)
  description <- paste0(
    "interleaving of ",
    paste(vapply(sources, function(s) s$description, ""), collapse = "; ")
  )
  open <- function() {
    readers <- list()
    close <- function() {
      for (reader in readers) {
        reader$close()
      }
      invisible()
    }
    ok <- FALSE
    on.exit(if (!ok) close())
    for (source in sources) {
      readers[[length(readers) + 1L]] <- source$open()
    }
    pending <- raw()
    ended <- FALSE
    fill <- function(nbytes) {
      short <- nbytes - length(pending)
      if (short > 0 && !ended) {
        rounds <- ceiling(short / (k * word))
        parts <- lapply(readers, function(r) as_bytes(r$fill(rounds * word)))
        whole <- min(vapply(parts, length, integer(1))) %/% word
        if (whole < rounds) {
          ended <<- TRUE
        }
        words <- vapply(
          parts,
          function(p) p[seq_len(whole * word)],
          raw(whole * word)
        )
        # words: one column per source, `word` bytes per round; reorder to
        # round by round, source by source.
        dim(words) <- c(word, whole, k)
        pending <<- c(pending, as.vector(aperm(words, c(1L, 3L, 2L))))
      }
      take <- min(nbytes, length(pending))
      out <- pending[seq_len(take)]
      pending <<- pending[-seq_len(take)]
      out
    }
    ok <- TRUE
    list(fill = fill, close = close)
  }
  new_source(open, bits = bits, description = description)
}

# A source's chunk as raw bytes in memory order.
as_bytes <- function(data) {
  if (is.integer(data)) {
    writeBin(data, raw(), endian = .Platform$endian)
  } else {
    data
  }
}
