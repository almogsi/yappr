# ---------------------------------------------------------------------------
# quanteda integration.
#
# Design: mirror the spacyr / udpipe pattern. `yap_parse()` returns a tidy
# data frame; we then expose an `as.tokens()` method that turns it into a
# quanteda::tokens object. This keeps the NLP layer (YAP) and the
# text-analysis layer (quanteda) cleanly separated.
#
# The S3 dispatch for `quanteda::as.tokens` is registered at load time in
# .onLoad() (see zzz.R) so that `quanteda` only needs to be present when the
# user actually calls as.tokens(), not at package install time.
#
# yap_to_dfm() additionally offers a one-shot `heb_lemma = TRUE` pipeline:
# lemma + content-POS filter + trailing-punct strip + Hebrew stopwords.
# ---------------------------------------------------------------------------

#\' Convert parsed YAP output to a quanteda::tokens object
#\'
#\' Turns a \code{yap_parsed} data frame into a \pkg{quanteda}
#\' \code{tokens} object. Each document becomes one element; each morpheme
#\' becomes one token. By default tokens are the surface forms
#\' (\code{token}); set \code{use_lemma = TRUE} to use lemmas.
#\'
#\' @param x A \code{yap_parsed} data frame.
#\' @param use_lemma Logical. Use the \code{lemma} column instead of
#\'   \code{token}. Default \code{FALSE}.
#\' @param concatenator Passed to \code{quanteda::as.tokens}. Default
#\'   \code{"_"}.
#\' @param remove_punct If \code{TRUE}, drop tokens whose POS starts with
#\'   \code{"yy"} (YAP\'s punctuation prefix).
#\' @param pos_keep Optional character vector of POS tags to retain.
#\' @param ... Unused, for S3 compatibility.
#\'
#\' @return A \pkg{quanteda} \code{tokens} object.
#\' @method as.tokens yap_parsed
#\'
#\' @note Registered at load time in \code{\link{.onLoad}} via
#\'   \code{registerS3method()}.
as.tokens.yap_parsed <- function(x,
                                 use_lemma    = FALSE,
                                 concatenator = "_",
                                 remove_punct = FALSE,
                                 pos_keep     = NULL,
                                 ...) {
  .require_pkg("quanteda",
               "to convert yap_parsed output to a tokens object")

  df <- as.data.frame(x)

  if (remove_punct && "pos" %in% names(df)) {
    df <- df[!grepl("^yy", df$pos), , drop = FALSE]
  }
  if (!is.null(pos_keep) && "pos" %in% names(df)) {
    df <- df[df$pos %in% pos_keep, , drop = FALSE]
  }

  col <- if (isTRUE(use_lemma)) "lemma" else "token"
  if (!col %in% names(df)) {
    stop("Expected a column called \'", col, "\' in the parsed data frame.",
         call. = FALSE)
  }

  doc_order <- unique(df$doc_id)
  tok_list  <- split(df[[col]], factor(df$doc_id, levels = doc_order))
  tok_list  <- lapply(tok_list, function(v) v[!is.na(v) & nzchar(v)])

  quanteda::as.tokens(tok_list, concatenator = concatenator)
}

#\' Non-S3 wrapper around \code{\link{as.tokens.yap_parsed}}
#\'
#\' @inheritParams as.tokens.yap_parsed
#\' @return A \pkg{quanteda} \code{tokens} object.
#\' @export
yap_to_tokens <- function(x,
                          use_lemma    = TRUE,
                          remove_punct = TRUE,
                          pos_keep     = NULL,
                          concatenator = "_") {
  as.tokens.yap_parsed(x,
                       use_lemma    = use_lemma,
                       remove_punct = remove_punct,
                       pos_keep     = pos_keep,
                       concatenator = concatenator)
}

#\' One-step parse-and-build-DFM
#\'
#\' Parse Hebrew text with YAP and return a \pkg{quanteda} document-feature
#\' matrix. With \code{heb_lemma = TRUE} (the default) the result is the
#\' full Hebrew-aware pipeline: lemma column + content-POS filter + trailing
#\' punctuation stripped + Hebrew stopwords removed (if the
#\' \pkg{stopwords} package is installed).
#\'
#\' @param text Character vector, data frame with \code{doc_id}/\code{text},
#\'   or \code{quanteda::corpus}.
#\' @param heb_lemma Logical. If \code{TRUE} (default), apply the full
#\'   Hebrew-lemma pipeline described above.
#\' @param use_lemma Logical. Use lemmas instead of surface forms. Forced
#\'   to \code{TRUE} when \code{heb_lemma = TRUE}. Default \code{TRUE}.
#\' @param pos_keep Character vector of POS tags to keep. When
#\'   \code{heb_lemma = TRUE} and this is \code{NULL}, defaults to
#\'   content words: NN, NNT, NNP, VB, JJ, RB.
#\' @param remove_punct If \code{TRUE}, drop tokens whose POS starts with
#\'   \code{"yy"}. Default \code{TRUE}.
#\' @param remove_stopwords If \code{TRUE}, remove Hebrew stopwords via
#\'   the \pkg{stopwords} package. Default \code{TRUE}.
#\' @param stopword_source Passed to \code{stopwords::stopwords}. Default
#\'   \code{"stopwords-iso"}.
#\' @param strip_trailing_punct If \code{TRUE}, strip trailing punctuation
#\'   from each token (YAP leaves sentence-final "." attached to the last
#\'   morpheme). Default \code{TRUE}.
#\' @param url,timeout,verbose Passed through to \code{\link{yap_parse}}.
#\'
#\' @return A \pkg{quanteda} \code{dfm}.
#\' @export
yap_to_dfm <- function(text,
                       heb_lemma            = TRUE,
                       use_lemma            = TRUE,
                       pos_keep             = NULL,
                       remove_punct         = TRUE,
                       remove_stopwords     = TRUE,
                       stopword_source      = "stopwords-iso",
                       strip_trailing_punct = TRUE,
                       url                  = NULL,
                       timeout              = 120,
                       verbose              = FALSE) {
  .require_pkg("quanteda", "to build a document-feature matrix")

  if (isTRUE(heb_lemma)) {
    use_lemma <- TRUE
    if (is.null(pos_keep)) pos_keep <- .HEB_CONTENT_POS
  }

  parsed <- yap_parse(text, dependency = FALSE, url = url,
                      timeout = timeout, verbose = verbose)

  # Strip trailing punctuation on the data.frame side (base sub()) -- not via
  # quanteda::tokens_replace(), because that function matches whole tokens for
  # regex patterns and would replace "token." with "" instead of "token".
  if (isTRUE(heb_lemma) && isTRUE(strip_trailing_punct)) {
    for (col in c("lemma", "token")) {
      if (col %in% names(parsed)) {
        parsed[[col]] <- sub("[[:punct:]]+$", "", parsed[[col]])
      }
    }
    col <- if (isTRUE(use_lemma)) "lemma" else "token"
    parsed <- parsed[nzchar(parsed[[col]]), , drop = FALSE]
  }

  toks <- yap_to_tokens(parsed,
                        use_lemma    = use_lemma,
                        remove_punct = remove_punct,
                        pos_keep     = pos_keep)

  if (isTRUE(heb_lemma) && isTRUE(remove_stopwords)
      && requireNamespace("stopwords", quietly = TRUE)) {
    he_stops <- tryCatch(
      stopwords::stopwords("he", source = stopword_source),
      error = function(e) character()
    )
    if (length(he_stops)) toks <- quanteda::tokens_remove(toks, he_stops)
  }

  quanteda::dfm(toks)
}
