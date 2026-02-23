library(testthat)

source("R/auth.R")
source("R/database.R")

test_that("check_permission enforces roles correctly", {
  expect_true(check_permission("admin", "admin_settings"))
  expect_true(check_permission("analyst", "run_etl"))
  expect_false(check_permission("viewer", "run_etl"))
  expect_false(check_permission("unknown", "view"))
})

test_that("authenticate_user validates inputs", {
  res <- authenticate_user("", "")
  expect_false(res$success)
  res2 <- authenticate_user("bob", "secret")
  expect_true(res2$success)
  expect_equal(res2$role, "viewer")
})

test_that("get_compensation_summary returns sample when DB missing", {
  s <- get_compensation_summary()
  expect_true(is.data.frame(s))
  expect_true(nrow(s) > 0)
})
