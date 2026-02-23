# Database connection and query functions

library(DBI)
library(odbc)
library(dplyr)

#' Get database connection
#' @return Database connection object
get_db_connection <- function() {
  tryCatch({
    # Try to connect to SQL Server or PostgreSQL
    # Adjust connection parameters based on your database
    conn <- dbConnect(
      odbc::odbc(),
      Driver = Sys.getenv("DB_DRIVER", "ODBC Driver 17 for SQL Server"),
      Server = Sys.getenv("DB_SERVER", "localhost"),
      Database = Sys.getenv("DB_NAME", "compensation"),
      UID = Sys.getenv("DB_USER", "sa"),
      PWD = Sys.getenv("DB_PASSWORD", ""),
      Trusted_Connection = Sys.getenv("DB_TRUSTED_CONN", "no")
    )
    return(conn)
  }, error = function(e) {
    warning("Database connection failed. Using sample data.")
    return(NULL)
  })
}

#' Get compensation summary
#' @return Data frame with compensation data
get_compensation_summary <- function() {
  conn <- get_db_connection()
  
  if (is.null(conn)) {
    # Return sample data if connection fails
    return(get_sample_data())
  }
  
  tryCatch({
    query <- readLines("sql/compensation_summary.sql")
    query <- paste(query, collapse = "\n")
    result <- dbGetQuery(conn, query)
    dbDisconnect(conn)
    return(result)
  }, error = function(e) {
    warning("Query failed: ", e$message)
    return(get_sample_data())
  })
}

#' Refresh data from database
#' @return Updated compensation data
refresh_data_from_db <- function() {
  # Clear cache and reload from database
  get_compensation_summary()
}

#' Get sample data for testing
#' @return Data frame with sample compensation data
get_sample_data <- function() {
  data.frame(
    physician_id = 1:15,
    physician_name = paste0("Dr. ", LETTERS[1:15]),
    specialty = rep(c("Cardiology", "Orthopedics", "Oncology", "Neurology", "Pediatrics"), 3),
    target_comp = rep(c(350000, 400000, 380000, 370000, 320000), 3),
    actual_comp = rep(c(345000, 420000, 375000, 360000, 330000), 3),
    variance = rep(c(-5000, 20000, -5000, -10000, 10000), 3),
    variance_pct = rep(c(-1.4, 5.0, -1.3, -2.7, 3.1), 3),
    date = rep(seq.Date(Sys.Date() - 365, Sys.Date(), by = "month")[1:3], 5),
    compensation = rep(c(340000, 345000, 348000), 5)
  )
}

#' Execute custom SQL query
#' @param query SQL query string
#' @return Query results
execute_query <- function(query) {
  conn <- get_db_connection()
  
  if (is.null(conn)) {
    warning("No database connection available")
    return(data.frame())
  }
  
  tryCatch({
    result <- dbGetQuery(conn, query)
    dbDisconnect(conn)
    return(result)
  }, error = function(e) {
    warning("Query failed: ", e$message)
    return(data.frame())
  })
}

#' Load database schema information
#' @return List of tables and columns
load_schema <- function() {
  conn <- get_db_connection()
  
  if (is.null(conn)) {
    return(NULL)
  }
  
  tables <- dbListTables(conn)
  dbDisconnect(conn)
  
  return(tables)
}
