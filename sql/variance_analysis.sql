-- Variance analysis query
-- Analyze compensation variance by specialty (PostgreSQL)

SELECT
    p.specialty,
    p.location,
    p.role,
    COUNT(DISTINCT p.physician_id)                                              AS physician_count,
    ROUND(AVG(c.hours_worked)::NUMERIC, 1)                                      AS avg_hours_worked,
    ROUND(AVG(c.target_compensation)::NUMERIC, 2)                               AS avg_target,
    ROUND(AVG(c.actual_compensation)::NUMERIC, 2)                               AS avg_actual,
    ROUND(AVG(c.actual_compensation - c.target_compensation)::NUMERIC, 2)       AS avg_variance,
    ROUND(
      AVG((c.actual_compensation - c.target_compensation)
          / NULLIF(c.target_compensation, 0) * 100)::NUMERIC, 2
    )                                                                            AS avg_variance_pct,
    ROUND(MIN(c.actual_compensation)::NUMERIC, 2)                               AS min_actual,
    ROUND(MAX(c.actual_compensation)::NUMERIC, 2)                               AS max_actual,
    ROUND(STDDEV_POP(c.actual_compensation)::NUMERIC, 2)                        AS stddev_actual
FROM
    physicians p
    LEFT JOIN compensation c ON p.physician_id = c.physician_id
WHERE
    c.service_period >= (CURRENT_DATE - INTERVAL '1 year')
GROUP BY
    p.specialty, p.location, p.role
ORDER BY
    ABS(avg_variance_pct) DESC
