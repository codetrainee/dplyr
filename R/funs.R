#' Create a list of functions calls.
#'
#' \Sexpr[results=rd, stage=render]{dplyr:::lifecycle("soft-deprecated")}
#'
#' @description
#'
#' `funs()` provides a flexible way to generate a named list of
#' functions for input to other functions like [summarise_at()].
#'
#' @param ... A list of functions specified by:
#'
#'  - Their name, `"mean"`
#'  - The function itself, `mean`
#'  - A call to the function with `.` as a dummy argument,
#'    `mean(., na.rm = TRUE)`
#'
#'  These arguments are automatically [quoted][rlang::quo]. They
#'  support [unquoting][rlang::quasiquotation] and splicing. See
#'  `vignette("programming")` for an introduction to these concepts.
#'
#'  The following notations are **not** supported, see examples:
#'
#'  - An anonymous function, `function(x) mean(x, na.rm = TRUE)`
#'  - An anonymous function in \pkg{purrr} notation, `~mean(., na.rm = TRUE)`
#'
#' @param .args,args A named list of additional arguments to be added to all
#'   function calls. As `funs()` is being deprecated, use other methods to
#'   supply arguments: `...` argument in [scoped verbs][summarise_at()] or make
#'   own functions with [purrr::partial()].
#' @export
#' @examples
#' funs(mean, "mean", mean(., na.rm = TRUE))
#'
#' # Override default names
#' funs(m1 = mean, m2 = "mean", m3 = mean(., na.rm = TRUE))
#'
#' # If you have function names in a vector, use funs_
#' fs <- c("min", "max")
#' funs_(fs)
#'
#' # Not supported
#' \dontrun{
#' funs(function(x) mean(x, na.rm = TRUE))
#' funs(~mean(x, na.rm = TRUE))}
funs <- function(..., .args = list()) {
  signal_soft_deprecated(paste_line(
    "funs() is soft deprecated as of dplyr 0.8.0",
    "please use list() instead",
    "",
    "# Before:",
    "funs(name = f(.))",
    "",
    "# After: ",
    "list(name = ~f(.))"
  ))
  dots <- quos(...)
  default_env <- caller_env()

  funs <- map(dots, function(quo) as_fun(quo, default_env, .args))
  new_funs(funs)
}
new_funs <- function(funs) {
  attr(funs, "have_name") <- any(names2(funs) != "")

  # Workaround until rlang:::label() is exported
  temp <- map(funs, function(fn) node_car(quo_get_expr(fn)))
  temp <- exprs_auto_name(temp)
  names(funs) <- names(temp)

  class(funs) <- "fun_list"
  funs
}

as_fun_list <- function(.funs, .env, ...) {
  args <- list2(...)

  if (is_fun_list(.funs)) {
    if (!is_empty(args)) {
      .funs[] <- map(.funs, call_modify, !!!args)
    }
    return(.funs)
  }

  if (!is_character(.funs) && !is_list(.funs)) {
    .funs <- list(.funs)
  }

  funs <- map(.funs, function(.x){
    if (is_formula(.x)) {
      # processing unquote operator at inlining time
      # for rlang lambdas
      .x <- expr_interp(.x)
      .x <- as_function(.x, env = .env)
    } else {
      if (is_character(.x)) {
        .x <- get(.x, .env, mode = "function")
      } else if (!is_function(.x)) {
        abort("not expecting this")
      }
      if (length(args)) {
        # swoosh the extra arguments so that we have a function that only
        # takes one argument `.`, or `.x` as a synonym
        .x <- new_function(
          list( . =missing_arg(), .x = sym(".")),
          call2(.x, sym("."), !!!args),
          env = .env
        )
      }
    }
    .x
  })
  attr(funs, "have_name") <- any(names2(funs) != "")
  funs
}


as_fun <- function(.x, .env, .args) {
  quo <- as_quosure(.x, .env)

  # For legacy reasons, we support strings. Those are enclosed in the
  # empty environment and need to be switched to the caller environment.
  quo <- quo_set_env(quo, fun_env(quo, .env))

  expr <- quo_get_expr(quo)

  if (is_call(expr, c("function", "~"))) {
    top_level <- as_string(expr[[1]])
    bad_args(quo_text(expr), "must be a function name (quoted or unquoted) or an unquoted call, not `{top_level}`")
  }

  if (is_call(expr) && !is_call(expr, c("::", ":::"))) {
    expr <- call_modify(expr, !!!.args)
  } else {
    expr <- call2(expr, quote(.), !!!.args)
  }

  set_expr(quo, expr)
}

quo_as_function <- function(quo) {
  new_function(exprs(. = ), quo_get_expr(quo), quo_get_env(quo))
}

fun_env <- function(quo, default_env) {
  env <- quo_get_env(quo)
  if (is_null(env) || identical(env, empty_env())) {
    default_env
  } else {
    env
  }
}

is_fun_list <- function(x) {
  inherits(x, "fun_list")
}
#' @export
`[.fun_list` <- function(x, i) {
  structure(NextMethod(),
    class = "fun_list",
    has_names = attr(x, "has_names")
  )
}
#' @export
print.fun_list <- function(x, ..., width = getOption("width")) {
  cat("<fun_calls>\n")
  names <- format(names(x))

  code <- map_chr(x, function(x) deparse_trunc(quo_get_expr(x), width - 2 - nchar(names[1])))

  cat(paste0("$ ", names, ": ", code, collapse = "\n"))
  cat("\n")
  invisible(x)
}

#' @export
#' @rdname se-deprecated
#' @inheritParams funs
#' @param env The environment in which functions should be evaluated.
funs_ <- function(dots, args = list(), env = base_env()) {
  signal_soft_deprecated(paste_line(
    "funs_() is deprecated. ",
    "Please use list() instead"
  ))

  dots <- compat_lazy_dots(dots, caller_env())
  funs(!!!dots, .args = args)
}
