# zzz.R
# Package load/unload hooks for yappr.
#
# We register the quanteda::as.tokens S3 method at runtime instead of in the
# NAMESPACE via S3method(quanteda::as.tokens, yap_parsed). The runtime path
# (a) avoids R CMD check grumbling when quanteda is Suggests but not
# installed, and (b) side-steps a warning that older R versions emit about
# methods "declared but not found".

.onLoad <- function(libname, pkgname) {
  if (requireNamespace("quanteda", quietly = TRUE)) {
    registerS3method("as.tokens", "yap_parsed",
                     method = as.tokens.yap_parsed,
                     envir  = asNamespace("quanteda"))
  }
  invisible()
}
