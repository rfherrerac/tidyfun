#' Gather all columns representing functional measurements into a `tfd`-object
#'
#' Similar in spirit to [tidyr::gather()], but does NOT put the values in the
#' gathered columns into one very long "value"-column while labeling the different
#' original columns in a very long "key"-column -- instead it creates a `tfd`-column
#' containing the functional measurements of the columns given in `...`.
#'
#' @param data a data frame -- note that `dplyr` does not handle matrix columns well,
#'    if `data` contains more than one of those, `tf_gather` will fail...
#' @param ... A selection of columns to collect as a `tfd` object. Each column
#'   represents measurements of a functional variable at a specific `arg`-val.
#'   Can also be the name of a matrix-valued column, but see above.
#'   If empty, all variables are selected. You can supply bare variable names,
#'   select all variables between x and z with x:z, exclude y with -y. For more
#'   options, see the [dplyr::select()] documentation.
#' @param key the name of the created `tfd`-column. Defaults to `".tfd"`, and
#'   the function will try to guess the name based on the column names of the
#'   gathered columns in this case. If a common prefix of all column names
#'   is found, this is used instead. You also get a message about this.
#' @param arg If not provided, will be guessed from the column names as well.
#'   See [tfd()].
#' @inheritParams tfd
#' @return a modified `data.frame` with a `tfd` column replacing the `...`.
#' @importFrom rlang is_empty :=  quo_name enexpr
#' @importFrom tidyselect vars_select
#' @importFrom stringr str_replace
#' @export
#' @seealso dplyr::select() tfd() tf_nest() tf_unnest()
#' @examples
#' (d <- dplyr::as.tbl(data.frame(refund::DTI[1:5,]$cca[, 1:10])))
#' tf_gather(d)
#' tf_gather(d, key = "cca_tf")
#' tf_gather(d, arg = seq(0, 1, l = 10))$cca
#' (d2 <- dplyr::bind_cols(id = rownames(d), d))
#' tf_gather(d2, -id) # tf_gather(d2, matches("cca")); tf_gather(d2, -1); etc
tf_gather <- function(data, ..., key = ".tfd", arg = NULL, domain = NULL,
                      evaluator = tf_approx_linear, resolution = NULL) {
  key_var <- quo_name(enexpr(key))
  evaluator <- quo_name(enexpr(evaluator))
  search_key <- isTRUE(key == ".tfd")
  quos <- enquos(...)
  if (rlang::is_empty(quos)) {
    gather_vars <- names(data)
  } else {
    gather_vars <- unname(vars_select(names(data), !!!quos))
  }
  if (rlang::is_empty(gather_vars)) {
    return(data)
  }
  # turn matrix column into regular columns:
  if (length(gather_vars) == 1) {
    if (is.matrix(data[[gather_vars]]) & search_key) {
      key_var <- gather_vars
      search_key <- FALSE
      message("creating new tfd-column <", key_var, ">")
    }
  }

  tfd_data <- data %>% select(gather_vars) %>% as.matrix()
  if (search_key) {
    # see also find_arg: will interpret separating-dashes as minus-signs
    # regex adapted from https://www.regular-expressions.info/floatingpoint.html
    found_key <- unique(str_replace(
      colnames(tfd_data),
      "[-+]?(0|(0\\.[0-9]+)|([1-9][0-9]*\\.?[0-9]*))([eE][-+]?[0-9]+)?$", ""
    ))
    # assume trailing punctuation is separator:
    found_key <- str_replace(found_key, "[:punct:]$", "")
    if (length(found_key) == 1 & all(found_key != "")) {
      key_var <- found_key
      message("creating new tfd-column <", key_var, ">")
    }
  }

  data %>%
    select(-gather_vars) %>%
    mutate(!!key_var :=
      tfd(tfd_data,
        arg = arg, domain = domain, evaluator = !!evaluator,
        resolution = resolution
      ))
}


#' Spread a `tf`-column into many columns representing the
#' function evaluations.
#'
#' Similar in spirit to [tidyr::spread()], but does NOT shorten,
#' just widens the data frame  -- a `tf`-column is spread out into many columns
#' containing the functional measurements.
#'
#' @param data a data frame with at least one `tf`-column
#' @param value the name of the `tf`-column to 'spread'/evaluate.
#'   You can supply bare variable names etc., see the [dplyr::select()]
#'   documentation. Also works without this if there's only one `tf` in `data`,
#'   see examples.
#' @param arg (Semi-)optional. A vector of `arg`-values on which to evaluate the
#'   functions. If not provided, uses the default `arg`s. Needs to be
#'   specified for `f_irreg`.
#' @param sep separating character used to create column names for the new columns,
#'   defaults to `"_"` for column names "<name of the `tf`>_<`arg`-value>".
#'   Set to NULL to get column names that only contain the `arg`-value.
#' @param interpolate `interpolate`-argument for evaluating the functional data.
#'   Defaults to TRUE, i.e., `tfd`s are inter/extrapolated on unobserved `arg`-values.
#' @importFrom tidyselect vars_pull
#' @export
#' @examples
#' d <- dplyr::tibble(g = 1:3)
#' d$f <- tf_rgp(3, 11L)
#' tf_spread(d, f)
#' tf_spread(d, -g)
#' tf_spread(d)
tf_spread <- function(data, value, arg, sep = "_", interpolate = TRUE) {
  if (missing(value)) {
    tf_cols <- which(map_lgl(data, is_tf))
    if (length(tf_cols) == 0) {
      warning(
        "<value>-argument ", sQuote(tf_var),
        " is not a column of class 'tf'. Nothing's happening here."
      )
      return(data)
    }
    if (length(tf_cols) == 1) {
      value <- tf_cols
    } else {
      stop("More than one `tf` found, specify which one to spread in <value>.")
    }
  }
  tf_var <- tidyselect::vars_pull(names(data), !!enquo(value))
  tf <- data[[tf_var]]
  if (!is_tf(tf)) {
    warning(
      "<value>-argument ", sQuote(tf_var),
      " is not a column of class 'tf'. Nothing's happening here."
    )
    return(data)
  }
  if (missing(arg)) {
    if (is_irreg(tf)) {
      stop("need explicit <arg> for irregular ", sQuote(tf_var), ".")
    }
    arg <- tf_arg(tf)
  }
  tf_eval <- tf[, arg, matrix = TRUE, interpolate = interpolate] %>%
    as.data.frame()
  if (!is.null(sep)) colnames(tf_eval) <- paste0(tf_var, sep, arg)
  data %>% select(-!!tf_var) %>% bind_cols(tf_eval)
}


# ------------------------------------------------------------------------------

#' Turn "long" tables into tidy data frames with `tf`-objects
#'
#' Similar in spirit to [tidyr::nest()]. This turns tables in "long" format,
#' where one column (`.id`) defines the unit of observation, one column (`.arg`)
#' defines the evaluation of the functional observations, and other columns (`...`)
#' define the values of the functions into a (much shorter) table containing
#' `tfd`-objects. All other variables are checked for constancy over `.id` and
#' appended as well.
#'
#' `domain`, `resolution` and `evaluator` can be speficied as lists or vectors
#' if you're nesting multiple functional data columns with different properties.
#' Because quasi-quotation is *such* a bitch, you can only specify the evaluator
#' functions as strings and not as bare names here.
#'
#' @param data a data frame
#' @param ... A selection of columns. If empty, all variables except the
#'   `.id` and `.arg` columns are selected. You can supply bare variable names,
#'   select all variables between `x` and `z` with `x:z`, exclude `y` with `-y`.
#'   For more options, see the [dplyr::select()] documentation.
#' @param .id the (bare or quoted) name of the column defining the different observations
#' @param .arg the (bare or quoted) name of the column defining the `arg`-values of the observed functions
#' @inheritParams tfd
#' @return a data frame with (at least) `.id` and `tfd` columns
#' @export
#' @seealso tf_gather(), tf_unnest(), tfd() for `domain, evaluator, resolution`
tf_nest <- function(data, ..., .id = "id", .arg = "arg", domain = NULL,
                    evaluator = "tf_approx_linear", resolution = NULL) {
  stopifnot(!missing(data))
  id_var <- quo_name(enexpr(.id))
  arg_var <- quo_name(enexpr(.arg))
  quos <- quos(...)
  if (is_empty(quos)) {
    value_vars <- setdiff(names(data), c(id_var, arg_var))
  } else {
    value_vars <- unname(vars_select(names(data), !!!quos))
  }
  if (is_empty(value_vars)) {
    return(data)
  }
  # homogenize inputs:
  stopifnot(length(evaluator) %in% c(1, length(value_vars)))
  if (!is.list(domain)) {
    domain <- replicate(length(value_vars), domain, simplify = FALSE)
  } else {
    stopifnot(length(domain) %in% c(1, length(value_vars)))
  }
  if (is.null(resolution)) {
    resolution <- replicate(length(value_vars), resolution, simplify = FALSE)
  }
  if (!is.list(resolution) & !is.null(resolution)) {
    resolution <- as.list(resolution)
  } else {
    stopifnot(length(resolution) %in% c(1, length(value_vars)))
  }
  evaluator <- as.list(evaluator)
  stopifnot(length(evaluator) %in% c(1, length(value_vars)))

  remaining <- setdiff(names(data), c(id_var, arg_var, value_vars))
  # check that nesting is possible without information loss
  ret <- select(data, !!id_var, !!remaining) %>%
    group_by(!!as.name(id_var))
  not_constant <- ret %>%
    summarise_all(n_distinct) %>%
    select(-!!id_var) %>%
    summarise_all(function(x) !all(x == 1L)) %>%
    select_if(isTRUE)
  if (ncol(not_constant)) {
    stop(
      "Can't nest - columns ", paste(names(not_constant), collapse = ", "),
      " are not constant for all levels of the id-variable."
    )
  }

  ret <- slice(ret, 1) %>% ungroup()
  # TODO: parallelize this over evaluator, domain, resolution
  tfd_list <- pmap(
    list(value_vars, evaluator, domain, resolution),
    ~select(data, id_var, arg_var, !!(..1)) %>%
      tfd(evaluator = !!(..2), domain = ..3, resolution = ..4)
  )
  names(tfd_list) <- value_vars
  # re-index to make sure order is correct
  id_index <- pull(ret, id_var)
  if (is.factor(id_index)) id_index <- as.character(id_index)
  for (v in value_vars) {
    ret[[v]] <- tfd_list[[v]][id_index, ]
  }
  ret
}

#-------------------------------------------------------------------------------

#' Turn data frames with `tf`-objects / list columns into "long" tables.
#'
#' Similar in spirit to [tidyr::unnest()], the reverse of [tf_nest()].
#' Caution -- uses slightly different defaults for names of unnested columns
#' than `tidyr::unnest()`.  
#' **Add an ID column to your data before unnesting!** If your nested data does
#' not include an ID column with a unique identifier for each row, you will not
#' be able to match arg-value pairs to different functions after unnesting, see 
#' `.id`-argument below.
#'
#' @param data a data frame
#' @param .arg optional values for the `arg` argument of
#'   [tf_evaluate.data.frame()]
#' @param try_dropping should `tf_unnest` try to avoid duplicating `id` or `arg`
#'   columns? Defaults to TRUE.
#' @inheritParams tf_evaluate.data.frame
#' @inheritParams tidyr::unnest
#' @return a "long" data frame with  `tf`-columns expanded into `id, arg, value`-
#'   columns.
#' @export
#' @seealso tf_gather(), tf_nest(), tf_evaluate.data.frame()
#' @importFrom digest digest
#' @importFrom utils data tail
#' @importFrom rlang syms `!!!` expr_text
tf_unnest <- function(data, cols, .arg, .id = "id", keep_empty = FALSE,
                      ptype = NULL, names_sep = "_",
                      names_repair = "check_unique", try_dropping = TRUE) {
  
  if (missing(cols)) {
    tf_cols <- names(data)[map_lgl(data, is_tf)]
    cols <- expr(c(!!!syms(tf_cols)))
    warning(paste0("`cols` is now required.\n", "Please use `cols = ", 
                expr_text(cols), "`"))
  }
  
  ret <- tf_evaluate.data.frame(data, !!enquo(cols), arg = .arg) %>% 
    tidyr::unnest(cols = !!enquo(cols), keep_empty = keep_empty,
                  ptype = ptype, names_sep = names_sep, 
                  names_repair = names_repair)
  
  if (try_dropping) {
    # drop duplicated arg/id columns if possible:
    arg_pattern <- paste0(names_sep, "arg$")
    same_arg <- ret %>%
      select(c(matches("^arg$"), matches(!!!arg_pattern))) %>%
      # stackoverflow.com/questions/7585316
      summarize_all(digest::digest) %>%
      t() %>%
      duplicated() %>%
      tail(-1) %>%
      {
        row.names(.)[which(.)]
      }
    id_pattern <- paste0(names_sep, "id$")
    same_id <- ret %>%
      select(c(matches("^id$", ignore.case = FALSE), matches(!!!id_pattern))) %>%
      # stackoverflow.com/questions/7585316
      summarize_all(function(x) digest::digest(as.character(x))) %>%
      t() %>%
      duplicated() %>%
      tail(-1) %>%
      {
        row.names(.)[which(.)]
      }
    if (length(same_arg)) ret <- ret %>% select(-!!same_arg)
    if (length(same_id)) ret <- ret %>% select(-!!same_id)
    if (length(c(same_arg, same_id))) {
      message(
        "Duplicate column", ifelse(length(c(same_arg, same_id)) > 1, "s ", " "),
        paste(same_arg, collapse = ", "), " ", paste(same_id, collapse = ", "),
        " created by unnesting were dropped."
      )
      # only rename left over columns if there was more than one and we don't
      # overwrite anything by doing so
      one_arg_left <- 
        length(vars_select(names(ret), matches(!!!arg_pattern))) == 1
      if (!("arg" %in% names(ret)) & one_arg_left & length(same_arg)) {
        new_arg <- select(ret, matches(!!!arg_pattern)) %>% names()
        ret <- rename(ret, arg = !!new_arg)
        message("Renamed ", sQuote(new_arg), " to 'arg'.")
      }
      one_id_left <- length(vars_select(names(ret), matches(!!!id_pattern))) == 1
      if (!("id" %in% names(ret)) & one_id_left & length(same_id)) {
        new_id <- select(ret, matches(!!!id_pattern)) %>% names()
        ret <- rename(ret, id = !!new_id)
        message("Renamed ", sQuote(new_id), " to 'id'.")
      }
    }
  }
  ret
}
