#' yappr: Hebrew NLP in R via YAP, in the quanteda workflow
#'
#' \code{yappr} is an R client for YAP (Yet Another Parser), the ONLP Lab's
#' open-source Hebrew morphological analyzer, disambiguator, and dependency
#' parser (\url{https://github.com/OnlpLab/yap}).
#'
#' Everything runs locally: YAP is a Go server listening on
#' \code{http://localhost:8000}, and \code{yappr} is a thin HTTP client.
#' On Windows, run YAP inside WSL \emph{--} native Windows builds of YAP
#' currently produce a non-working Hebrew tokenizer.
#'
#' @section Typical workflow:
#' \preformatted{
#' library(yappr)
#' library(quanteda)
#'
#' # Parse Hebrew text (auto-tokenizes for YAP's wire format)
#' parsed <- yap_parse(c(doc1 = "\u05D4\u05D9\u05DC\u05D3\u05D9\u05DD."),
#'                     dependency = TRUE)
#'
#' # Lemma-based DFM in one call, with Hebrew stopwords + content POS filter
#' yap_to_dfm(docs, heb_lemma = TRUE)
#' }
#'
#' @section Main functions:
#' \describe{
#'   \item{\code{\link{yap_parse}} / \code{\link{yap_dep}}}{Parse Hebrew
#'     text into a \code{yap_parsed} data frame.}
#'   \item{\code{\link{yap_to_tokens}} / \code{\link{yap_to_dfm}}}{Drop
#'     straight into quanteda. \code{heb_lemma = TRUE} turns on the full
#'     Hebrew pipeline (lemma + content POS + stopwords + punct strip).}
#'   \item{\code{\link{yap_start}} / \code{\link{yap_stop}}}{Manage a local
#'     YAP server on Linux/macOS (Windows users run it from WSL instead).}
#'   \item{\code{\link{yap_doctor}} / \code{\link{yap_install}}}{Check
#'     prerequisites and clone/build YAP on Linux/macOS.}
#' }
#'
#' @docType package
#' @name yappr-package
#' @aliases yappr
"_PACKAGE"
