# Customer Churn Analysis — Olist Brazilian E-Commerce

## Overview

This project analyzes customer churn behavior using the Olist Brazilian e-commerce dataset.
The objective is to identify patterns that differentiate churned and retained customers and evaluate how well these patterns can predict churn.

## Dataset

Brazilian E-Commerce Public Dataset by Olist

~100k orders (2016–2018)
Multi-marketplace transactions across Brazil
Includes order status, pricing, delivery, customer, and product information


## Problem Definition

Churn is defined as:

> A customer is considered churned if they have not made a purchase in the last **90 days** relative to the dataset’s reference date.

To avoid data leakage, customers with recent activity inside the 90-day window are excluded.

---

## Data Pipeline

This project follows a two-stage workflow:

### 1. Exploratory Analysis (Pandas)

* Data cleaning and type conversion
* Feature experimentation
* Initial hypothesis generation

### 2. Feature Engineering (SQL)

* Reimplementation of features using PostgreSQL
* Use of joins and window functions (`LAG`, `ROW_NUMBER`)
* Creation of a reproducible customer-level dataset

The final dataset is exported for downstream analysis and modeling.

---

## Features

Customer-level features used:

* **total_orders** — number of purchases
* **avg_days_between_orders** — purchase timing (inter-purchase interval)
* **avg_delivery_delay** — difference between actual and estimated delivery dates
* **is_multi** — whether customer purchased across multiple product categories
* **churn** — target variable (0 = retained, 1 = churned)

---

## Analysis

### Key Findings

* **Purchase timing is the strongest signal**

  * Churned customers exhibit significantly shorter inter-purchase intervals
  * Moderate effect size (r ≈ 0.35) indicates meaningful behavioral difference

* **Category breadth (is_multi) shows weak association**

  * Multi-category users churn less, but effect size is small (Cramér’s V ≈ 0.09)

* **Order count has limited impact**

  * Statistically significant but weak relationship with churn

* **Delivery delay has no meaningful effect**

  * Nearly identical distributions across churned and retained users

---

## Modeling

A logistic regression model was used to evaluate predictive power:

* **AUC ≈ 0.67** → moderate performance
* Strongest feature: `avg_days_between_orders`
* Weak features: `total_orders`, `avg_delivery_delay`
* Negligible: `is_multi`

---

## Key Insight

Churn behavior follows a **“burst-and-drop” pattern**:

* Customers make rapid repeat purchases over a short period
* Followed by disengagement

Retention is driven more by **purchase timing patterns** than by order volume or delivery experience.

---

## Project Structure

```
.
## Project Structure

```text
.
├── churn_analysis/
│   ├── a01_data_preparation.ipynb
│   ├── a02_EDA_olist_ecommerce.ipynb
│   ├── a03_analysis.ipynb
│   ├── a04_feature_engineering_sql.ipynb
│   └── a05_model.ipynb
│
├── data/
│   ├── olist_orders_dataset.csv
│   ├── olist_order_items_dataset.csv
│   ├── olist_order_reviews_dataset.csv  
│   ├── olist_order_payments_dataset.csv
│   ├── olist_customers_dataset.csv
│   ├── olist_products_dataset.csv
│   ├── customer_df.csv
│   └── churn.sql
│
├── README.md
```

```

---

## Tech Stack

* Python (pandas, numpy, seaborn, matplotlib, scikit-learn)
* PostgreSQL
* SQL (CTEs, window functions)

---



## Conclusion

Churn in this dataset is not strongly driven by transactional metrics such as order count or delivery performance.
Instead, **temporal behavior (purchase timing)** provides the most meaningful signal, though overall predictability remains moderate.

---

## How to Run

1. Load raw data into PostgreSQL
2. Run `sql/churn.sql`
3. Open notebooks in order:

   * data preparation → feature engineering → analysis → modeling
