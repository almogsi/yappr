test_that("yap_ping returns FALSE when no server is listening", {
  # Very short timeout so the test is fast even if something unexpected is on
  # the port. We use a random high port unlikely to host a YAP instance.
  expect_false(yap_ping("http://127.0.0.1:57391", timeout = 1))
})

test_that("yap_available wraps yap_ping", {
  expect_false(yap_available("http://127.0.0.1:57391"))
})
