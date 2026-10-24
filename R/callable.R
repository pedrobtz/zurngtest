# pract_test() for a generator in C, called by zurngtest_test_cfun()
# (src/callable.cpp) with the generator in `ptr`: the source fills each chunk
# natively. `options` is a list of further pract_test() arguments, by name,
# or NULL.
test_cfun <- function(ptr, options) {
  arguments <- setdiff(names(formals(pract_test)), "source")
  given <- names(options)
  ok <- is.null(options) ||
    (is.list(options) && length(options) == 0) ||
    (is.list(options) &&
      !is.null(given) &&
      all(given %in% arguments) &&
      !anyDuplicated(given))
  if (!ok) {
    zurngtest_abort(
      paste0(
        "`options` must be NULL or a list of pract_test() arguments by ",
        "name: ",
        paste(arguments, collapse = ", "),
        "."
      ),
      "zurngtest_invalid_argument",
      call = quote(zurngtest_test_cfun())
    )
  }
  open <- function() {
    list(
      fill = function(nbytes) {
        out <- .Call(zrt_cfun_fill, ptr, nbytes)
        if (is.null(out)) {
          zurngtest_abort(
            paste(
              "The C generator is gone: its zurngtest_test_cfun() call has",
              "returned."
            ),
            "zurngtest_source_error"
          )
        }
        out
      },
      close = function() invisible()
    )
  }
  source <- new_source(
    open,
    bits = 32L,
    description = "C function, 32-bit words"
  )
  # By name, so that a condition's call reads pract_test(source, ...) rather
  # than holding the source and its generator.
  do.call("pract_test", c(list(quote(source)), options))
}
