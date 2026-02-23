.PHONY: help install build run stop clean docker-build docker-run docker-stop reports test

help:
	@echo "Compensation Analytics Dashboard - Build Targets"
	@echo ""
	@echo "Development:"
	@echo "  install        - Install R dependencies"
	@echo "  run            - Run Shiny app locally"
	@echo "  etl            - Run ETL process"
	@echo "  reports        - Generate Quarto reports"
	@echo ""
	@echo "Docker:"
	@echo "  docker-build   - Build Docker image"
	@echo "  docker-run     - Run Docker containers with docker-compose"
	@echo "  docker-stop    - Stop Docker containers"
	@echo ""
	@echo "Maintenance:"
	@echo "  clean          - Clean build artifacts"
	@echo "  test           - Run tests"

install:
	@echo "Installing R dependencies..."
	Rscript -e "options(repos = list(CRAN = 'http://cran.r-project.org')); install.packages('devtools'); devtools::install_local()"

run:
	@echo "Starting Shiny application on http://localhost:3838"
	Rscript -e "shiny::runApp('app.R', host = '0.0.0.0', port = 3838)"

etl:
	@echo "Running ETL process..."
	Rscript -e "source('R/etl.R'); run_etl_process()"

reports:
	@echo "Generating Quarto reports..."
	@mkdir -p reports/output
	quarto render reports/compensation_analysis.qmd --output-dir reports/output

docker-build:
	@echo "Building Docker image..."
	docker build -t compensation-analytics:latest .

docker-run:
	@echo "Starting Docker containers..."
	docker-compose up -d

docker-stop:
	@echo "Stopping Docker containers..."
	docker-compose down

docker-clean:
	@echo "Removing Docker containers and volumes..."
	docker-compose down -v

clean:
	@echo "Cleaning build artifacts..."
	@rm -rf reports/output
	@find . -name "*.Rdata" -delete
	@find . -name ".Rhistory" -delete

test:
	@echo "Running tests..."
	Rscript -e "testthat::test_dir('tests')"

.DEFAULT_GOAL := help
