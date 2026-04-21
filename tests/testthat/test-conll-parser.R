test_that(".parse_conll reads md_lattice with the expected columns", {
  df <- yappr:::.parse_conll(
    fixture_md_one_sentence,
    yappr:::.YAP_MD_COLS
  )
  expect_s3_class(df, "data.frame")
  expect_equal(
    names(df),
    c("sentence_id", yappr:::.YAP_MD_COLS)
  )
  expect_equal(nrow(df), 6)
  expect_equal(df$token[2], "ylDym")
  expect_equal(df$lemma[2], "ylD")
  expect_equal(unique(df$sentence_id), 1L)
})

test_that(".parse_conll splits sentences on blank lines", {
  df <- yappr:::.parse_conll(
    fixture_md_two_sentences,
    yappr:::.YAP_MD_COLS
  )
  expect_equal(sort(unique(df$sentence_id)), c(1L, 2L))
  expect_equal(sum(df$sentence_id == 1L), 6)
  expect_equal(sum(df$sentence_id == 2L), 3)
})

test_that(".parse_conll tolerates empty input", {
  df <- yappr:::.parse_conll("", yappr:::.YAP_MD_COLS)
  expect_s3_class(df, "data.frame")
  expect_equal(nrow(df), 0)
  expect_true("sentence_id" %in% names(df))
})

test_that(".coerce_int converts selected columns to integer", {
  df <- yappr:::.parse_conll(
    fixture_md_one_sentence,
    yappr:::.YAP_MD_COLS
  )
  df <- yappr:::.coerce_int(df, c("from", "to", "token_id"))
  expect_type(df$from, "integer")
  expect_type(df$to, "integer")
  expect_type(df$token_id, "integer")
  expect_type(df$lemma, "character")
})

test_that("dep_tree parsing returns correct head/deprel columns", {
  dep <- yappr:::.parse_conll(
    fixture_dep_one_sentence,
    yappr:::.YAP_DEP_COLS
  )
  dep <- yappr:::.coerce_int(dep, c("id", "head"))
  expect_equal(dep$deprel[3], "ROOT")
  expect_equal(dep$head[3], 0L)
  expect_equal(dep$head[2], 3L)
})
