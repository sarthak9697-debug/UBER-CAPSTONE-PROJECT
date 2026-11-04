/* ============================================================
   UBER CAPSTONE PROJECT
   COMPLETE SQL SERVER SCRIPT
   ============================================================ */


/* ============================================================
   1. CREATE DATABASE
   ============================================================ */

IF DB_ID('Uber_Capstone') IS NULL
BEGIN
    CREATE DATABASE Uber_Capstone;
END;
GO

USE Uber_Capstone;
GO


/* ============================================================
   2. VERIFY IMPORTED TABLES
   Excel files should already be imported into these tables:

   dbo.city_dataset2
   dbo.driver_dataset3
   dbo.[payment_dataset 4]
   dbo.rides_dataset1
   ============================================================ */

SELECT
    TABLE_SCHEMA,
    TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME IN
(
    'city_dataset2',
    'driver_dataset3',
    'payment_dataset 4',
    'rides_dataset1'
)
ORDER BY TABLE_NAME;
GO


/* ============================================================
   3. VERIFY ROW COUNTS
   Expected:
   city_dataset2       = 500
   driver_dataset3     = 100
   payment_dataset 4   = 500
   rides_dataset1      = 500
   ============================================================ */

SELECT
    'city_dataset2' AS Table_Name,
    COUNT(*) AS Row_Count
FROM dbo.city_dataset2

UNION ALL

SELECT
    'driver_dataset3',
    COUNT(*)
FROM dbo.driver_dataset3

UNION ALL

SELECT
    'payment_dataset 4',
    COUNT(*)
FROM dbo.[payment_dataset 4]

UNION ALL

SELECT
    'rides_dataset1',
    COUNT(*)
FROM dbo.rides_dataset1;
GO


/* ============================================================
   4. VIEW SAMPLE DATA
   ============================================================ */

SELECT TOP 10 *
FROM dbo.rides_dataset1;

SELECT TOP 10 *
FROM dbo.city_dataset2;

SELECT TOP 10 *
FROM dbo.driver_dataset3;

SELECT TOP 10 *
FROM dbo.[payment_dataset 4];
GO


/* ============================================================
   5. BUSINESS ANALYSIS
   AVERAGE FARE FOR EACH CITY
   ============================================================ */

SELECT
    start_city,
    AVG(fare) AS average_fare
FROM dbo.rides_dataset1
WHERE fare IS NOT NULL
GROUP BY start_city
ORDER BY average_fare DESC;
GO


/* ============================================================
   6. CREATE INDEX FOR RIDE DATE
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'idx_ride_date'
      AND object_id = OBJECT_ID('dbo.rides_dataset1')
)
BEGIN
    CREATE INDEX idx_ride_date
    ON dbo.rides_dataset1(ride_date);
END;
GO


/* ============================================================
   7. VERIFY INDEX
   ============================================================ */

SELECT
    name AS Index_Name,
    type_desc AS Index_Type
FROM sys.indexes
WHERE object_id = OBJECT_ID('dbo.rides_dataset1');
GO


/* ============================================================
   8. DATE FILTERING
   ============================================================ */

SELECT *
FROM dbo.rides_dataset1
WHERE ride_date >= '2024-05-01'
  AND ride_date < '2024-05-02';


SELECT
    ride_id,
    fare
FROM dbo.rides_dataset1
WHERE ride_date = '2024-05-01';
GO


/* ============================================================
   9. UPDATE STATISTICS
   ============================================================ */

UPDATE STATISTICS dbo.rides_dataset1;
GO


/* ============================================================
   10. REBUILD INDEX
   ============================================================ */

ALTER INDEX ALL
ON dbo.rides_dataset1
REBUILD;
GO


/* ============================================================
   11. AVERAGE RIDE DURATION
       AND CUSTOMER SATISFACTION
   ============================================================ */

SELECT
    start_city,

    AVG(
        CASE
            WHEN CAST(end_time AS time)
               >= CAST(start_time AS time)
            THEN
                DATEDIFF(
                    MINUTE,
                    CAST(start_time AS time),
                    CAST(end_time AS time)
                )

            ELSE
                DATEDIFF(
                    MINUTE,
                    CAST(start_time AS time),
                    DATEADD(
                        DAY,
                        1,
                        CAST(end_time AS datetime)
                    )
                )
        END
    ) AS avg_ride_duration_minutes,

    AVG(
        CAST(rating AS DECIMAL(10,2))
    ) AS avg_customer_rating

FROM dbo.rides_dataset1

WHERE start_time IS NOT NULL
  AND end_time IS NOT NULL
  AND rating IS NOT NULL

GROUP BY start_city

ORDER BY avg_ride_duration_minutes DESC;
GO


/* ============================================================
   12. FARE VARIATION ACROSS SEASONS
   ============================================================ */

SELECT
    CASE
        WHEN MONTH(ride_date) IN (12, 1, 2)
            THEN 'Winter'

        WHEN MONTH(ride_date) IN (3, 4, 5)
            THEN 'Spring'

        WHEN MONTH(ride_date) IN (6, 7, 8)
            THEN 'Summer'

        WHEN MONTH(ride_date) IN (9, 10, 11)
            THEN 'Autumn'
    END AS Season,

    COUNT(*) AS Total_Rides,

    AVG(fare) AS Avg_Fare,

    MIN(fare) AS Min_Fare,

    MAX(fare) AS Max_Fare,

    STDEV(fare) AS Fare_StdDev

FROM dbo.rides_dataset1

WHERE fare IS NOT NULL
  AND ride_date IS NOT NULL

GROUP BY
    CASE
        WHEN MONTH(ride_date) IN (12, 1, 2)
            THEN 'Winter'

        WHEN MONTH(ride_date) IN (3, 4, 5)
            THEN 'Spring'

        WHEN MONTH(ride_date) IN (6, 7, 8)
            THEN 'Summer'

        WHEN MONTH(ride_date) IN (9, 10, 11)
            THEN 'Autumn'
    END

ORDER BY Avg_Fare DESC;
GO


/* ============================================================
   13. CANCELLATION PATTERNS BY TIME OF DAY
   ============================================================ */

SELECT
    DATEPART(
        HOUR,
        CAST(start_time AS time)
    ) AS RideHour,

    COUNT(*) AS TotalRides,

    SUM(
        CASE
            WHEN ride_status = 'Canceled'
                THEN 1
            ELSE 0
        END
    ) AS CanceledRides,

    SUM(
        CASE
            WHEN ride_status = 'Completed'
                THEN ISNULL(fare, 0)
            ELSE 0
        END
    ) AS Revenue,

    CAST(
        SUM(
            CASE
                WHEN ride_status = 'Canceled'
                    THEN 1
                ELSE 0
            END
        ) * 100.0
        / NULLIF(COUNT(*), 0)
        AS DECIMAL(5,2)
    ) AS CancellationRate

FROM dbo.rides_dataset1

WHERE start_time IS NOT NULL

GROUP BY
    DATEPART(
        HOUR,
        CAST(start_time AS time)
    )

ORDER BY CancellationRate DESC;
GO


/* ============================================================
   14. CANCELLATION PATTERNS ACROSS CITIES
   ============================================================ */

SELECT
    start_city,

    COUNT(*) AS total_rides,

    SUM(
        CASE
            WHEN ride_status = 'Canceled'
                THEN 1
            ELSE 0
        END
    ) AS canceled_rides,

    SUM(
        CASE
            WHEN ride_status = 'Completed'
                THEN ISNULL(fare, 0)
            ELSE 0
        END
    ) AS total_revenue,

    CAST(
        SUM(
            CASE
                WHEN ride_status = 'Canceled'
                    THEN 1
                ELSE 0
            END
        ) * 100.0
        / NULLIF(COUNT(*), 0)
        AS DECIMAL(5,2)
    ) AS cancellation_rate

FROM dbo.rides_dataset1

WHERE ride_status IN
(
    'Completed',
    'Canceled'
)

GROUP BY start_city

ORDER BY cancellation_rate DESC;
GO


/* ============================================================
   15. CREATE AUDIT TABLE
   Correct ride_id datatype = VARCHAR
   because ride_id contains UUID values.
   ============================================================ */

IF OBJECT_ID(
    'dbo.ride_status_audit',
    'U'
) IS NULL
BEGIN

    CREATE TABLE dbo.ride_status_audit
    (
        audit_id INT IDENTITY(1,1) PRIMARY KEY,

        ride_id VARCHAR(50),

        old_status VARCHAR(50),

        new_status VARCHAR(50),

        changed_at DATETIME
            DEFAULT GETDATE(),

        changed_by VARCHAR(100)
    );

END;
GO


/* ============================================================
   16. FIX EXISTING AUDIT TABLE IF ride_id IS INT
   ============================================================ */

IF EXISTS
(
    SELECT 1
    FROM sys.columns
    WHERE object_id =
          OBJECT_ID('dbo.ride_status_audit')
      AND name = 'ride_id'
      AND system_type_id = 56
)
BEGIN

    ALTER TABLE dbo.ride_status_audit
    ALTER COLUMN ride_id VARCHAR(50);

END;
GO


/* ============================================================
   17. DROP OLD TRIGGER IF IT EXISTS
   ============================================================ */

IF OBJECT_ID(
    'dbo.trg_ride_status_change',
    'TR'
) IS NOT NULL
BEGIN

    DROP TRIGGER dbo.trg_ride_status_change;

END;
GO


/* ============================================================
   18. CREATE CORRECT STATUS AUDIT TRIGGER
   ============================================================ */

CREATE TRIGGER dbo.trg_ride_status_change

ON dbo.rides_dataset1

AFTER UPDATE

AS
BEGIN

    SET NOCOUNT ON;

    INSERT INTO dbo.ride_status_audit
    (
        ride_id,
        old_status,
        new_status,
        changed_by
    )

    SELECT
        d.ride_id,

        d.ride_status AS old_status,

        i.ride_status AS new_status,

        SYSTEM_USER

    FROM deleted d

    INNER JOIN inserted i
        ON d.ride_id = i.ride_id

    WHERE ISNULL(
              d.ride_status,
              ''
          )
          <>
          ISNULL(
              i.ride_status,
              ''
          );

END;
GO


/* ============================================================
   19. VERIFY AUDIT TABLE
   ============================================================ */

SELECT
    TABLE_SCHEMA,
    TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME =
      'ride_status_audit';
GO


/* ============================================================
   20. VERIFY AUDIT TABLE COLUMNS
   ============================================================ */

SELECT
    COLUMN_NAME,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME =
      'ride_status_audit'
ORDER BY ORDINAL_POSITION;
GO


/* ============================================================
   21. VERIFY TRIGGER
   is_disabled = 0 means ENABLED
   ============================================================ */

SELECT
    name AS Trigger_Name,

    is_disabled

FROM sys.triggers

WHERE parent_id =
      OBJECT_ID('dbo.rides_dataset1');
GO


/* ============================================================
   22. DRIVER PERFORMANCE ANALYSIS
   ============================================================ */

SELECT
    d.driver_id,

    d.driver_name,

    COUNT(r.ride_id) AS total_rides,

    AVG(
        CAST(
            r.rating AS DECIMAL(10,2)
        )
    ) AS avg_rating,

    SUM(
        CASE
            WHEN r.ride_status = 'Completed'
                THEN ISNULL(r.fare, 0)
            ELSE 0
        END
    ) AS total_revenue,

    CAST(
        SUM(
            CASE
                WHEN r.ride_status = 'Canceled'
                    THEN 1
                ELSE 0
            END
        ) * 100.0
        / NULLIF(
            COUNT(r.ride_id),
            0
        )
        AS DECIMAL(5,2)
    ) AS cancellation_rate,

    AVG(
        CASE

            WHEN r.start_time IS NULL
              OR r.end_time IS NULL
                THEN NULL

            WHEN CAST(r.end_time AS time)
               >= CAST(r.start_time AS time)

            THEN
                DATEDIFF(
                    MINUTE,
                    CAST(r.start_time AS time),
                    CAST(r.end_time AS time)
                )

            ELSE
                DATEDIFF(
                    MINUTE,
                    CAST(r.start_time AS time),
                    DATEADD(
                        DAY,
                        1,
                        CAST(r.end_time AS datetime)
                    )
                )

        END
    ) AS avg_ride_duration_minutes

FROM dbo.rides_dataset1 r

INNER JOIN dbo.driver_dataset3 d

    ON r.driver_id =
       d.driver_id

GROUP BY
    d.driver_id,
    d.driver_name

ORDER BY
    total_revenue DESC;
GO


/* ============================================================
   23. VIEW AUDIT HISTORY
   ============================================================ */

SELECT TOP 20

    audit_id,

    ride_id,

    old_status,

    new_status,

    changed_at,

    changed_by

FROM dbo.ride_status_audit

ORDER BY
    audit_id DESC;
GO


/* ============================================================
   24. FINAL TABLE VERIFICATION
   ============================================================ */

SELECT
    'city_dataset2' AS Table_Name,
    COUNT(*) AS Row_Count

FROM dbo.city_dataset2

UNION ALL

SELECT
    'driver_dataset3',
    COUNT(*)

FROM dbo.driver_dataset3

UNION ALL

SELECT
    'payment_dataset 4',
    COUNT(*)

FROM dbo.[payment_dataset 4]

UNION ALL

SELECT
    'rides_dataset1',
    COUNT(*)

FROM dbo.rides_dataset1;
GO


/* ============================================================
   25. FINAL INDEX VERIFICATION
   ============================================================ */

SELECT
    name AS Index_Name,

    type_desc AS Index_Type

FROM sys.indexes

WHERE object_id =
      OBJECT_ID('dbo.rides_dataset1');
GO


/* ============================================================
   26. FINAL TRIGGER VERIFICATION
   ============================================================ */

SELECT
    name AS Trigger_Name,

    is_disabled

FROM sys.triggers

WHERE parent_id =
      OBJECT_ID('dbo.rides_dataset1');
GO


/* ============================================================
   27. FINAL AUDIT TABLE VERIFICATION
   ============================================================ */

SELECT
    COUNT(*) AS Audit_Record_Count

FROM dbo.ride_status_audit;
GO


/* ============================================================
   28. FINAL DATABASE OBJECT CHECK
   ============================================================ */

SELECT
    name AS Object_Name,
    type_desc AS Object_Type
FROM sys.objects
WHERE name IN
(
    'city_dataset2',
    'driver_dataset3',
    'payment_dataset 4',
    'rides_dataset1',
    'ride_status_audit',
    'trg_ride_status_change'
)
ORDER BY type_desc, name;
GO