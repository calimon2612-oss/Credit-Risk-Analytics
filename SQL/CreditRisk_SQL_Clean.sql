/*==============================================================================
PROJECT: Credit Risk Analytics
AUTHOR: Carlos Castillo
PURPOSE:
    Curated SQL script for a portfolio project focused on identifying behavioral
    and financial indicators associated with next-month credit card default.

WORKFLOW:
    1. Data validation
    2. Baseline default rate
    3. Payment-delay behavior
    4. Credit utilization
    5. Payment ratio
    6. Combined risk segmentation
    7. Reusable analytical view
    8. Final validation

NOTES:
    - A confirmed delay is defined as PAY_x >= 1.
    - PAY_x values below 1 are preserved without assigning unsupported meaning.
    - PaymentRatio is only calculated when BILL_AMT1 > 0.
    - Extreme values are retained because they can represent valid customer behavior.
==============================================================================*/

USE CreditRiskPortfolio;
GO


/*==============================================================================
1. DATA VALIDATION
Business question:
Is the imported dataset structurally complete and suitable for analysis?
==============================================================================*/

SELECT
    COUNT(*) AS TotalRows,
    COUNT(DISTINCT ID) AS UniqueCustomers,
    SUM(DEFAULT_NEXT_MONTH) AS DefaultCustomers,
    SUM(CASE WHEN ID IS NULL THEN 1 ELSE 0 END) AS Null_ID,
    SUM(CASE WHEN LIMIT_BAL IS NULL THEN 1 ELSE 0 END) AS Null_LIMIT_BAL,
    SUM(CASE WHEN AGE IS NULL THEN 1 ELSE 0 END) AS Null_AGE,
    SUM(CASE WHEN DEFAULT_NEXT_MONTH IS NULL THEN 1 ELSE 0 END) AS Null_DEFAULT
FROM dbo.CreditRiskRaw;

SELECT
    ID,
    COUNT(*) AS DuplicateCount
FROM dbo.CreditRiskRaw
GROUP BY ID
HAVING COUNT(*) > 1;


/*==============================================================================
2. BASELINE DEFAULT RATE
Business question:
What percentage of customers defaulted in the next month?
==============================================================================*/

SELECT
    COUNT(*) AS TotalCustomers,
    SUM(DEFAULT_NEXT_MONTH) AS DefaultCustomers,
    CAST(ROUND(SUM(DEFAULT_NEXT_MONTH) * 100.0 / COUNT(*), 2) AS DECIMAL(5,2)) AS DefaultRate
FROM dbo.CreditRiskRaw;


/*==============================================================================
3. PAYMENT DELAY BEHAVIOR
Business question:
How are recent, frequent, and severe payment delays associated with default risk?
==============================================================================*/

-- 3.1 Recent confirmed delay
SELECT
    CASE
        WHEN PAY_0 >= 1 THEN 'ConfirmedDelay'
        ELSE 'NoConfirmedDelay'
    END AS RecentPaymentStatus,
    COUNT(*) AS TotalCustomers,
    SUM(DEFAULT_NEXT_MONTH) AS DefaultCustomers,
    CAST(ROUND(SUM(DEFAULT_NEXT_MONTH) * 100.0 / COUNT(*), 2) AS DECIMAL(5,2)) AS DefaultRate
FROM dbo.CreditRiskRaw
GROUP BY
    CASE
        WHEN PAY_0 >= 1 THEN 'ConfirmedDelay'
        ELSE 'NoConfirmedDelay'
    END;


-- 3.2 Delay frequency
WITH PaymentBehavior AS (
    SELECT
        ID,
        DEFAULT_NEXT_MONTH,
        CASE WHEN PAY_0 >= 1 THEN 1 ELSE 0 END +
        CASE WHEN PAY_2 >= 1 THEN 1 ELSE 0 END +
        CASE WHEN PAY_3 >= 1 THEN 1 ELSE 0 END +
        CASE WHEN PAY_4 >= 1 THEN 1 ELSE 0 END +
        CASE WHEN PAY_5 >= 1 THEN 1 ELSE 0 END +
        CASE WHEN PAY_6 >= 1 THEN 1 ELSE 0 END AS DelayedMonths
    FROM dbo.CreditRiskRaw
)
SELECT
    DelayedMonths,
    COUNT(*) AS TotalCustomers,
    SUM(DEFAULT_NEXT_MONTH) AS DefaultCustomers,
    CAST(ROUND(SUM(DEFAULT_NEXT_MONTH) * 100.0 / COUNT(*), 2) AS DECIMAL(5,2)) AS DefaultRate
FROM PaymentBehavior
GROUP BY DelayedMonths
ORDER BY DelayedMonths;


-- 3.3 Delay severity
WITH PaymentSeverity AS (
    SELECT
        ID,
        DEFAULT_NEXT_MONTH,
        CASE
            WHEN GREATEST(PAY_0, PAY_2, PAY_3, PAY_4, PAY_5, PAY_6) >= 1
            THEN GREATEST(PAY_0, PAY_2, PAY_3, PAY_4, PAY_5, PAY_6)
            ELSE 0
        END AS MaxDelay
    FROM dbo.CreditRiskRaw
)
SELECT
    MaxDelay,
    COUNT(*) AS TotalCustomers,
    SUM(DEFAULT_NEXT_MONTH) AS DefaultCustomers,
    CAST(ROUND(SUM(DEFAULT_NEXT_MONTH) * 100.0 / COUNT(*), 2) AS DECIMAL(5,2)) AS DefaultRate
FROM PaymentSeverity
GROUP BY MaxDelay
ORDER BY MaxDelay;


/*==============================================================================
4. CREDIT UTILIZATION
Business question:
Does default risk increase as customers use a larger share of their credit limit?
==============================================================================*/

WITH CreditUtilization AS (
    SELECT
        ID,
        DEFAULT_NEXT_MONTH,
        LIMIT_BAL,
        BILL_AMT1,
        CAST(ROUND(BILL_AMT1 * 100.0 / NULLIF(LIMIT_BAL, 0), 2) AS DECIMAL(10,2)) AS CreditUtilization
    FROM dbo.CreditRiskRaw
),
UtilizationBands AS (
    SELECT
        ID,
        DEFAULT_NEXT_MONTH,
        CreditUtilization,
        CASE
            WHEN CreditUtilization < 0 THEN 'Negative Balance'
            WHEN CreditUtilization < 30 THEN '0-29%'
            WHEN CreditUtilization < 60 THEN '30-59%'
            WHEN CreditUtilization < 80 THEN '60-79%'
            WHEN CreditUtilization < 100 THEN '80-99%'
            ELSE '100%+'
        END AS CreditUtilizationBand
    FROM CreditUtilization
)
SELECT
    CreditUtilizationBand,
    COUNT(*) AS TotalCustomers,
    SUM(DEFAULT_NEXT_MONTH) AS DefaultCustomers,
    CAST(ROUND(SUM(DEFAULT_NEXT_MONTH) * 100.0 / COUNT(*), 2) AS DECIMAL(5,2)) AS DefaultRate
FROM UtilizationBands
GROUP BY CreditUtilizationBand
ORDER BY
    CASE CreditUtilizationBand
        WHEN 'Negative Balance' THEN 1
        WHEN '0-29%' THEN 2
        WHEN '30-59%' THEN 3
        WHEN '60-79%' THEN 4
        WHEN '80-99%' THEN 5
        WHEN '100%+' THEN 6
    END;


/*==============================================================================
5. PAYMENT RATIO
Business question:
Does paying a larger proportion of the billed balance relate to lower default risk?
==============================================================================*/

WITH PaymentRatio AS (
    SELECT
        ID,
        DEFAULT_NEXT_MONTH,
        BILL_AMT1,
        PAY_AMT1,
        CASE
            WHEN BILL_AMT1 > 0
            THEN CAST(ROUND(PAY_AMT1 * 100.0 / NULLIF(BILL_AMT1, 0), 2) AS DECIMAL(10,2))
            ELSE NULL
        END AS PaymentRatio
    FROM dbo.CreditRiskRaw
),
PaymentRatioBands AS (
    SELECT
        ID,
        DEFAULT_NEXT_MONTH,
        BILL_AMT1,
        PAY_AMT1,
        PaymentRatio,
        CASE
            WHEN BILL_AMT1 < 0 THEN 'Negative Balance'
            WHEN BILL_AMT1 = 0 THEN 'No Bill / Zero Balance'
            WHEN PaymentRatio = 0 THEN '0%'
            WHEN PaymentRatio < 25 THEN '1-24%'
            WHEN PaymentRatio < 50 THEN '25-49%'
            WHEN PaymentRatio < 100 THEN '50-99%'
            ELSE '100%+'
        END AS PaymentRatioBand
    FROM PaymentRatio
)
SELECT
    PaymentRatioBand,
    COUNT(*) AS TotalCustomers,
    SUM(DEFAULT_NEXT_MONTH) AS DefaultCustomers,
    CAST(ROUND(SUM(DEFAULT_NEXT_MONTH) * 100.0 / COUNT(*), 2) AS DECIMAL(5,2)) AS DefaultRate
FROM PaymentRatioBands
GROUP BY PaymentRatioBand
ORDER BY
    CASE PaymentRatioBand
        WHEN 'Negative Balance' THEN 1
        WHEN 'No Bill / Zero Balance' THEN 2
        WHEN '0%' THEN 3
        WHEN '1-24%' THEN 4
        WHEN '25-49%' THEN 5
        WHEN '50-99%' THEN 6
        WHEN '100%+' THEN 7
    END;


/*==============================================================================
6. COMBINED RISK SEGMENTATION
Business question:
Can utilization and repayment behavior identify a higher-risk customer segment?
==============================================================================*/

WITH RiskMetrics AS (
    SELECT
        ID,
        DEFAULT_NEXT_MONTH,
        LIMIT_BAL,
        BILL_AMT1,
        PAY_AMT1,
        CAST(ROUND(BILL_AMT1 * 100.0 / NULLIF(LIMIT_BAL, 0), 2) AS DECIMAL(10,2)) AS CreditUtilization,
        CASE
            WHEN BILL_AMT1 > 0
            THEN CAST(ROUND(PAY_AMT1 * 100.0 / NULLIF(BILL_AMT1, 0), 2) AS DECIMAL(10,2))
            ELSE NULL
        END AS PaymentRatio
    FROM dbo.CreditRiskRaw
),
RiskSegment AS (
    SELECT
        ID,
        DEFAULT_NEXT_MONTH,
        BILL_AMT1,
        CreditUtilization,
        PaymentRatio,
        CASE
            WHEN BILL_AMT1 <= 0 OR PaymentRatio IS NULL THEN 'NotComparable'
            WHEN CreditUtilization >= 80 AND PaymentRatio < 25 THEN 'HighUtilization_LowPayment'
            ELSE 'OtherValidBehavior'
        END AS RiskGroup
    FROM RiskMetrics
)
SELECT
    RiskGroup,
    COUNT(*) AS TotalCustomers,
    SUM(DEFAULT_NEXT_MONTH) AS DefaultCustomers,
    CAST(ROUND(SUM(DEFAULT_NEXT_MONTH) * 100.0 / COUNT(*), 2) AS DECIMAL(5,2)) AS DefaultRate
FROM RiskSegment
GROUP BY RiskGroup;


/*==============================================================================
7. REUSABLE CUSTOMER RISK FEATURE VIEW
Purpose:
Create a reusable analytical layer for Python and Power BI so the same business
logic is applied consistently across tools.
==============================================================================*/

CREATE OR ALTER VIEW dbo.vw_CustomerRiskFeatures
AS
WITH BaseFeatures AS (
    SELECT
        ID,
        DEFAULT_NEXT_MONTH,
        LIMIT_BAL,
        BILL_AMT1,
        PAY_AMT1,
        SEX,
        EDUCATION,
        MARRIAGE,
        AGE,
        PAY_0, PAY_2, PAY_3, PAY_4, PAY_5, PAY_6,
        BILL_AMT2, BILL_AMT3, BILL_AMT4, BILL_AMT5, BILL_AMT6,
        PAY_AMT2, PAY_AMT3, PAY_AMT4, PAY_AMT5, PAY_AMT6,

        CASE
            WHEN EDUCATION = 1 THEN 'Graduate School'
            WHEN EDUCATION = 2 THEN 'University'
            WHEN EDUCATION = 3 THEN 'High School'
            WHEN EDUCATION = 4 THEN 'Other'
            WHEN EDUCATION IN (0,5,6) THEN 'Other/Unknown'
            ELSE 'Unknown'
        END AS EducationCategory,

        CASE
            WHEN MARRIAGE = 1 THEN 'Married'
            WHEN MARRIAGE = 2 THEN 'Single'
            WHEN MARRIAGE = 3 THEN 'Other'
            WHEN MARRIAGE = 0 THEN 'Unknown'
            ELSE 'Unknown'
        END AS MarriageCategory,

        CASE
            WHEN PAY_0 >= 1 OR PAY_2 >= 1 OR PAY_3 >= 1
              OR PAY_4 >= 1 OR PAY_5 >= 1 OR PAY_6 >= 1
            THEN 1
            ELSE 0
        END AS HasPreviousDelay,

        CASE WHEN PAY_0 >= 1 THEN 1 ELSE 0 END +
        CASE WHEN PAY_2 >= 1 THEN 1 ELSE 0 END +
        CASE WHEN PAY_3 >= 1 THEN 1 ELSE 0 END +
        CASE WHEN PAY_4 >= 1 THEN 1 ELSE 0 END +
        CASE WHEN PAY_5 >= 1 THEN 1 ELSE 0 END +
        CASE WHEN PAY_6 >= 1 THEN 1 ELSE 0 END AS DelayedMonths,

        CASE
            WHEN GREATEST(PAY_0, PAY_2, PAY_3, PAY_4, PAY_5, PAY_6) >= 1
            THEN GREATEST(PAY_0, PAY_2, PAY_3, PAY_4, PAY_5, PAY_6)
            ELSE 0
        END AS MaxDelay,

        CAST(ROUND(BILL_AMT1 * 100.0 / NULLIF(LIMIT_BAL, 0), 2) AS DECIMAL(10,2)) AS CreditUtilization,

        CASE
            WHEN BILL_AMT1 > 0
            THEN CAST(ROUND(PAY_AMT1 * 100.0 / NULLIF(BILL_AMT1, 0), 2) AS DECIMAL(10,2))
            ELSE NULL
        END AS PaymentRatio

    FROM dbo.CreditRiskRaw
)
SELECT
    *,
    CASE
        WHEN BILL_AMT1 <= 0 OR PaymentRatio IS NULL THEN 'NotComparable'
        WHEN CreditUtilization >= 80 AND PaymentRatio < 25 THEN 'HighUtilization_LowPayment'
        ELSE 'OtherValidBehavior'
    END AS RiskGroup
FROM BaseFeatures;
GO


/*==============================================================================
8. FINAL VIEW VALIDATION
Business question:
Did the analytical view preserve the full customer population and expected
feature ranges?
==============================================================================*/

SELECT
    COUNT(*) AS TotalRows,
    COUNT(DISTINCT ID) AS UniqueCustomers,
    SUM(DEFAULT_NEXT_MONTH) AS DefaultCustomers,
    SUM(CASE WHEN PaymentRatio IS NULL THEN 1 ELSE 0 END) AS NullPaymentRatio,
    MIN(DelayedMonths) AS MinDelayedMonths,
    MAX(DelayedMonths) AS MaxDelayedMonths,
    MIN(MaxDelay) AS MinMaxDelay,
    MAX(MaxDelay) AS MaxMaxDelay,
    MIN(CreditUtilization) AS MinCreditUtilization,
    MAX(CreditUtilization) AS MaxCreditUtilization,
    MIN(PaymentRatio) AS MinPaymentRatio,
    MAX(PaymentRatio) AS MaxPaymentRatio
FROM dbo.vw_CustomerRiskFeatures;
