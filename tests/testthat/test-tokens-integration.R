test_that("as.tokens.yap_parsed produces one element per doc_id", {
  skip_if_not_installed("quanteda")

  parsed <- data.frame(
    doc_id      = rep(c("a", "b"), c(3, 2)),
    sentence_id = c(1, 1, 1, 1, 1),
    token_id    = c(1, 2, 3, 1, 2),
    token       = c("ha", "yeled", "halak", "yom", "yafe"),
    lemma       = c("ha", "yeled", "halak", "yom", "yafe"),
    pos         = c("DEF", "NN", "VB", "NN", "JJ"),
    xpos        = c("DEF", "NN", "VB", "NN", "JJ"),
    feats       = "_",
    stringsAsFactors = FALSE
  )
  class(parsed) <- c("yap_parsed", "data.frame")

  toks <- quanteda::as.tokens(parsed, use_lemma = TRUE)
  expect_s3_class(toks, "tokens")
  expect_equal(length(toks), 2L)
  expect_equal(names(toks), c("a", "b"))
  expect_equal(as.character(toks[[1]]), c("ha", "yeled", "halak"))
})

test_that("as.tokens.yap_parsed remove_punct drops yy* POS tags", {
  skip_if_not_installed("quanteda")

  parsed <- data.frame(
    doc_id      = "a",
    sentence_id = 1L,
    token_id    = 1:4,
    token       = c("halak", "yom", "yafe", "."),
    lemma       = c("halak", "yom", "yafe", "."),
    pos         = c("VB", "NN", "JJ", "yyDOT"),
    xpos        = c("VB", "NN", "JJ", "yyDOT"),
    feats       = "_",
    stringsAsFactors = FALSE
  )
  class(parsed) <- c("yap_parsed", "data.frame")

  toks <- quanteda::as.tokens(parsed, use_lemma = TRUE, remove_punct = TRUE)
  expect_equal(as.character(toks[[1]]), c("halak", "yom", "yafe"))
})

test_that("pos_keep filters to requested POS tags only", {
  skip_if_not_installed("quanteda")

  parsed <- data.frame(
    doc_id      = "a",
    sentence_id = 1L,
    token_id    = 1:4,
    token       = c("halak", "yom", "yafe", "."),
    lemma       = c("halak", "yom", "yafe", "."),
    pos         = c("VB", "NN", "JJ", "yyDOT"),
    xpos        = c("VB", "NN", "JJ", "yyDOT"),
    feats       = "_",
    stringsAsFactors = FALSE
  )
  class(parsed) <- c("yap_parsed", "data.frame")

  toks <- quanteda::as.tokens(parsed, use_lemma = FALSE, pos_keep = "NN")
  expect_equal(as.character(toks[[1]]), "yom")
})
