# ---------------------------------------------------------------------------
# Send Hebrew text to YAP and parse the response.
#
# YAP's /yap/heb/joint endpoint returns JSON that looks roughly like:
#
# {
#   "ma_lattice": "<CoNLL-like TSV, ambiguous lattice>",
#   "md_lattice": "<CoNLL-like TSV, disambiguated>",
#   "dep_tree":   "<CoNLL-like TSV with head/deprel>",
#   "segmented_text": "..."
# }
#
# The md_lattice columns (as emitted by YAP) are:
#   FROM  TO  FORM  LEMMA  CPOSTAG  POSTAG  FEATS  TOKEN
# where FROM/TO are lattice edge indices and TOKEN is the 1-based index of the
# original whitespace-separated token that the morpheme belongs to.
#
# The dep_tree columns are the standard CoNLL-style:
#   ID  FORM  LEMMA  CPOSTAG  POSTAG  FEATS  HEAD  DEPREL  PHEAD  PDEPREL
# YAP emits 8 columns (ID .. DEPREL); the last two are typically absent.
#
# IMPORTANT: YAP's HTTP endpoint silently returns `{}` when the `text` field is
# a space-separated sentence. It requires tokens to be separated by newlines,
# with a trailing blank line to terminate the sentence. We handle this in
# .heb_tokenize_for_yap() and call it on every document before sending.
# ---------------------------------------------------------------------------

# Column specs kept as package-internal constants so other code stays DRY.
.YAP_MD_COLS  <- c("from", "to", "token", "lemma",
                   "cpostag", "postag", "feats", "token_id")
.YAP_DEP_COLS <- c("id", "token", "lemma", "cpostag", "postag",
                   "feats", "head", "deprel")

#\' Parse Hebrew text with YAP
#\'
#\' Sends one or more documents to the local YAP server's joint endpoint and
#\' returns a tidy data frame: one row per morpheme, with document, sentence,
#\' and (optionally) dependency annotations. The result is a
#\' \code{\link[=as.tokens.yap_parsed]{yap_parsed}} object and is designed to
#\' plug straight into the \pkg{quanteda} workflow.
#\'
#\' @param text A character vector (named for \code{doc_id}), a
#\'   \code{quanteda::corpus}, or a data frame with columns \code{doc_id}
#\'   and \code{text}.
#\' @param dependency If \code{TRUE}, also request dependency parsing and
#\'   attach \code{head} and \code{deprel} columns.
#\' @param url Base URL of the YAP server. Defaults to the running local
#\'   server, then to \code{"http://localhost:8000"}.
#\' @param timeout HTTP request timeout in seconds.
#\' @param keep_lattice If \code{TRUE}, keep the ambiguous \code{ma_lattice}
#\'   as an attribute of the returned object for advanced use.
#\' @param pre_tokenized If \code{TRUE}, \code{text} is already in YAP's
#\'   expected wire format (one token per line, trailing blank line) and is
#\'   sent verbatim. Default \code{FALSE}, in which case each document is
#\'   auto-tokenized on whitespace before being sent. YAP's HTTP endpoint
#\'   silently returns \code{{}} for space-separated input, so auto-tokenization
#\'   is essential and on by default.
#\' @param verbose Print per-document progress.
#\'
#\' @return A data frame (class \code{yap_parsed}) with columns:
#\'   \code{doc_id, sentence_id, token_id, token, lemma, pos, xpos, feats}
#\'   and, when \code{dependency = TRUE}, also \code{head_token_id} and
#\'   \code{deprel}.
#\'
#\' @examples
#\' \dontrun{
#\'   parsed <- yap_parse(
#\'     c(doc1 = "\u05D4\u05D9\u05DC\u05D3\u05D9\u05DD \u05D4\u05DC\u05DB\u05D5."),
#\'     dependency = TRUE
#\'   )
#\'   head(parsed)
#\' }
#\'
#\' @export
yap_parse <- function(text,
                      dependency = FALSE,
                      url = NULL,
                      timeout = 120,
                      keep_lattice = FALSE,
                      pre_tokenized = FALSE,
                      verbose = FALSE) {
  docs <- .normalize_input(text)
  url  <- .resolve_url(url)

  all_rows <- vector("list", length(docs))
  lattices <- if (keep_lattice) vector("list", length(docs)) else NULL

  # Single pass: one HTTP round trip per document.
  for (i in seq_along(docs)) {
    doc_id <- names(docs)[[i]]
    txt    <- docs[[i]]
    if (verbose) message("[", i, "/", length(docs), "] ", doc_id)

    wire <- if (pre_tokenized) txt else .heb_tokenize_for_yap(txt)
    resp <- .yap_post(url, "/yap/heb/joint", list(text = wire),
                      timeout = timeout)

    md <- .parse_conll(resp$md_lattice, .YAP_MD_COLS)
    md <- .coerce_int(md, c("from", "to", "token_id"))

    if (dependency) {
      dep <- .parse_conll(resp$dep_tree, .YAP_DEP_COLS)
      dep <- .coerce_int(dep, c("id", "head"))
      md <- .zip_md_dep(md, dep)
    }

    if (!nrow(md)) next

    out <- data.frame(
      doc_id      = doc_id,
      sentence_id = md$sentence_id,
      token_id    = .per_sentence_idx(md$sentence_id),
      token       = md$token,
      lemma       = md$lemma,
      pos         = md$cpostag,
      xpos        = md$postag,
      feats       = md$feats,
      stringsAsFactors = FALSE
    )
    if (dependency) {
      out$head_token_id <- md$head
      out$deprel        <- md$deprel
    }

    all_rows[[i]] <- out
    if (keep_lattice) lattices[[i]] <- resp$ma_lattice
  }

  out <- do.call(rbind, all_rows[!vapply(all_rows, is.null, logical(1))])
  if (is.null(out)) {
    out <- .empty_parse(dependency)
  }
  rownames(out) <- NULL
  class(out) <- c("yap_parsed", "data.frame")
  attr(out, "url") <- url
  if (keep_lattice) attr(out, "ma_lattice") <- lattices
  out
}

#\' Dependency-only parsing
#\'
#\' Shortcut for \code{yap_parse(..., dependency = TRUE)}.
#\'
#\' @inheritParams yap_parse
#\' @return A \code{yap_parsed} data frame including \code{head_token_id}
#\'   and \code{deprel}.
#\' @export
yap_dep <- function(text, url = NULL, timeout = 120,
                    pre_tokenized = FALSE, verbose = FALSE) {
  yap_parse(text, dependency = TRUE, url = url, timeout = timeout,
            pre_tokenized = pre_tokenized, verbose = verbose)
}

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# POST JSON to the YAP endpoint and return the parsed response body as a list.
.yap_post <- function(url, path, body, timeout = 120) {
  full <- paste0(sub("/+$", "", url), path)
  resp <- tryCatch(
    httr::POST(
      full,
      body = jsonlite::toJSON(body, auto_unbox = TRUE),
      httr::timeout(timeout),
      httr::add_headers("Content-Type" = "application/json; charset=utf-8")
    ),
    error = function(e) {
      stop("Could not reach YAP at ", url, ": ", conditionMessage(e),
           "\nIs the server running? On Linux/macOS try yap_start(); ",
           "on Windows, start YAP inside WSL (see README).",
           call. = FALSE)
    }
  )
  if (httr::http_error(resp)) {
    stop("YAP returned HTTP ", httr::status_code(resp),
         " for ", path, ".", call. = FALSE)
  }
  parsed <- tryCatch(
    httr::content(resp, as = "parsed", type = "application/json",
                  encoding = "UTF-8"),
    error = function(e) {
      txt <- httr::content(resp, as = "text", encoding = "UTF-8")
      jsonlite::fromJSON(txt, simplifyVector = FALSE)
    }
  )
  parsed
}

# Within each sentence, assign 1..n to rows in the order they appear.
.per_sentence_idx <- function(sentence_id) {
  out <- integer(length(sentence_id))
  last_sid <- NA_integer_
  k <- 0L
  for (i in seq_along(sentence_id)) {
    sid <- sentence_id[[i]]
    if (is.na(last_sid) || sid != last_sid) {
      k <- 0L
      last_sid <- sid
    }
    k <- k + 1L
    out[i] <- k
  }
  out
}

# Row-align the md_lattice and dep_tree parses.
.zip_md_dep <- function(md, dep) {
  if (!nrow(md)) return(cbind(md, head = integer(0), deprel = character(0)))
  md$head   <- NA_integer_
  md$deprel <- NA_character_
  if (!nrow(dep)) return(md)
  sids <- unique(md$sentence_id)
  for (s in sids) {
    mi <- which(md$sentence_id == s)
    di <- which(dep$sentence_id == s)
    n  <- min(length(mi), length(di))
    if (n == 0L) next
    if (length(mi) != length(di)) {
      warning("md_lattice and dep_tree lengths differ in sentence ", s,
              " (", length(mi), " vs ", length(di),
              "); aligning the first ", n, " rows.", call. = FALSE)
    }
    md$head[mi[seq_len(n)]]   <- as.integer(dep$head[di[seq_len(n)]])
    md$deprel[mi[seq_len(n)]] <- dep$deprel[di[seq_len(n)]]
  }
  md
}

.empty_parse <- function(dependency) {
  base <- data.frame(
    doc_id      = character(0),
    sentence_id = integer(0),
    token_id    = integer(0),
    token       = character(0),
    lemma       = character(0),
    pos         = character(0),
    xpos        = character(0),
    feats       = character(0),
    stringsAsFactors = FALSE
  )
  if (dependency) {
    base$head_token_id <- integer(0)
    base$deprel        <- character(0)
  }
  base
}

#\' @export
print.yap_parsed <- function(x, n = 10, ...) {
  cat("<yap_parsed> ", nrow(x), " morphemes across ",
      length(unique(x$doc_id)), " document(s)\n", sep = "")
  NextMethod("print", utils::head(as.data.frame(x), n), ...)
  invisible(x)
}
