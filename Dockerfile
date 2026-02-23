FROM rocker/shiny:latest

# Set maintainer
LABEL maintainer="comp-analytics@example.com"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libpq-dev \
    libssl-dev \
    libxml2-dev \
    libcurl4-openssl-dev \
    odbc-postgresql \
    unixodbc \
    unixodbc-dev \
    && rm -rf /var/lib/apt/lists/*

# Install R dependencies from CRAN
RUN install2.r --error \
    shiny \
    shinydashboard \
    DBI \
    RPostgres \
    odbc \
    dplyr \
    tidyr \
    ggplot2 \
    plotly \
    DT \
    data.table \
    rmarkdown \
    quarto \
    && rm -rf /tmp/downloaded_packages /tmp/*.rds

# Copy application files
COPY app.R /srv/shiny-server/
COPY R/ /srv/shiny-server/R/
COPY sql/ /srv/shiny-server/sql/
COPY reports/ /srv/shiny-server/reports/
COPY data/ /srv/shiny-server/data/
COPY tests/ /srv/shiny-server/tests/
COPY www/ /srv/shiny-server/www/

# Set working directory
WORKDIR /srv/shiny-server

# Expose Shiny port
EXPOSE 3838

# Set environment variables
ENV DB_DRIVER="ODBC Driver 17 for SQL Server"
ENV DB_SERVER="localhost"
ENV DB_NAME="compensation"
ENV DB_USER="sa"
ENV DB_PASSWORD=""
ENV DB_TRUSTED_CONN="no"
ENV USER_ROLE="viewer"

# Run Shiny application
CMD ["/usr/bin/shiny-server"]
