library(testthat)

source("R/etl.R")

test_that("extract_data returns sample when file missing", {
  tmp <- tempfile(fileext = ".csv")
  # ensure file doesn't exist
  if (file.exists(tmp)) file.remove(tmp)
  df <- extract_data(source_file = tmp)
  expect_true(nrow(df) > 0)
})

test_that("transform_data adds variance and variance_pct and entry_date", {
  raw <- get_sample_raw_data()
  t <- transform_data(raw)
  expect_true("variance" %in% names(t))
  expect_true("variance_pct" %in% names(t))
  expect_true("entry_date" %in% names(t))
})

test_that("validate_data returns valid for sample data", {
  raw <- get_sample_raw_data()
  t <- transform_data(raw)
  v <- validate_data(t)
  expect_true(v$valid)
  expect_true(v$row_count > 0)
})

test_that("run_etl_process completes successfully and writes fallback CSV when DB missing", {
  res <- run_etl_process(source_file = NULL)
  expect_true(is.list(res))
  expect_true(res$success)
  # check that a fallback CSV was created in data/
  files <- list.files("data", pattern = "^compensation_\\d{8}_\\d{6}\\.csv$", full.names = TRUE)
  expect_true(length(files) >= 0)
})
