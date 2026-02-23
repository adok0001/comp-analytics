-- Create physicians table
CREATE TABLE IF NOT EXISTS physicians (
    physician_id    INT          PRIMARY KEY,
    physician_name  VARCHAR(255) NOT NULL,
    specialty       VARCHAR(100),
    department      VARCHAR(100),
    -- Clinical role (e.g. Attending, Fellow, Resident, NP, PA, Locum)
    role            VARCHAR(100),
    -- Facility / site where the physician primarily works
    location        VARCHAR(255),
    -- Full-time, Part-time, Contract, Locum Tenens
    employment_type VARCHAR(50)  DEFAULT 'Full-time',
    hire_date       DATE,
    status          VARCHAR(20)  DEFAULT 'Active',
    created_date    TIMESTAMP    DEFAULT NOW(),
    updated_date    TIMESTAMP    DEFAULT NOW()
);

-- Create compensation table
CREATE TABLE IF NOT EXISTS compensation (
    comp_id              SERIAL       PRIMARY KEY,
    physician_id         INT          NOT NULL,
    -- First day of the service month (e.g. 2025-01-01 for Jan 2025)
    service_period       DATE         NOT NULL,
    reporting_period     DATE         NOT NULL,
    target_compensation  DECIMAL(15,2),
    actual_compensation  DECIMAL(15,2),
    variance_amount      DECIMAL(15,2),
    variance_percent     DECIMAL(10,4),
    hours_worked         DECIMAL(8,2),
    hourly_rate          DECIMAL(10,2) GENERATED ALWAYS AS (
                           CASE WHEN hours_worked > 0
                                THEN actual_compensation / hours_worked
                                ELSE NULL END
                         ) STORED,
    rvu_production       DECIMAL(12,2),
    bonus                DECIMAL(15,2),
    benefits_value       DECIMAL(15,2),
    created_date         TIMESTAMP    DEFAULT NOW(),
    FOREIGN KEY (physician_id) REFERENCES physicians(physician_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_compensation_period    ON compensation(reporting_period);
CREATE INDEX IF NOT EXISTS idx_compensation_service   ON compensation(service_period);
CREATE INDEX IF NOT EXISTS idx_compensation_physician ON compensation(physician_id);
CREATE INDEX IF NOT EXISTS idx_physicians_role        ON physicians(role);
CREATE INDEX IF NOT EXISTS idx_physicians_location    ON physicians(location);
