# ETL (Extract, Transform, Load) process for compensation data

library(DBI)
library(dplyr)
library(tidyr)

#' Main ETL process orchestrator
#' @param source_file Source data file (CSV or database)
#' @return Status message
run_etl_process <- function(source_file = NULL) {
  tryCatch({
    cat("Starting ETL process...\n")
    
    # Extract
    cat("1. Extracting data...\n")
    raw_data <- extract_data(source_file)
    
    # Transform
    cat("2. Transforming data...\n")
    transformed_data <- transform_data(raw_data)
    
    # Validate
    cat("3. Validating data...\n")
    validation_result <- validate_data(transformed_data)
    
    if (!validation_result$valid) {
      warning("Data validation failed: ", paste(validation_result$errors, collapse = "; "))
    }
    
    # Load
    cat("4. Loading data to database...\n")
    load_data(transformed_data)
    
    cat("ETL process completed successfully\n")
    return(list(success = TRUE, message = "ETL completed"))
    
  }, error = function(e) {
    return(list(success = FALSE, message = paste("ETL failed:", e$message)))
  })
}

#' Extract data from source
#' @param source_file Source file path
#' @return Raw data frame
extract_data <- function(source_file = NULL) {
  if (is.null(source_file)) {
    source_file <- Sys.getenv("ETL_SOURCE_FILE", "data/compensation_raw.csv")
  }
  
  if (file.exists(source_file)) {
    return(read.csv(source_file, stringsAsFactors = FALSE))
  } else {
    # Return sample data
    return(get_sample_raw_data())
  }
}

#' Transform raw data
#' @param data Raw data frame
#' @return Transformed data frame
transform_data <- function(data) {
  data %>
    # Standardize column names
    rename_with(tolower) %>%
    # Clean whitespace (use base `trimws` to avoid extra stringr dependency)
    mutate(across(where(is.character), ~trimws(.x))) %>%
    # Convert numeric columns
    mutate(
      target_comp = as.numeric(gsub("[^0-9.]", "", target_comp)),
      actual_comp = as.numeric(gsub("[^0-9.]", "", actual_comp))
    ) %>%
    # Calculate derived columns
    mutate(
      variance = actual_comp - target_comp,
      variance_pct = (variance / target_comp) * 100,
      entry_date = Sys.Date()
    ) %>%
    # Remove duplicates
    distinct()
}

#' Validate transformed data
#' @param data Transformed data frame
#' @return Validation result list
validate_data <- function(data) {
  errors <- c()
  
  # Check required columns
  required_cols <- c("physician_id", "physician_name", "specialty", 
                    "target_comp", "actual_comp")
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    errors <- c(errors, paste("Missing columns:", paste(missing_cols, collapse = ", ")))
  }
  
  # Check for null values in key columns
  if (any(is.na(data$physician_id))) {
    errors <- c(errors, "physician_id contains NULL values")
  }
  
  # Check for negative values
  if (any(data$target_comp < 0, na.rm = TRUE) || 
      any(data$actual_comp < 0, na.rm = TRUE)) {
    errors <- c(errors, "Negative compensation values detected")
  }
  
  # Check data types
  if (!is.numeric(data$target_comp) || !is.numeric(data$actual_comp)) {
    errors <- c(errors, "Compensation columns must be numeric")
  }
  
  list(
    valid = length(errors) == 0,
    errors = errors,
    row_count = nrow(data)
  )
}

#' Load transformed data to database
#' @param data Transformed data frame
#' @return Load status
load_data <- function(data) {
  conn <- get_db_connection()
  
  if (is.null(conn)) {
    # Save to CSV as fallback
    output_file <- paste0("data/compensation_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv")
    write.csv(data, output_file, row.names = FALSE)
    cat("Data saved to", output_file, "\n")
    return(TRUE)
  }
  
  tryCatch({
    # Create or append to table
    dbWriteTable(conn, "compensation_data", data, 
                 overwrite = FALSE, append = TRUE)
    dbDisconnect(conn)
    return(TRUE)
  }, error = function(e) {
    warning("Failed to load data to database: ", e$message)
    return(FALSE)
  })
}

#' Get sample raw data for testing
#' @return Sample raw data frame
get_sample_raw_data <- function() {
  data.frame(
    physician_id = 1:10,
    physician_name = paste0("Dr. ", LETTERS[1:10]),
    specialty = rep(c("Cardiology", "Orthopedics"), 5),
    target_comp = c(350000, 400000, 350000, 400000, 350000,
                   400000, 350000, 400000, 350000, 400000),
    actual_comp = c(345000, 420000, 352000, 395000, 355000,
                   410000, 348000, 425000, 360000, 405000),
    stringsAsFactors = FALSE
  )
}
