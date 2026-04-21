test_that(".normalize_input handles named and unnamed character vectors", {
  out1 <- yappr:::.normalize_input(c("a", "b"))
  expect_named(out1, c("text1", "text2"))

  out2 <- yappr:::.normalize_input(c(x = "a", y = "b"))
  expect_named(out2, c("x", "y"))
})

test_that(".normalize_input accepts a doc_id/text data.frame", {
  df <- data.frame(doc_id = c("one", "two"),
                   text   = c("aa", "bb"),
                   stringsAsFactors = FALSE)
  out <- yappr:::.normalize_input(df)
  expect_named(out, c("one", "two"))
  expect_equal(unname(out), c("aa", "bb"))
})

test_that(".normalize_input rejects bad input", {
  expect_error(yappr:::.normalize_input(1:3),
               "must be a character vector")
})

test_that(".resolve_url prefers explicit url, then stored, then default", {
  old <- yappr:::.yappr$base_url
  on.exit(yappr:::.yappr$base_url <- old)

  yappr:::.yappr$base_url <- NULL
  expect_equal(yappr:::.resolve_url(NULL), "http://localhost:8000")

  yappr:::.yappr$base_url <- "http://localhost:9999"
  expect_equal(yappr:::.resolve_url(NULL), "http://localhost:9999")

  expect_equal(yappr:::.resolve_url("http://other:1234"),
               "http://other:1234")
})
