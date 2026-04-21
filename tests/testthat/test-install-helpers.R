# Unit tests for the install-side helpers that we can exercise without a
# network or a real YAP checkout.

test_that(".detect_lfs_pointers flags files whose content is a pointer stub", {
  tmp <- tempfile("lfs-"); dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  # A realistic LFS pointer stub: short, starts with "version https://git-lfs".
  pointer <- paste(
    "version https://git-lfs.github.com/spec/v1",
    "oid sha256:1111111111111111111111111111111111111111111111111111111111111111",
    "size 123456",
    sep = "\n"
  )
  writeLines(pointer, file.path(tmp, "model.bin"))
  # A non-pointer file: small but starts with something else.
  writeLines("hello world", file.path(tmp, "notes.txt"))
  # A large file (above the 200-byte size filter) even if it starts with the
  # LFS marker should NOT be flagged, because our filter size-gates first.
  writeLines(paste(rep("x", 500), collapse = ""),
             file.path(tmp, "big.bin"))

  bad <- yappr:::.detect_lfs_pointers(tmp)
  expect_length(bad, 1)
  expect_true(endsWith(bad, "model.bin"))
})

test_that(".detect_lfs_pointers returns character(0) for a clean directory", {
  tmp <- tempfile("clean-"); dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  writeLines("arbitrary content", file.path(tmp, "a.txt"))
  expect_equal(yappr:::.detect_lfs_pointers(tmp), character(0))
})

test_that("yap_doctor runs without erroring and reports a structured result", {
  # We don't assert on the tool availability (depends on the test env); we
  # just check that the function returns a well-formed result.
  res <- yap_doctor(dest = tempfile("yap-check-"))
  expect_type(res, "list")
  for (f in c("git", "git_lfs", "go", "issues")) {
    expect_true(f %in% names(res))
  }
  expect_type(res$issues, "character")
})
