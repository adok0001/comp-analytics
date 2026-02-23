# Compensation Analytics Dashboard

A production-ready Shiny dashboard for physician compensation analysis. Supports role-based access, automated ETL, parameterized HTML reports, variance analysis, and Docker deployment with PostgreSQL.

---

## Features

- **Interactive Dashboard** — Specialty-level compensation bar chart and monthly trend line via Plotly
- **Variance Analysis Table** — Filterable, sortable DT table with physician-level details including role, location, employment type, service period, hours worked, and color-coded variance
- **Downloadable Reports** — Parameterized Quarto/R Markdown HTML reports (Executive Summary, Detailed Analysis, Trends) with date range and type selection
- **Database Connector UI** — Admin panel to configure, test, and save DB credentials at runtime with live connection status in the sidebar
- **ETL Pipeline** — Extract from CSV, transform (including service period parsing and derived fields), validate, and load to PostgreSQL or fallback CSV
- **Role-Based Access Control** — Admin, analyst, and viewer roles defined in `R/auth.R`
- **Graceful Fallback** — App runs on built-in sample data when no database is reachable
- **Docker Deployment** — Single `docker compose up` spins up the Shiny app + PostgreSQL

---

## Project Structure

```
comp-analytics/
├── app.R                          # Main Shiny application
├── R/
│   ├── auth.R                    # RBAC: roles, permissions, authenticate_user()
│   ├── database.R                # DB connection, get_compensation_summary(), sample data
│   ├── analytics.R               # Variance, metrics, trend, outlier functions
│   └── etl.R                     # ETL orchestration: extract, transform, validate, load
├── sql/
│   ├── schema.sql                # PostgreSQL schema (physicians + compensation tables)
│   ├── compensation_summary.sql  # Summary query with role, location, hours, hourly rate
│   └── variance_analysis.sql     # Specialty/location/role variance aggregation
├── reports/
│   └── compensation_analysis.qmd # Parameterized Quarto report template
├── data/
│   └── compensation_raw.csv      # ETL seed file (15 physicians, full field set)
├── tests/
│   ├── test-basic.R
│   ├── test-analytics.R
│   ├── test-auth-db.R
│   ├── test-etl.R
│   └── test-db-connection.R      # Standalone 4-step DB connectivity test
├── www/                          # Static assets
├── Dockerfile                    # rocker/shiny base + R package installs
├── docker-compose.yml            # App (port 3838) + PostgreSQL 15 (port 5432)
├── Makefile                      # Build targets: run, etl, reports, docker-*
├── DESCRIPTION                   # R package metadata and dependencies
└── .env.example                  # Environment variable reference
```

---

## Data Model

### `physicians`
| Column | Type | Notes |
|---|---|---|
| `physician_id` | INT PK | |
| `physician_name` | VARCHAR(255) | |
| `specialty` | VARCHAR(100) | |
| `department` | VARCHAR(100) | |
| `role` | VARCHAR(100) | Attending, Fellow, Resident, NP, PA, Locum |
| `location` | VARCHAR(255) | Facility / site |
| `employment_type` | VARCHAR(50) | Full-time, Part-time, Contract, Locum Tenens |
| `hire_date` | DATE | |
| `status` | VARCHAR(20) | Default: Active |

### `compensation`
| Column | Type | Notes |
|---|---|---|
| `comp_id` | SERIAL PK | |
| `physician_id` | INT FK | |
| `service_period` | DATE | First day of service month (e.g. 2025-01-01) |
| `reporting_period` | DATE | |
| `target_compensation` | DECIMAL(15,2) | |
| `actual_compensation` | DECIMAL(15,2) | |
| `variance_amount` | DECIMAL(15,2) | |
| `variance_percent` | DECIMAL(10,4) | |
| `hours_worked` | DECIMAL(8,2) | |
| `hourly_rate` | DECIMAL(10,2) | Generated: `actual_compensation / hours_worked` |
| `rvu_production` | DECIMAL(12,2) | |
| `bonus` | DECIMAL(15,2) | |
| `benefits_value` | DECIMAL(15,2) | |

---

## Quick Start

### Docker (Recommended)

```bash
# Start app + database
docker compose up -d

# App: http://localhost:3838
# PostgreSQL: localhost:5432
```

```bash
# Stop
docker compose down
```

### Load Database Schema

```bash
psql -U postgres -d compensation -h localhost -f sql/schema.sql
```

### Test Database Connection

```bash
docker exec comp-analytics-app-1 Rscript tests/test-db-connection.R
```

Override credentials via env vars:
```bash
DB_SERVER=myhost DB_PASSWORD=secret Rscript tests/test-db-connection.R
```

### Local Development (requires R 4.0+)

```bash
make install   # Install R dependencies
make run       # Run at http://localhost:3838
make etl       # Run ETL pipeline
make reports   # Render Quarto report
```

---

## Configuration

Copy `.env.example` to `.env` and configure:

```bash
# Database
DB_DRIVER=PostgreSQL Unicode          # or: ODBC Driver 17 for SQL Server
DB_SERVER=localhost
DB_NAME=compensation
DB_USER=postgres
DB_PASSWORD=your-password
DB_TRUSTED_CONN=no

# Application
USER_ROLE=viewer                      # viewer | analyst | admin

# ETL
ETL_SOURCE_FILE=data/compensation_raw.csv
```

DB credentials can also be set live in the **Admin → Database Connection** panel without restarting the app.

---

## User Roles

| Role | Permissions |
|---|---|
| `viewer` | View dashboard, variance table, download reports |
| `analyst` | Viewer + run ETL |
| `admin` | Analyst + edit, delete, admin settings |

Set via `USER_ROLE` environment variable or implement full auth in `R/auth.R`.

---

## CSV Input Format

`data/compensation_raw.csv` columns:

| Column | Example |
|---|---|
| `physician_id` | 1 |
| `physician_name` | Dr. Alice Johnson |
| `specialty` | Cardiology |
| `role` | Attending |
| `location` | Main Campus |
| `employment_type` | Full-time |
| `service_month` | 01 |
| `service_year` | 2025 |
| `hours_worked` | 160 |
| `target_comp` | 350000 |
| `actual_comp` | 345000 |

---

## Makefile Targets

```bash
make help          # List all targets
make install       # Install R dependencies via devtools
make run           # Run Shiny app locally on port 3838
make etl           # Run ETL pipeline
make reports       # Render Quarto report to reports/output/
make docker-build  # Build Docker image
make docker-run    # Start containers with docker compose
make docker-stop   # Stop containers
make clean         # Remove build artifacts
make test          # Run testthat tests
```

---

## Troubleshooting

**App shows "Using Sample Data" badge**
No database connection — use Admin → Database Connection to configure and connect, or set env vars and restart.

**Report generation fails**
Ensure `rmarkdown` is installed and the `.qmd` file can source `R/analytics.R` and `R/database.R` from the `reports/` directory.

**Docker port conflict**
Change `3838:3838` or `5432:5432` in `docker-compose.yml` if those ports are already in use.

**Schema errors on load**
The schema is written for **PostgreSQL**. For SQL Server, refer to the original SQL Server syntax in version history.

---

## License

MIT — see [LICENSE](LICENSE)


## Features

- **Shiny Dashboard**: Interactive web interface for compensation visualization and analysis
- **Role-Based Access Control**: Admin, analyst, and viewer roles with permission management
- **ETL Pipeline**: Automated Extract, Transform, Load process for compensation data
- **Variance Analysis**: Detailed analysis of compensation variance by specialty and physician
- **Quarto Reports**: Parameterized reports for executive summaries and detailed analysis
- **Database Integration**: Support for SQL Server, PostgreSQL, and other ODBC-compatible databases
- **Docker Deployment**: Containerized application for easy deployment
- **Data Validation**: Comprehensive data quality checks during ETL

## Project Structure

```
comp-analytics/
├── app.R                      # Main Shiny application
├── R/                         # R helper modules
│   ├── auth.R                # Authentication and authorization
│   ├── database.R            # Database connections and queries
│   ├── analytics.R           # Analytics functions
│   └── etl.R                 # ETL process orchestration
├── sql/                      # SQL scripts and queries
│   ├── schema.sql            # Database schema definition
│   ├── compensation_summary.sql
│   └── variance_analysis.sql
├── reports/                  # Quarto report templates
│   └── compensation_analysis.qmd
├── data/                     # Data files and samples
│   └── compensation_raw.csv
├── www/                      # Static assets (CSS, JS, images)
├── Dockerfile                # Docker container definition
├── docker-compose.yml        # Docker Compose configuration
├── Makefile                  # Build automation
├── DESCRIPTION               # R package metadata
└── .env.example              # Environment variables template
```

## Prerequisites

### Local Development
- R 4.0 or higher
- RStudio (recommended)
- Quarto CLI (for report generation)
- Make (for build targets)
- PostgreSQL or SQL Server (for database backend)

### Docker Deployment
- Docker 20.10+
- Docker Compose 2.0+

## Quick Start

### Option 1: Local Development

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd comp-analytics
   ```

2. **Install R dependencies**
   ```bash
   make install
   ```

3. **Configure environment**
   ```bash
   cp .env.example .env
   # Edit .env with your database credentials
   ```

4. **Run the application**
   ```bash
   make run
   ```
   The app will be available at `http://localhost:3838`

### Option 2: Docker Compose (Recommended)

1. **Build and run containers**
   ```bash
   make docker-run
   ```

2. **Access the dashboard**
   - Open `http://localhost:3838` in your browser
   - Database available at `localhost:5432`

3. **Stop containers**
   ```bash
   make docker-stop
   ```

## Building the Project

### Common Build Targets

```bash
# Display all available targets
make help

# Install R dependencies
make install

# Run Shiny app locally
make run

# Run ETL process
make etl

# Generate Quarto reports
make reports

# Build Docker image
make docker-build

# Run with Docker Compose
make docker-run

# Stop Docker containers
make docker-stop

# Clean build artifacts
make clean
```

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
# Database Connection
DB_DRIVER=ODBC Driver 17 for SQL Server
DB_SERVER=your-server-name
DB_NAME=compensation
DB_USER=your-username
DB_PASSWORD=your-password

# Authentication
AUTH_TYPE=local  # Options: local, ldap, oauth
USER_ROLE=viewer

# ETL Configuration
ETL_SOURCE_FILE=data/compensation_raw.csv
```

### Database Setup

For local development with PostgreSQL:

```bash
# The docker-compose configuration creates a PostgreSQL database automatically
# To set up manually:
psql -U postgres -d compensation -f sql/schema.sql
```

## Usage

### Running the Dashboard

**Local:**
```bash
make run
```

**Docker:**
```bash
make docker-run
```

### Generating Reports

Generate a Quarto report with parameters:

```bash
# Default report
make reports

# Or with Quarto parameters
quarto render reports/compensation_analysis.qmd \
  -P specialty:"Cardiology" \
  -P report_type:"Detailed Analysis"
```

### Running ETL Process

```bash
make etl
```

This will:
1. Extract data from CSV source
2. Transform and clean the data
3. Validate data quality
4. Load into the database

## API Reference

### R Functions

#### Authentication (`R/auth.R`)
- `authenticate_user(username, password)` - Authenticate user
- `check_permission(user_role, required_permission)` - Check user permissions
- `get_user_role(session)` - Get user role from session

#### Database (`R/database.R`)
- `get_db_connection()` - Get database connection
- `get_compensation_summary()` - Retrieve compensation data
- `execute_query(query)` - Execute custom SQL query

#### Analytics (`R/analytics.R`)
- `calculate_variance(target, actual)` - Calculate compensation variance
- `variance_by_specialty(data)` - Analyze variance by specialty
- `calculate_metrics(data)` - Get summary metrics
- `identify_outliers(data, threshold)` - Identify statistical outliers

#### ETL (`R/etl.R`)
- `run_etl_process()` - Execute full ETL pipeline
- `extract_data(source_file)` - Extract source data
- `transform_data(data)` - Transform and clean data
- `validate_data(data)` - Validate data quality
- `load_data(data)` - Load data to database

## Database Schema

### Tables

**physicians**
- `physician_id` (INT, PK)
- `physician_name` (VARCHAR)
- `specialty` (VARCHAR)
- `department` (VARCHAR)
- `hire_date` (DATE)
- `status` (VARCHAR)

**compensation**
- `comp_id` (INT, PK)
- `physician_id` (INT, FK)
- `reporting_period` (DATE)
- `target_compensation` (DECIMAL)
- `actual_compensation` (DECIMAL)
- `variance_amount` (DECIMAL)
- `variance_percent` (DECIMAL)

## Development

### Adding New Features

1. Create new R script in `R/` directory
2. Add functions to `app.R` or relevant modules
3. Update dependencies in `DESCRIPTION`
4. Test with `make run`

### Database Changes

1. Create SQL migration in `sql/` directory
2. Update `sql/schema.sql` for documentation
3. Test against PostgreSQL and SQL Server if possible

### Report Customization

Edit `reports/compensation_analysis.qmd` to modify report structure, add new sections, or adjust visualizations.

## Troubleshooting

### Database connection fails
- Check `.env` configuration
- Verify database server is running
- Check network connectivity and firewall rules
- Ensure ODBC drivers are installed

### Shiny app won't start
- Check R package installation: `make install`
- Review app logs for errors
- Verify port 3838 is available

### Docker issues
- Ensure Docker daemon is running
- Check disk space for containers
- Review logs: `docker-compose logs`

## Deployment

### Production Deployment

1. **Configure production environment**
   ```bash
   cp .env.example .env.production
   # Update with production credentials
   ```

2. **Build optimized Docker image**
   ```bash
   docker build -t compensation-analytics:1.0 .
   ```

3. **Deploy with Docker Compose**
   ```bash
   docker-compose -f docker-compose.yml up -d
   ```

4. **Set up SSL/TLS reverse proxy** (nginx, Traefik, etc.)

5. **Configure monitoring and logging**

## Performance Optimization

- Index key database columns
- Cache frequently accessed queries
- Use connection pooling
- Optimize SQL queries
- Implement data pagination in UI

## License

MIT License - See LICENSE file for details

## Support

For issues, questions, or contributions, please:
1. Check existing documentation
2. Review SQL and R scripts
3. Check application logs
4. Create an issue in the repository

---

*Last Updated: February 2026*
