# Offline coverage for the new heb_lemma pipeline in yap_to_dfm(). We mock
# yap_parse() via testthat::local_mocked_bindings() so no server is required.

test_that("yap_to_dfm(heb_lemma = TRUE) keeps content POS and strips trailing punct", {
  skip_if_not_installed("quanteda")

  fake_parse <- data.frame(
    doc_id      = c("a","a","a","a","a", "b","b","b"),
    sentence_id = c(1,1,1,1,1, 1,1,1),
    token_id    = c(1,2,3,4,5, 1,2,3),
    token       = c("\u05D4","\u05D9\u05DC\u05D3","\u05D4\u05DC\u05DA","\u05DC","\u05D1\u05D9\u05EA",
                    "\u05D9\u05D5\u05DD","\u05D9\u05E4\u05D4.","\u05DE\u05D0\u05D5\u05D3"),
    lemma       = c("\u05D4","\u05D9\u05DC\u05D3","\u05D4\u05DC\u05DA","\u05DC","\u05D1\u05D9\u05EA",
                    "\u05D9\u05D5\u05DD","\u05D9\u05E4\u05D4.","\u05DE\u05D0\u05D5\u05D3"),
    pos         = c("DEF","NN","VB","PREPOSITION","NN", "NN","JJ","RB"),
    xpos        = c("DEF","NN","VB","PREPOSITION","NN", "NN","JJ","RB"),
    feats       = rep("_", 8),
    stringsAsFactors = FALSE
  )
  class(fake_parse) <- c("yap_parsed", "data.frame")

  local_mocked_bindings(
    yap_parse = function(text, ...) fake_parse,
    .package  = "yappr"
  )

  d <- yap_to_dfm(c(a = "x", b = "y"),
                  heb_lemma        = TRUE,
                  remove_stopwords = FALSE)
  expect_s3_class(d, "dfm")

  feats <- quanteda::featnames(d)
  # DEF ("\u05D4") and PREPOSITION ("\u05DC") must be dropped.
  expect_false("\u05D4" %in% feats)
  expect_false("\u05DC" %in% feats)
  # "\u05D9\u05E4\u05D4." must survive, with the trailing dot stripped.
  expect_true("\u05D9\u05E4\u05D4" %in% feats)
  expect_false("\u05D9\u05E4\u05D4." %in% feats)
})

test_that("regression: sentence-final lemma with trailing period is not dropped", {
  # This is the "\u05E1\u05E4\u05E8" case: YAP returns the lemma with "."
  # attached to the last morpheme. Previously we used tokens_replace with a
  # regex pattern, which quanteda matches against whole tokens -- so the entire
  # token got replaced by "" instead of just having the dot stripped.
  skip_if_not_installed("quanteda")

  fake_parse <- data.frame(
    doc_id      = rep("a", 3),
    sentence_id = rep(1L, 3),
    token_id    = 1:3,
    token       = c("\u05D9\u05DC\u05D3", "\u05D1\u05D9\u05EA", "\u05E1\u05E4\u05E8."),
    lemma       = c("\u05D9\u05DC\u05D3", "\u05D1\u05D9\u05EA", "\u05E1\u05E4\u05E8."),
    pos         = c("NN", "NNT", "NN"),
    xpos        = c("NN", "NNT", "NN"),
    feats       = rep("_", 3),
    stringsAsFactors = FALSE
  )
  class(fake_parse) <- c("yap_parsed", "data.frame")
  local_mocked_bindings(
    yap_parse = function(text, ...) fake_parse,
    .package  = "yappr"
  )

  d <- yap_to_dfm("ignored", heb_lemma = TRUE, remove_stopwords = FALSE)
  feats <- quanteda::featnames(d)
  expect_true("\u05E1\u05E4\u05E8" %in% feats)
  expect_false("\u05E1\u05E4\u05E8." %in% feats)
})
