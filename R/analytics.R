# Analytics functions for compensation analysis

library(dplyr)
library(ggplot2)
library(tidyr)

#' Calculate variance between target and actual compensation
#' @param target_comp Target compensation value
#' @param actual_comp Actual compensation value
#' @return Data frame with variance analysis
calculate_variance <- function(target_comp, actual_comp) {
  data.frame(
    variance = actual_comp - target_comp,
    variance_pct = ((actual_comp - target_comp) / target_comp) * 100,
    variance_category = ifelse(actual_comp > target_comp, "Over", "Under")
  )
}

#' Perform variance analysis by specialty
#' @param data Compensation data frame
#' @return Variance analysis by specialty
variance_by_specialty <- function(data) {
  data %>%
    group_by(specialty) %>%
    summarise(
      count = n(),
      avg_target = mean(target_comp, na.rm = TRUE),
      avg_actual = mean(actual_comp, na.rm = TRUE),
      avg_variance = mean(actual_comp - target_comp, na.rm = TRUE),
      avg_variance_pct = (avg_actual - avg_target) / avg_target * 100,
      .groups = "drop"
    ) %>%
    arrange(desc(abs(avg_variance_pct)))
}

#' Segment physicians by compensation level
#' @param data Compensation data frame
#' @return Data with compensation segments
segment_by_level <- function(data) {
  data %>%
    mutate(
      comp_segment = cut(
        actual_comp,
        breaks = quantile(actual_comp, probs = c(0, 0.25, 0.5, 0.75, 1)),
        labels = c("Bottom 25%", "25-50%", "50-75%", "Top 25%"),
        include.lowest = TRUE
      )
    )
}

#' Calculate performance metrics
#' @param data Compensation data frame
#' @return Performance metrics
calculate_metrics <- function(data) {
  total_physicians <- nrow(data)
  over_target <- sum(data$actual_comp > data$target_comp, na.rm = TRUE)
  under_target <- total_physicians - over_target
  avg_variance_pct <- mean(abs(data$variance_pct), na.rm = TRUE)
  
  list(
    total_physicians = total_physicians,
    over_target = over_target,
    under_target = under_target,
    pct_over_target = (over_target / total_physicians) * 100,
    avg_variance_pct = avg_variance_pct,
    total_compensation = sum(data$actual_comp, na.rm = TRUE),
    avg_compensation = mean(data$actual_comp, na.rm = TRUE)
  )
}

#' Generate compensation trend analysis
#' @param data Data frame with date and compensation
#' @return Trend analysis
analyze_trends <- function(data) {
  if (!"date" %in% names(data)) {
    return(NULL)
  }
  
  data %>%
    group_by(date) %>%
    summarise(
      avg_comp = mean(compensation, na.rm = TRUE),
      median_comp = median(compensation, na.rm = TRUE),
      count = n(),
      .groups = "drop"
    ) %>%
    arrange(date)
}

#' Identify outliers in compensation data
#' @param data Compensation data frame
#' @param threshold Standard deviations for outlier detection (default: 2)
#' @return Data frame with outlier flag
identify_outliers <- function(data, threshold = 2) {
  mean_val <- mean(data$actual_comp, na.rm = TRUE)
  sd_val <- sd(data$actual_comp, na.rm = TRUE)
  if (is.na(sd_val) || sd_val == 0) {
    data$z_score <- 0
    data$is_outlier <- FALSE
    return(data)
  }
  data %>%
    mutate(
      z_score = (actual_comp - mean_val) / sd_val,
      is_outlier = abs(z_score) > threshold
    )
}

#' Generate summary statistics
#' @param data Compensation data frame
#' @return Summary statistics
get_summary_stats <- function(data) {
  list(
    min_comp = min(data$actual_comp, na.rm = TRUE),
    max_comp = max(data$actual_comp, na.rm = TRUE),
    mean_comp = mean(data$actual_comp, na.rm = TRUE),
    median_comp = median(data$actual_comp, na.rm = TRUE),
    sd_comp = sd(data$actual_comp, na.rm = TRUE),
    q1_comp = quantile(data$actual_comp, 0.25, na.rm = TRUE),
    q3_comp = quantile(data$actual_comp, 0.75, na.rm = TRUE)
  )
}
