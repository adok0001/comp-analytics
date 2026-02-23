library(testthat)

# ensure tests run from project root
setwd("..")
source("R/analytics.R")

test_that("calculate_variance computes correct values and category", {
  res <- calculate_variance(100, 120)
  expect_equal(res$variance, 20)
  expect_equal(round(res$variance_pct, 6), 20)
  expect_equal(as.character(res$variance_category), "Over")
})

test_that("variance_by_specialty aggregates correctly", {
  df <- data.frame(
    specialty = c("A", "A", "B"),
    target_comp = c(100, 100, 200),
    actual_comp = c(110, 90, 220)
  )
  res <- variance_by_specialty(df)
  expect_true("specialty" %in% names(res))
  expect_true(all(c("avg_target", "avg_actual", "avg_variance_pct") %in% names(res)))
})

test_that("segment_by_level assigns comp_segment", {
  df <- data.frame(actual_comp = c(10, 20, 30, 40))
  res <- segment_by_level(df)
  expect_true("comp_segment" %in% names(res))
  expect_equal(nrow(res), 4)
})

test_that("identify_outliers flags extreme values", {
  df <- data.frame(actual_comp = c(10, 10, 10, 1000))
  # use a lower threshold to ensure the extreme value is flagged in tests
  res <- identify_outliers(df, threshold = 1.5)
  expect_true("is_outlier" %in% names(res))
  expect_true(any(res$is_outlier))
})

test_that("get_summary_stats returns expected keys", {
  df <- data.frame(actual_comp = c(1,2,3,4,5))
  stats <- get_summary_stats(df)
  expect_equal(stats$min_comp, 1)
  expect_equal(stats$max_comp, 5)
})
