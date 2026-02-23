library(testthat)

test_that("data file exists and loads", {
  expect_true(file.exists("data/compensation_raw.csv"))
  df <- read.csv("data/compensation_raw.csv")
  expect_true(nrow(df) > 0)
})
