# Credit Risk Analytics

End-to-end data analytics project focused on identifying behavioral and financial indicators associated with next-month credit card default.

The project combines **SQL Server, Python, and Power BI** to validate the data, engineer reusable risk features, analyze customer behavior, and communicate the most relevant findings through an interactive dashboard.

![Credit Risk Dashboard](./images/dashboard_overview.png)

---

## Project Objective

The main business objective is to identify patterns associated with higher default risk and create reusable customer-risk features that can support monitoring and prioritization.

The analysis focuses on four key dimensions:

- **Payment delay frequency**
- **Payment delay severity**
- **Recent payment behavior**
- **Credit utilization and repayment behavior**

The project does **not** treat these indicators as deterministic predictors. They are interpreted as behavioral risk signals that can support further assessment.

---

## Dataset

This project uses the **Default of Credit Card Clients** dataset from the UCI Machine Learning Repository.

- **30,000 customers**
- **25 original variables in the project source file, including the target**
- Target variable: `DEFAULT_NEXT_MONTH`
  - `1` = customer defaulted in the next month
  - `0` = customer did not default

Main groups of variables include:

- Credit limit
- Demographic attributes
- Payment status history
- Monthly bill amounts
- Monthly payment amounts
- Default status

**Source:** UCI Machine Learning Repository — Default of Credit Card Clients  
https://archive.ics.uci.edu/dataset/350/default%2Bof%2Bcredit%2Bcard%2Bclients

**Dataset citation:** Yeh, I. (2009). *Default of Credit Card Clients* [Dataset]. UCI Machine Learning Repository.  
DOI: https://doi.org/10.24432/C55S3H

**License:** Creative Commons Attribution 4.0 International (CC BY 4.0)

---

## Tools Used

### SQL Server

- Data validation
- Feature engineering
- CTEs
- `CASE` expressions
- Aggregations
- Views

### Python

- `pandas`
- `numpy`
- `pyodbc`
- `matplotlib`
- Exploratory data analysis
- Extreme-value review
- Behavioral segmentation

### Power BI

- DAX measures
- Calculated columns
- KPI cards
- Interactive slicers
- Gauge visualization
- Executive dashboard

---

## Project Workflow

```text
Raw Credit Risk Data
        ↓
SQL Server Validation
        ↓
SQL Feature Engineering
        ↓
vw_CustomerRiskFeatures
        ↓
Python Exploratory Analysis
        ↓
Power BI Dashboard
        ↓
Business Insights
```

---

## SQL Analysis

SQL was used to validate the dataset and build reusable analytical features.

### Main SQL Features

#### `DelayedMonths`

Counts the number of observed periods with a confirmed payment delay.

```sql
CASE WHEN PAY_0 >= 1 THEN 1 ELSE 0 END +
CASE WHEN PAY_2 >= 1 THEN 1 ELSE 0 END +
CASE WHEN PAY_3 >= 1 THEN 1 ELSE 0 END +
CASE WHEN PAY_4 >= 1 THEN 1 ELSE 0 END +
CASE WHEN PAY_5 >= 1 THEN 1 ELSE 0 END +
CASE WHEN PAY_6 >= 1 THEN 1 ELSE 0 END
```

#### `MaxDelay`

Represents the maximum confirmed delay level observed across the payment history.

#### `CreditUtilization`

```text
BILL_AMT1 / LIMIT_BAL × 100
```

#### `PaymentRatio`

The SQL column `PaymentRatio` is calculated as:

```text
PAY_AMT1 / BILL_AMT1 × 100
```

It is only calculated when `BILL_AMT1 > 0`.

In this project, the metric is interpreted as a **payment-to-bill proxy** that compares the payment amount recorded for the period with the billed balance used in the analysis. It should **not** be interpreted as the exact percentage of a specific bill that was repaid because the dataset documentation does not explicitly map each payment amount to an individual bill statement.

#### `RiskGroup`

Customers were grouped into:

- `HighUtilization_LowPayment`
- `OtherValidBehavior`
- `NotComparable`

The final SQL view:

```sql
dbo.vw_CustomerRiskFeatures
```

was used as the reusable analytical layer for both Python and Power BI.

**SQL script:** [CreditRisk_SQL_Clean.sql](./SQL/CreditRisk_SQL_Clean.sql)

---

## Python Exploratory Analysis

Python was used to validate engineered features, inspect extreme values, and explore the relationship between payment behavior and default risk.

### Extreme Value Review

Extreme values in `PaymentRatio` and `CreditUtilization` were reviewed before segmentation.

They were retained when they were mathematically consistent with the underlying values rather than being automatically removed as errors. Because `PaymentRatio` is used as a payment-to-bill proxy, extreme values are interpreted cautiously and are not treated as exact repayment percentages.

**Notebook:** [Credit_Risk_Analysis.ipynb](./Python/Credit_Risk_Analysis.ipynb)

---

## Key Findings

### 1. Baseline Default Rate

- Total customers: **30,000**
- Default customers: **6,636**
- Overall default rate: **22.12%**

### 2. Delay Frequency

Default risk increased substantially as customers accumulated more delayed months.

- No confirmed delayed months: **11.71%**
- Delays in all six observed months: **70.32%**

Repeated payment delays were one of the strongest behavioral risk indicators observed in the analysis.

### 3. Recent Payment Delay

Customers with a recent confirmed delay showed a much higher default rate.

- No recent confirmed delay: **13.83%**
- Recent confirmed delay: **50.29%**

### 4. Combined Recency and Frequency

Combining recent delay status with historical delay frequency created clearer risk segmentation.

| Segment | Default Rate |
|---|---:|
| NoRecent_Low | 12.73% |
| NoRecent_High | 34.09% |
| Recent_Low | 36.05% |
| Recent_High | 57.88% |

The `Recent_High` segment showed the highest default rate.

### 5. Credit Utilization

Default risk generally increased as credit utilization rose.

| Credit Utilization Band | Default Rate |
|---|---:|
| Negative Balance | 17.56% |
| 0-29% | 18.33% |
| 30-59% | 23.18% |
| 60-79% | 27.27% |
| 80-99% | 25.54% |
| 100%+ | 30.00% |

The relationship was not perfectly linear, but customers above 100% utilization showed the highest rate.

### 6. Payment-to-Bill Proxy

The `PaymentRatio` feature showed an association between payment intensity and default risk, but it is interpreted as a proxy rather than an exact bill-repayment percentage.

| Payment Ratio Band | Default Rate |
|---|---:|
| Negative Balance | 18.47% |
| No Bill / Zero Balance | 26.59% |
| 0% | 39.81% |
| 1-24% | 20.82% |
| 25-49% | 17.15% |
| 50-99% | 13.58% |
| 100%+ | 15.50% |

The `0%` group showed the highest default rate within this segmentation.

---

## Power BI Dashboard

The Power BI dashboard was designed as a single-page executive overview.

### KPI Cards

- Total Customers
- Default Customers
- Default Rate

### Main Visuals

- Default Rate by Frequency Delay Segment
- Default Rate by Credit Utilization Band
- Default Rate by Payment Ratio Band

### Interactive Filters

- Education
- Marriage Status
- Risk Group

### Additional Features

- `Reset Filters` button
- Selected Default Rate vs Portfolio Baseline gauge
- Key Risk Signals summary

The dashboard allows users to compare filtered customer segments against the overall portfolio default rate of **22.12%**.

**Power BI file:** [Credit Risk PBI.pbix](./PowerBI/Credit%20Risk%20PBI.pbix)

---

## Key Risk Signals

- **Recent + frequent delays:** 57.88% default rate
- **100%+ credit utilization:** 30.00% default rate
- **0% payment-to-bill proxy:** 39.81% default rate

These indicators are behavioral risk signals and should be used to prioritize further assessment, not as deterministic predictions.

---

## Data Limitations

- The dataset represents a specific population of credit-card clients in Taiwan and a limited historical period, so the findings should not be generalized to every credit portfolio.
- The analysis identifies **associations** with next-month default and does not establish causality.
- No predictive model was developed. The project focuses on descriptive analytics, segmentation, feature engineering, and risk indicators.
- `PaymentRatio` is calculated as `PAY_AMT1 / BILL_AMT1` and is used as a **payment-to-bill proxy**. The dataset documentation does not explicitly map each payment amount to a specific bill statement, so this metric should not be interpreted as the exact percentage of an individual bill that was repaid.
- Extreme values were reviewed and retained when consistent with the underlying data; they should still be interpreted with caution.

---

## How to Run

### Requirements

- **SQL Server 2022+** because the SQL script uses `GREATEST`
- Python with:
  - `pandas`
  - `numpy`
  - `pyodbc`
  - `matplotlib`
- Microsoft ODBC Driver for SQL Server
- Power BI Desktop

### Steps

1. Load the source dataset into SQL Server as `dbo.CreditRiskRaw`.
2. Run [CreditRisk_SQL_Clean.sql](./SQL/CreditRisk_SQL_Clean.sql) to validate the data and create `dbo.vw_CustomerRiskFeatures`.
3. Open [Credit_Risk_Analysis.ipynb](./Python/Credit_Risk_Analysis.ipynb).
4. Update the SQL Server connection string in the notebook for your local environment.
5. Run the notebook cells in order.
6. Open [Credit Risk PBI.pbix](./PowerBI/Credit%20Risk%20PBI.pbix) in Power BI Desktop and update the SQL Server data-source settings if required.

---

## Repository Structure

```text
Credit-Risk-Analytics/
│
├── SQL/
│   └── CreditRisk_SQL_Clean.sql
│
├── Python/
│   └── Credit_Risk_Analysis.ipynb
│
├── PowerBI/
│   └── Credit Risk PBI.pbix
│
├── images/
│   └── dashboard_overview.png
│
└── README.md
```

---

## Business Interpretation

The analysis suggests that payment history should be a central component of credit-risk monitoring.

Customers showing:

- recent delays,
- repeated delays,
- high credit utilization,
- and low payment intensity

may require closer monitoring or earlier intervention.

The strongest insight from the project is that combining multiple behavioral indicators provides a clearer picture of customer risk than relying on a single metric.

---

## Author

**Carlos Luis Castillo**

Data Analyst Portfolio Project  
SQL Server | Python | Power BI

[LinkedIn](https://www.linkedin.com/in/carlos-castillo-data-analyst) | [GitHub](https://github.com/calimon2612-oss)
