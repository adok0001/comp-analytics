-- Compensation Summary Query
-- Returns aggregate compensation data by specialty and physician

SELECT
    p.physician_id,
    p.physician_name,
    p.specialty,
    p.role,
    p.location,
    p.employment_type,
    c.service_period,
    c.reporting_period,
    c.hours_worked,
    c.target_compensation,
    c.actual_compensation,
    c.actual_compensation - c.target_compensation AS variance,
    (c.actual_compensation - c.target_compensation) / NULLIF(c.target_compensation, 0) * 100 AS variance_pct,
    CASE WHEN c.hours_worked > 0
         THEN c.actual_compensation / c.hours_worked
         ELSE NULL END AS hourly_rate
FROM
    physicians p
    LEFT JOIN compensation c ON p.physician_id = c.physician_id
WHERE
    c.service_period = (SELECT MAX(service_period) FROM compensation)
ORDER BY
    p.specialty, p.physician_name
