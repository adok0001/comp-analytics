# Compensation Analytics Dashboard
# Production Shiny application with role-based authentication

library(shiny)
library(shinydashboard)
library(DBI)
library(dplyr)
library(ggplot2)
library(plotly)
library(DT)

# Source helper functions
source("R/auth.R")
source("R/database.R")
source("R/analytics.R")

ui <- dashboardPage(
  dashboardHeader(
    title = "Compensation Analytics",
    dropdownMenu(
      type = "messages",
      messageItem(
        from = "User",
        message = "Welcome to Comp Analytics"
      )
    )
  ),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Dashboard", tabName = "dashboard", icon = icon("dashboard")),
      menuItem("Variance Analysis", tabName = "variance", icon = icon("chart-bar")),
      menuItem("Reports", tabName = "reports", icon = icon("file")),
      menuItem("Admin", tabName = "admin", icon = icon("cog"))
    ),
    tags$div(
      style = "position:absolute; bottom:12px; left:0; right:0; padding:0 15px;",
      uiOutput("dbStatusBadge")
    )
  ),
  dashboardBody(
    tabItems(
      # Dashboard Tab
      tabItem(
        tabName = "dashboard",
        h2("Compensation Dashboard"),
        fluidRow(
          valueBox(value = 0, subtitle = "Total Physicians", icon = icon("user-md")),
          valueBox(value = "$0", subtitle = "Total Compensation", icon = icon("dollar-sign")),
          valueBox(value = "0%", subtitle = "Target Achievement", icon = icon("bullseye"))
        ),
        fluidRow(
          box(
            plotlyOutput("compPlot"),
            width = 6,
            title = "Compensation by Specialty"
          ),
          box(
            plotlyOutput("trendPlot"),
            width = 6,
            title = "Compensation Trend"
          )
        )
      ),
      # Variance Analysis Tab
      tabItem(
        tabName = "variance",
        h2("Variance Analysis"),
        fluidRow(
          column(
            width = 12,
            box(
              DTOutput("varianceTable"),
              width = 12,
              title = "Variance Summary"
            )
          )
        )
      ),
      # Reports Tab
      tabItem(
        tabName = "reports",
        h2("Generate Reports"),
        fluidRow(
          column(
            width = 6,
            box(
              selectInput("reportType", "Select Report Type:", 
                          c("Executive Summary", "Detailed Analysis", "Trends")),
              dateRangeInput("reportDates", "Date Range:"),
              downloadButton("downloadReport", "Generate Report"),
              width = 12
            )
          )
        )
      ),
      # Admin Tab
      tabItem(
        tabName = "admin",
        h2("Administration"),
        fluidRow(
          # Database connector
          column(
            width = 6,
            box(
              title = tagList(icon("database"), " Database Connection"),
              status = "primary", solidHeader = TRUE, width = 12,
              selectInput("dbDriver",  "Driver",
                choices = c("PostgreSQL Unicode", "ODBC Driver 17 for SQL Server", "ODBC Driver 18 for SQL Server"),
                selected = Sys.getenv("DB_DRIVER", "PostgreSQL Unicode")
              ),
              textInput("dbServer",   "Server / Host",
                value = Sys.getenv("DB_SERVER", "localhost")),
              textInput("dbName",     "Database Name",
                value = Sys.getenv("DB_NAME",   "compensation")),
              textInput("dbUser",     "Username",
                value = Sys.getenv("DB_USER",   "")),
              passwordInput("dbPassword", "Password",
                value = Sys.getenv("DB_PASSWORD", "")),
              selectInput("dbTrusted", "Trusted Connection",
                choices = c("no", "yes"),
                selected = Sys.getenv("DB_TRUSTED_CONN", "no")
              ),
              tags$div(
                style = "display:flex; gap:8px; margin-top:8px;",
                actionButton("testDbConn",  "Test Connection",
                  icon = icon("plug"),  class = "btn-info"),
                actionButton("saveDbConn",  "Save & Connect",
                  icon = icon("save"),  class = "btn-success")
              ),
              tags$div(style = "margin-top:12px;", uiOutput("dbTestResult"))
            )
          ),
          # Data actions
          column(
            width = 6,
            box(
              title = tagList(icon("cog"), " Data Actions"),
              status = "warning", solidHeader = TRUE, width = 12,
              tags$p("Reload compensation data from the configured database."),
              actionButton("refreshData", "Refresh Data from Database",
                icon = icon("sync"), class = "btn-primary"),
              tags$hr(),
              tags$p("Run the full ETL pipeline to ingest the latest source files."),
              actionButton("runETL", "Run ETL Process",
                icon = icon("play"), class = "btn-warning")
            )
          )
        )
      )
    )
  )
)

server <- function(input, output, session) {

  # Show welcome modal on startup
  showModal(modalDialog(
    title = tags$div(
      icon("chart-line"), " Welcome to Compensation Analytics"
    ),
    tags$div(
      tags$p("This dashboard provides interactive physician compensation analysis. Here's a quick guide to get started:"),
      tags$hr(),
      tags$h5(icon("dashboard"), " Dashboard"),
      tags$p("View summary KPIs and interactive charts showing average compensation by specialty and compensation trends over time."),
      tags$h5(icon("chart-bar"), " Variance Analysis"),
      tags$p("Explore detailed physician-level variance between target and actual compensation. Sort and filter the table to identify outliers."),
      tags$h5(icon("file"), " Reports"),
      tags$p("Generate a downloadable HTML report. Select a report type and date range, then click ", tags$strong("Generate Report"), " to download."),
      tags$h5(icon("cog"), " Admin"),
      tags$p("Refresh the compensation data from the database or trigger the ETL pipeline to ingest the latest source files."),
      tags$hr(),
      tags$p(tags$em("The app runs on sample data when no database connection is configured."),
             style = "color: #888; font-size: 0.9em;")
    ),
    easyClose = TRUE,
    footer = modalButton("Get Started")
  ))

  # --- Database connection state ---
  db_connected <- reactiveVal(FALSE)

  # Test whether a connection can be made with current inputs
  test_connection <- function(driver, server, name, user, pwd, trusted) {
    tryCatch({
      conn <- DBI::dbConnect(
        odbc::odbc(),
        Driver             = driver,
        Server             = server,
        Database           = name,
        UID                = user,
        PWD                = pwd,
        Trusted_Connection = trusted
      )
      DBI::dbDisconnect(conn)
      TRUE
    }, error = function(e) conditionMessage(e))
  }

  # Test Connection button
  observeEvent(input$testDbConn, {
    result <- test_connection(
      input$dbDriver, input$dbServer, input$dbName,
      input$dbUser,   input$dbPassword, input$dbTrusted
    )
    if (isTRUE(result)) {
      output$dbTestResult <- renderUI(
        tags$span(icon("check-circle"), " Connection successful",
          style = "color:#27ae60; font-weight:bold;")
      )
    } else {
      output$dbTestResult <- renderUI(
        tags$span(icon("times-circle"), paste(" Failed:", result),
          style = "color:#e74c3c; font-weight:bold;")
      )
    }
  })

  # Save & Connect button — update env vars then reload data
  observeEvent(input$saveDbConn, {
    Sys.setenv(
      DB_DRIVER     = input$dbDriver,
      DB_SERVER     = input$dbServer,
      DB_NAME       = input$dbName,
      DB_USER       = input$dbUser,
      DB_PASSWORD   = input$dbPassword,
      DB_TRUSTED_CONN = input$dbTrusted
    )
    result <- test_connection(
      input$dbDriver, input$dbServer, input$dbName,
      input$dbUser,   input$dbPassword, input$dbTrusted
    )
    if (isTRUE(result)) {
      db_connected(TRUE)
      output$dbTestResult <- renderUI(
        tags$span(icon("check-circle"), " Saved and connected",
          style = "color:#27ae60; font-weight:bold;")
      )
      tryCatch({
        data <- get_compensation_summary()
        comp_data(data)
        showNotification("Connected — data reloaded from database.", type = "message")
      }, error = function(e) {
        showNotification(paste("Data reload error:", e$message), type = "error")
      })
    } else {
      db_connected(FALSE)
      output$dbTestResult <- renderUI(
        tags$span(icon("times-circle"), paste(" Could not connect:", result),
          style = "color:#e74c3c; font-weight:bold;")
      )
      showNotification(paste("Connection failed:", result), type = "error")
    }
  })

  # Sidebar connection status badge
  output$dbStatusBadge <- renderUI({
    if (db_connected()) {
      tags$div(
        style = "background:#27ae60; color:#fff; border-radius:4px; padding:6px 10px; font-size:0.85em; text-align:center;",
        icon("circle"), " DB Connected"
      )
    } else {
      tags$div(
        style = "background:#7f8c8d; color:#fff; border-radius:4px; padding:6px 10px; font-size:0.85em; text-align:center;",
        icon("circle"), " Using Sample Data"
      )
    }
  })

  # Reactive data
  comp_data <- reactiveVal(data.frame())
  
  # Load initial data
  observeEvent(TRUE, {
    tryCatch({
      data <- get_compensation_summary()
      comp_data(data)
    }, error = function(e) {
      showNotification(paste("Error loading data:", e$message), type = "error")
    })
  }, once = TRUE)
  
  # Output renderers
  output$compPlot <- renderPlotly({
    plot_data <- comp_data() %>%
      group_by(specialty) %>%
      summarise(avg_compensation = mean(actual_comp, na.rm = TRUE), .groups = "drop")
    plot_ly(plot_data, x = ~specialty, y = ~avg_compensation,
            type = 'bar', marker = list(color = 'rgba(55, 128, 191, 0.7)')) %>%
      layout(title = "Average Compensation by Specialty",
             xaxis = list(title = "Specialty"),
             yaxis = list(title = "Compensation ($)"))
  })
  
  output$trendPlot <- renderPlotly({
    plot_ly(comp_data(), x = ~date, y = ~compensation,
            type = 'scatter', mode = 'lines') %>%
      layout(title = "Compensation Trend",
             xaxis = list(title = "Date"),
             yaxis = list(title = "Compensation ($)"))
  })
  
  output$varianceTable <- renderDT({
    comp_data() %>%
      select(
        physician_name, specialty, role, location, employment_type,
        service_period, hours_worked,
        target_comp, actual_comp, variance, variance_pct
      ) %>%
      datatable(
        colnames = c(
          "Physician", "Specialty", "Role", "Location", "Employment Type",
          "Service Period", "Hours Worked",
          "Target ($)", "Actual ($)", "Variance ($)", "Variance (%)"
        ),
        options = list(pageLength = 10, scrollX = TRUE),
        filter = "top"
      ) %>%
      formatCurrency(c("target_comp", "actual_comp", "variance"), currency = "$", digits = 0) %>%
      formatRound("variance_pct", digits = 1) %>%
      formatStyle(
        "variance",
        color = styleInterval(0, c("#e74c3c", "#27ae60"))
      )
  })
  
  # Report generation
  output$downloadReport <- downloadHandler(
    filename = function() {
      paste0("compensation_report_", Sys.Date(), "_",
             gsub(" ", "_", input$reportType), ".html")
    },
    content = function(file) {
      id <- showNotification("Generating report, please wait...", type = "message", duration = NULL)
      on.exit(removeNotification(id), add = TRUE)
      tryCatch({
        params <- list(
          report_type = input$reportType,
          start_date  = input$reportDates[1],
          end_date    = input$reportDates[2]
        )
        rmarkdown::render(
          input       = "reports/compensation_analysis.qmd",
          output_format = rmarkdown::html_document(
            self_contained = TRUE,
            toc            = TRUE,
            number_sections = TRUE
          ),
          output_file = file,
          params      = params,
          envir       = new.env(parent = globalenv())
        )
      }, error = function(e) {
        showNotification(paste("Report error:", e$message), type = "error")
      })
    }
  )

  # Reactive handlers
  observeEvent(input$refreshData, {
    showNotification("Refreshing data...", type = "message")
    tryCatch({
      data <- refresh_data_from_db()
      comp_data(data)
      showNotification("Data refreshed successfully", type = "message")
    }, error = function(e) {
      showNotification(paste("Error:", e$message), type = "error")
    })
  })
  
  observeEvent(input$runETL, {
    showNotification("Running ETL process...", type = "message")
    tryCatch({
      run_etl_process()
      showNotification("ETL completed successfully", type = "message")
    }, error = function(e) {
      showNotification(paste("Error:", e$message), type = "error")
    })
  })
}

shinyApp(ui, server)
