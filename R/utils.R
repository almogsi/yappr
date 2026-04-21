# ---------------------------------------------------------------------------
# Internal utilities for yappr
# ---------------------------------------------------------------------------

# Package-level environment to hold the running server reference, the base URL,
# and any session-wide options. Keeping state in an env lets yap_parse() find
# the server without the user having to pass it around explicitly.
.yappr <- new.env(parent = emptyenv())
.yappr$base_url <- NULL       # e.g. "http://localhost:8000"
.yappr$server   <- NULL       # processx::process handle, if we launched it
.yappr$yap_path <- NULL       # directory where ./yap lives

# Default URL when nothing else is known. YAP's default port is 8000.
# `localhost` (not 127.0.0.1) so WSL2's automatic port forwarding works on
# Windows clients without the user having to touch anything.
.default_url <- function() "http://localhost:8000"

# Resolve the URL to use for a request: explicit > stored > default.
.resolve_url <- function(url = NULL) {
  if (!is.null(url) && nzchar(url)) return(url)
  if (!is.null(.yappr$base_url)) return(.yappr$base_url)
  .default_url()
}

# Normalize the `text` input into a named character vector keyed by doc_id.
# Accepts: a character vector (named or unnamed), a corpus/tokens from
# quanteda (character coercion), or a data.frame with doc_id/text columns.
.normalize_input <- function(text) {
  if (is.data.frame(text)) {
    if (!all(c("doc_id", "text") %in% names(text))) {
      stop("When `text` is a data.frame it must have columns 'doc_id' and 'text'.",
           call. = FALSE)
    }
    out <- as.character(text$text)
    names(out) <- as.character(text$doc_id)
    return(out)
  }
  if (inherits(text, "corpus")) {
    return(as.character(text))
  }
  if (!is.character(text)) {
    stop("`text` must be a character vector, a data.frame with doc_id/text, ",
         "or a quanteda corpus.", call. = FALSE)
  }
  if (is.null(names(text)) || any(!nzchar(names(text)))) {
    names(text) <- paste0("text", seq_along(text))
  }
  text
}

# Require a suggested package or fail clearly.
.require_pkg <- function(pkg, reason = "") {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(sprintf(
      "Package '%s' is required%s. Install with install.packages('%s').",
      pkg, if (nzchar(reason)) paste0(" ", reason) else "", pkg),
      call. = FALSE)
  }
}

# YAP returns lattices as CoNLL-like tab-separated text. This parser converts
# one such block into a data.frame.
.parse_conll <- function(text, cols) {
  if (is.null(text) || !nzchar(text)) {
    return(.empty_df(cols))
  }
  lines <- strsplit(text, "\n", fixed = TRUE)[[1]]
  sent_id <- 1L
  rows <- vector("list", length(lines))
  j <- 0L
  pending_break <- FALSE
  for (line in lines) {
    if (!nzchar(line)) {
      if (j > 0L) pending_break <- TRUE
      next
    }
    if (pending_break) {
      sent_id <- sent_id + 1L
      pending_break <- FALSE
    }
    fields <- strsplit(line, "\t", fixed = TRUE)[[1]]
    if (length(fields) < length(cols)) {
      fields <- c(fields, rep(NA_character_, length(cols) - length(fields)))
    } else if (length(fields) > length(cols)) {
      fields <- fields[seq_along(cols)]
    }
    j <- j + 1L
    rows[[j]] <- c(sentence_id = sent_id, stats::setNames(fields, cols))
  }
  rows <- rows[seq_len(j)]
  if (!length(rows)) return(.empty_df(cols))
  df <- as.data.frame(do.call(rbind, rows), stringsAsFactors = FALSE)
  df$sentence_id <- as.integer(df$sentence_id)
  df
}

.empty_df <- function(cols) {
  out <- as.data.frame(
    matrix(character(0), nrow = 0, ncol = length(cols) + 1),
    stringsAsFactors = FALSE
  )
  names(out) <- c("sentence_id", cols)
  out$sentence_id <- integer(0)
  out
}

# Convert columns that should be integers.
.coerce_int <- function(df, cols) {
  for (cc in cols) {
    if (cc %in% names(df)) {
      df[[cc]] <- suppressWarnings(as.integer(df[[cc]]))
    }
  }
  df
}

# Prepare a single document for YAP\'s HTTP endpoint.
#
# YAP expects its input already tokenized: one token per line, with a trailing
# blank line to terminate the sentence. Passing a single space-separated
# sentence makes YAP silently return {} (no error, no log). We split on
# whitespace, drop empty tokens, and append the terminator.
.heb_tokenize_for_yap <- function(txt) {
  toks <- strsplit(as.character(txt), "\\s+", perl = TRUE)[[1]]
  toks <- toks[nzchar(toks)]
  if (!length(toks)) return("\n\n")
  paste0(paste(toks, collapse = "\n"), "\n\n")
}

# Default Hebrew content-word POS tags (YAP CPOSTAGs). Used by yap_to_dfm()
# when heb_lemma = TRUE. Kept as an internal constant so downstream code can
# override via the pos_keep argument.
.HEB_CONTENT_POS <- c("NN", "NNT", "NNP", "VB", "JJ", "RB")

# POSIX/Windows-safe file exists check
.is_file <- function(path) file.exists(path) && !dir.exists(path)

# Detect whether we're on Windows.
.is_windows <- function() .Platform$OS.type == "windows"
