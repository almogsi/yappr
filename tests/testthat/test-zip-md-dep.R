test_that(".zip_md_dep attaches head and deprel to md rows", {
  md  <- yappr:::.parse_conll(
    fixture_md_one_sentence, yappr:::.YAP_MD_COLS
  )
  md  <- yappr:::.coerce_int(md, c("from", "to", "token_id"))
  dep <- yappr:::.parse_conll(
    fixture_dep_one_sentence, yappr:::.YAP_DEP_COLS
  )
  dep <- yappr:::.coerce_int(dep, c("id", "head"))

  z <- yappr:::.zip_md_dep(md, dep)
  expect_true(all(c("head", "deprel") %in% names(z)))
  expect_equal(nrow(z), nrow(md))
  # The third morpheme should be the verbal ROOT.
  expect_equal(z$deprel[3], "ROOT")
  expect_equal(z$head[3], 0L)
})

test_that(".zip_md_dep handles length mismatch with a warning", {
  md <- yappr:::.parse_conll(
    fixture_md_one_sentence, yappr:::.YAP_MD_COLS
  )
  md <- yappr:::.coerce_int(md, c("from", "to", "token_id"))
  dep <- yappr:::.parse_conll(
    fixture_dep_one_sentence, yappr:::.YAP_DEP_COLS
  )
  dep <- yappr:::.coerce_int(dep, c("id", "head"))
  dep_short <- dep[1:3, , drop = FALSE]

  expect_warning(
    z <- yappr:::.zip_md_dep(md, dep_short),
    "md_lattice and dep_tree lengths differ"
  )
  expect_equal(sum(!is.na(z$head)), 3L)
})

test_that(".per_sentence_idx produces 1..n within each sentence", {
  sid <- c(1L, 1L, 1L, 2L, 2L, 3L)
  expect_equal(yappr:::.per_sentence_idx(sid),
               c(1L, 2L, 3L, 1L, 2L, 1L))
})
