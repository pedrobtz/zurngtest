# How each RNGkind() turns its output into unif_rand(), from R's
# src/main/RNG.c, and so how to recover its own bits from runif(). `scale`
# is the factor that makes u an exact integer again; NA means it does not
# exist, and the 32 most significant bits of the double are taken. Verified
# on 1e5 draws of each kind (roadmap, Stage 3).
rng_kinds <- list(
  "Mersenne-Twister" = list(
    scale = 2^32,
    width = 32L,
    how = "its 32-bit integers"
  ),
  "Marsaglia-Multicarry" = list(
    scale = 2^32 - 1,
    width = 32L,
    how = "its 32-bit integers"
  ),
  "Super-Duper" = list(
    scale = 2^32 - 1,
    width = 32L,
    how = "its 32-bit integers"
  ),
  "L'Ecuyer-CMRG" = list(
    scale = 4294967088,
    width = 32L,
    how = "its integers, 1 to 4294967087"
  ),
  "Knuth-TAOCP" = list(
    scale = 2^30,
    width = 30L,
    how = "its 30-bit integers, packed into a bit stream"
  ),
  "Knuth-TAOCP-2002" = list(
    scale = 2^30,
    width = 30L,
    how = "its 30-bit integers, packed into a bit stream"
  ),
  "Wichmann-Hill" = list(
    scale = NA_real_,
    width = 32L,
    how = "the 32 most significant bits of each double"
  ),
  "user-supplied" = list(
    scale = NA_real_,
    width = 32L,
    how = "the 32 most significant bits of each double"
  )
)

#' A source of bits from one of R's random number generators
#'
#' `pract_rng()` tests the generator behind [runif()], as chosen by
#' [RNGkind()], with its own bits wherever they can be recovered: the 32-bit
#' integers of Mersenne-Twister, Marsaglia-Multicarry, Super-Duper and
#' L'Ecuyer-CMRG, and the 30-bit integers of the Knuth generators, packed
#' into a continuous bit stream. Wichmann-Hill, which adds three fractions,
#' and user-supplied generators are tested on the 32 most significant bits
#' of each number.
#'
#' The source draws from its own copy of the generator's state, set with
#' `RNGkind(kind)` and `set.seed(seed)`: the session's `.Random.seed` and
#' kind are restored after every draw, so testing does not change the random
#' numbers the session draws, and several `pract_rng()` sources, for example
#' two seeds in [pract_interleave()], each keep their own stream.
#'
#' A user-supplied generator ([Random.user]) keeps its state in its own
#' code. R copies that state into `.Random.seed` only when the generator
#' provides `user_unif_nseed` and `user_unif_seedloc`, so only then can the
#' source keep a stream of its own. Without them, `set.seed()` and the
#' draws act on the generator the session uses: testing it changes the
#' session's stream, and two such sources share one stream.
#'
#' @param kind The generator, as named by [RNGkind()].
#' @param seed The seed passed to [set.seed()]: a whole number of at most
#'   `.Machine$integer.max` in absolute value.
#' @return An object of class `zurngtest_source`.
#' @family sources
#' @export
#' @examples
#' pract_test(pract_rng("Mersenne-Twister"), min_bytes = 2^16, max_bytes = 2^17)
pract_rng <- function(kind = "Mersenne-Twister", seed = 1) {
  if (
    !(is.character(kind) && length(kind) == 1 && kind %in% names(rng_kinds))
  ) {
    zurngtest_abort(
      sprintf(
        "`kind` must be one of %s.",
        paste0('"', names(rng_kinds), '"', collapse = ", ")
      ),
      "zurngtest_invalid_argument"
    )
  }
  if (
    !(is.numeric(seed) &&
      length(seed) == 1 &&
      is.finite(seed) &&
      seed == floor(seed) &&
      abs(seed) <= .Machine$integer.max)
  ) {
    zurngtest_abort(
      "`seed` must be a whole number that set.seed() accepts.",
      "zurngtest_invalid_argument"
    )
  }
  spec <- rng_kinds[[kind]]
  description <- sprintf(
    "R's %s generator (seed %s), %s",
    kind,
    format(seed),
    spec$how
  )
  open <- function() {
    # The reader keeps its own .Random.seed and swaps it in only while it
    # draws, so the session's stream is untouched between fills and several
    # pract_rng() sources (pract_interleave()) do not share one stream.
    restore <- switch_rng(kind, seed)
    on.exit(restore())
    state <- get(".Random.seed", envir = globalenv())
    draw <- function(n) {
      own <- swap_seed(state)
      on.exit(state <<- own())
      stats::runif(n)
    }
    fill <- if (spec$width == 32L) {
      function(nbytes) {
        u <- draw(nbytes %/% 4)
        x <- if (is.na(spec$scale)) floor(u * 2^32) else round(u * spec$scale)
        as_int32(pmin(x, 2^32 - 1))
      }
    } else {
      packed_fill(function(n) as.integer(round(draw(n) * spec$scale)))
    }
    list(fill = fill, close = close_nothing)
  }
  new_source(
    open,
    bits = if (spec$width == 32L) 32L else 0L,
    description = description
  )
}

# Sets the generator and seed, returning a function that puts back the
# kind and the .Random.seed (or its absence) the session had. If setting
# them fails, they are put back before the error leaves.
switch_rng <- function(kind, seed) {
  env <- globalenv()
  had_seed <- exists(".Random.seed", envir = env, inherits = FALSE)
  old_seed <- if (had_seed) get(".Random.seed", envir = env)
  old_kind <- RNGkind()
  restore <- function() {
    suppressWarnings(RNGkind(old_kind[[1]], old_kind[[2]], old_kind[[3]]))
    if (had_seed) {
      assign(".Random.seed", old_seed, envir = env)
    } else if (exists(".Random.seed", envir = env, inherits = FALSE)) {
      rm(".Random.seed", envir = env)
    }
    invisible()
  }
  ok <- FALSE
  on.exit(if (!ok) restore())
  tryCatch(
    suppressWarnings(RNGkind(kind)),
    error = function(cnd) {
      zurngtest_abort(conditionMessage(cnd), "zurngtest_source_error")
    }
  )
  set.seed(seed)
  ok <- TRUE
  restore
}

# Makes `state` the session's .Random.seed, returning a function that puts
# the previous one (or its absence) back and returns the state as it is then.
swap_seed <- function(state) {
  env <- globalenv()
  had_seed <- exists(".Random.seed", envir = env, inherits = FALSE)
  old_seed <- if (had_seed) get(".Random.seed", envir = env)
  old_kind <- if (!had_seed) RNGkind()
  assign(".Random.seed", state, envir = env)
  function() {
    now <- get(".Random.seed", envir = env)
    if (had_seed) {
      # .Random.seed carries the kind, so this restores both.
      assign(".Random.seed", old_seed, envir = env)
    } else {
      # Without a seed R seeds its current kind on the next draw, so that
      # kind must be the session's again; RNGkind() then leaves a seed of
      # its own, which goes.
      suppressWarnings(RNGkind(old_kind[[1]], old_kind[[2]], old_kind[[3]]))
      rm(".Random.seed", envir = env)
    }
    now
  }
}

# Unsigned 32-bit values (as doubles) to the integers with the same bit
# patterns: 2^31 and above wrap to negative, and 2^31 itself is NA_integer_.
as_int32 <- function(x) {
  high <- x >= 2^31
  x[high] <- x[high] - 2^32
  suppressWarnings(as.integer(x))
}

# A fill function for 30-bit values: `draw(n)` returns n values below 2^30,
# packed four at a time into 15 bytes, most significant bit first, with the
# bytes beyond a request kept for the next.
packed_fill <- function(draw) {
  pending <- raw()
  function(nbytes) {
    short <- nbytes - length(pending)
    if (short > 0) {
      pending <<- c(pending, pack30(draw(4L * ceiling(short / 15))))
    }
    out <- pending[seq_len(nbytes)]
    pending <<- pending[-seq_len(nbytes)]
    out
  }
}

pack30 <- function(v) {
  m <- matrix(v, nrow = 4L)
  w1 <- m[1L, ]
  w2 <- m[2L, ]
  w3 <- m[3L, ]
  w4 <- m[4L, ]
  shr <- bitwShiftR
  and <- bitwAnd
  shl <- bitwShiftL
  bytes <- rbind(
    shr(w1, 22L),
    and(shr(w1, 14L), 255L),
    and(shr(w1, 6L), 255L),
    bitwOr(shl(and(w1, 63L), 2L), shr(w2, 28L)),
    and(shr(w2, 20L), 255L),
    and(shr(w2, 12L), 255L),
    and(shr(w2, 4L), 255L),
    bitwOr(shl(and(w2, 15L), 4L), shr(w3, 26L)),
    and(shr(w3, 18L), 255L),
    and(shr(w3, 10L), 255L),
    and(shr(w3, 2L), 255L),
    bitwOr(shl(and(w3, 3L), 6L), shr(w4, 24L)),
    and(shr(w4, 16L), 255L),
    and(shr(w4, 8L), 255L),
    and(w4, 255L)
  )
  as.raw(bytes)
}
