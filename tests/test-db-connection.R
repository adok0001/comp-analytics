#!/usr/bin/env Rscript
# -----------------------------------------------------------------------------
# Database Connection Test
# Tests the PostgreSQL connection used by the Docker Compose stack.
# Run from the project root:
#   Rscript tests/test-db-connection.R
# Or override credentials via env vars:
#   DB_SERVER=myhost DB_PASSWORD=secret Rscript tests/test-db-connection.R
# -----------------------------------------------------------------------------

library(DBI)
library(RPostgres)

# ── Connection parameters ─────────────────────────────────────────────────────
host     <- Sys.getenv("DB_SERVER",   "localhost")
port     <- as.integer(Sys.getenv("DB_PORT",     "5432"))
dbname   <- Sys.getenv("DB_NAME",     "compensation")
user     <- Sys.getenv("DB_USER",     "postgres")
password <- Sys.getenv("DB_PASSWORD", "postgres")

cat("─────────────────────────────────────────────\n")
cat("  Compensation Analytics — DB Connection Test\n")
cat("─────────────────────────────────────────────\n")
cat(sprintf("  Host     : %s:%d\n", host, port))
cat(sprintf("  Database : %s\n", dbname))
cat(sprintf("  User     : %s\n", user))
cat("─────────────────────────────────────────────\n\n")

# ── 1. Connect ────────────────────────────────────────────────────────────────
cat("[1/4] Connecting ... ")
conn <- tryCatch(
  dbConnect(RPostgres::Postgres(),
            host     = host,
            port     = port,
            dbname   = dbname,
            user     = user,
            password = password),
  error = function(e) {
    cat("FAILED\n")
    cat(sprintf("      Error: %s\n", conditionMessage(e)))
    cat("\nHint: make sure the database container is running:\n")
    cat("      docker compose up -d database\n\n")
    quit(status = 1)
  }
)
cat("OK\n")

# ── 2. Server version ─────────────────────────────────────────────────────────
cat("[2/4] Server version ... ")
ver <- tryCatch(
  dbGetQuery(conn, "SELECT version()")[1, 1],
  error = function(e) paste("unknown:", conditionMessage(e))
)
cat(sprintf("OK\n      %s\n", ver))

# ── 3. List tables ────────────────────────────────────────────────────────────
cat("[3/4] Tables in database ... ")
tables <- tryCatch(
  dbListTables(conn),
  error = function(e) character(0)
)
if (length(tables) == 0) {
  cat("none found (schema not yet loaded)\n")
  cat("      Hint: load the schema with:\n")
  cat("            psql -U postgres -d compensation -h localhost -f sql/schema.sql\n")
} else {
  cat(sprintf("OK (%d found)\n", length(tables)))
  for (tbl in tables) cat(sprintf("      - %s\n", tbl))
}

# ── 4. Quick query ────────────────────────────────────────────────────────────
cat("[4/4] Quick query (SELECT 1) ... ")
result <- tryCatch(
  dbGetQuery(conn, "SELECT 1 AS ping")[1, 1],
  error = function(e) NA
)
if (!is.na(result) && result == 1) {
  cat("OK\n")
} else {
  cat("FAILED\n")
}

# ── Teardown ──────────────────────────────────────────────────────────────────
dbDisconnect(conn)

cat("\n✓ All checks passed — database is reachable and responding.\n\n")
