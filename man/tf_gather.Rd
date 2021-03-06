% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/tidyr.R
\name{tf_gather}
\alias{tf_gather}
\title{Gather all columns representing functional measurements into a \code{tfd}-object}
\usage{
tf_gather(
  data,
  ...,
  key = ".tfd",
  arg = NULL,
  domain = NULL,
  evaluator = tf_approx_linear,
  resolution = NULL
)
}
\arguments{
\item{data}{a data frame -- note that \code{dplyr} does not handle matrix columns well,
if \code{data} contains more than one of those, \code{tf_gather} will fail...}

\item{...}{A selection of columns to collect as a \code{tfd} object. Each column
represents measurements of a functional variable at a specific \code{arg}-val.
Can also be the name of a matrix-valued column, but see above.
If empty, all variables are selected. You can supply bare variable names,
select all variables between x and z with x:z, exclude y with -y. For more
options, see the \code{\link[dplyr:select]{dplyr::select()}} documentation.}

\item{key}{the name of the created \code{tfd}-column. Defaults to \code{".tfd"}, and
the function will try to guess the name based on the column names of the
gathered columns in this case. If a common prefix of all column names
is found, this is used instead. You also get a message about this.}

\item{arg}{If not provided, will be guessed from the column names as well.
See \code{\link[=tfd]{tfd()}}.}

\item{domain}{range of the \code{arg}.}

\item{evaluator}{a function accepting arguments \verb{x, arg, evaluations}. See details for \code{\link[=tfd]{tfd()}}.}

\item{resolution}{resolution of the evaluation grid. See details for \code{\link[=tfd]{tfd()}}.}
}
\value{
a modified \code{data.frame} with a \code{tfd} column replacing the \code{...}.
}
\description{
Similar in spirit to \code{\link[tidyr:gather]{tidyr::gather()}}, but does NOT put the values in the
gathered columns into one very long "value"-column while labeling the different
original columns in a very long "key"-column -- instead it creates a \code{tfd}-column
containing the functional measurements of the columns given in \code{...}.
}
\examples{
(d <- dplyr::as.tbl(data.frame(refund::DTI[1:5,]$cca[, 1:10])))
tf_gather(d)
tf_gather(d, key = "cca_tf")
tf_gather(d, arg = seq(0, 1, l = 10))$cca
(d2 <- dplyr::bind_cols(id = rownames(d), d))
tf_gather(d2, -id) # tf_gather(d2, matches("cca")); tf_gather(d2, -1); etc
}
\seealso{
dplyr::select() tfd() tf_nest() tf_unnest()
}
