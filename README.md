# E-Commerce Logistics Analytics

## Objective

This project builds an analytics-engineering pipeline for the **Olist Brazilian E-Commerce Public Dataset**, focused on logistics performance: delivery speed, freight cost, seller performance, customer experience, and data quality. It uses ClickHouse, dbt, and Metabase, all running locally via Docker.

You can check the source of data here: [https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)

---

## 💭 Problem Statement

The main business question is:

> **How is our logistics operation performing, where are the problems, and why are those problems happening?**

The analytical flow is:

```text
How are we doing?
        ↓
Where are the problems?
        ↓
Why are we seeing them?
```

The intended users are:

- Management / executives
- E-commerce operations
- Logistics operations

### Key Insights:

1. **Delivery Performance**:
   - Classify orders as on time, 1–3 days late, 4–7 days late, or 8+ days late against the estimated delivery date.
   - Orders without usable delivery dates are flagged as "delivery data unavailable" rather than assumed late.

2. **Logistics Cost**:
   - Analyze freight value relative to order value across sellers, geography, and time.

3. **Seller Performance**:
   - Track on-time delivery rate and order volume per seller to identify strong and weak performers.

4. **Customer Experience**:
   - Compare review scores across delivery-severity groups to see whether delays are associated with lower ratings (correlation, not causation).

5. **Data Quality**:
   - Surface missing/unusable delivery dates and other data-quality gaps as their own metric, kept separate from the logistics performance score.

---

## 🚀 Pipeline Overview

1. **Data Ingestion**
   - Load the 9 Olist CSVs verbatim into ClickHouse's `raw` database using `scripts/load_raw.sh` (no renaming/transformation/dedup at this stage).

2. **Staging (`dbt/models/staging`)**
   - One `stg_*` model per source table: column renaming, type casting, standardization.

3. **Intermediate (`dbt/models/intermediate`)**
   - `int_*` models: delivery delay/severity calculations, freight metrics, seller performance metrics, customer experience metrics, and data-quality flags. Not meant to be queried directly.

4. **Marts (`dbt/models/marts`)**
   - Business-facing `fct_*`/`dim_*` tables that Metabase queries.

5. **Data Modeling**
   - dbt models are materialized as views (staging, intermediate) or tables (marts) in ClickHouse, with `unique`/`not_null`/`relationships`/`accepted_values` and business-rule tests.

6. **Visualization**
   - Dashboards built in Metabase, backed only by marts.

7. **Infrastructure**
   - ClickHouse, dbt, and Metabase run as services via `docker-compose.yml`; no orchestrator (no Airflow) is used for this V1.

---

## 🗂 Project Structure

```
.
├── dbt/
│   ├── models/
│   │   ├── staging/       # stg_*   1:1 with a source table, light cleaning only
│   │   ├── intermediate/  # int_*   joins/aggregations, not queried directly
│   │   └── marts/         # fct_*, dim_*   final tables Metabase queries
│   ├── tests/             # custom singular tests (assert_*.sql)
│   ├── macros/
│   ├── seeds/
│   ├── snapshots/
│   ├── profiles.yml
│   ├── dbt_project.yml
│   ├── packages.yml
│   ├── package-lock.yml
│   ├── pyproject.toml
│   ├── uv.lock
│   ├── Dockerfile
│   └── entrypoint.sh
├── scripts/
│   └── load_raw.sh        # one-time load of the Olist CSVs into ClickHouse
├── data/                  # Olist CSV source files
├── _docs/
│   ├── plan.md             # the current product/data spec
│   ├── process.md          # how work is organized
│   ├── task-template.md    # template used when grooming issues
│   └── team/                # role definitions for PM / analytics engineer / QA
├── logs/
├── docker-compose.yml
├── AGENTS.md
└── README.md
```

### Quick Summary:

- **ClickHouse**: Analytical warehouse holding raw, staging, intermediate, and mart data.
- **dbt (`dbt/`)**: Handles all SQL transformations and business logic inside ClickHouse.
- **Metabase**: Dashboards and exploration, querying marts only.
- **Scripts (`scripts/`)**: One-time raw data load from CSV into ClickHouse.
- **Docker & configs**: Makes everything containerized and easy to run locally.
- **Documentation (`_docs/`, `AGENTS.md`)**: Process, spec, and role guides for the project.

---

## 🛠️ Technologies Used

- **ClickHouse**: Analytical (OLAP) warehouse for raw, staging, intermediate, and mart data.
- **dbt (Data Build Tool)**: Models and transforms data inside ClickHouse; owns all business logic.
- **Metabase**: Dashboards, filters, and exploration on top of dbt marts.
- **Docker / Docker Compose**: Runs ClickHouse, dbt, and Metabase locally as containers.
- **uv**: Python dependency and virtual environment management for the dbt container.
- **Olist Public Dataset**: Source e-commerce/logistics data (9 CSV files).

---

## ⚙️ Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/cancinoray/ecommerce-logistics-analytics
cd ecommerce-logistics-analytics
```

### 2. Get the Data

Download the [Olist Brazilian E-Commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) and place the 9 CSV files in `./data/`:

```
data/
├── olist_customers_dataset.csv
├── olist_geolocation_dataset.csv
├── olist_order_items_dataset.csv
├── olist_order_payments_dataset.csv
├── olist_order_reviews_dataset.csv
├── olist_orders_dataset.csv
├── olist_products_dataset.csv
├── olist_sellers_dataset.csv
└── product_category_name_translation.csv
```

### 3. Start ClickHouse, dbt, and Metabase

```bash
docker compose up -d
```

### 4. Load Raw Data into ClickHouse

```bash
./scripts/load_raw.sh
```

This creates the `raw` database in ClickHouse and loads all 9 CSVs verbatim (no transformation).

### 5. Run dbt

```bash
docker compose exec dbt dbt run     # run all models
docker compose exec dbt dbt test    # run all tests
docker compose exec dbt dbt build   # run + test in DAG order
```

Run or test a single model with `--select <model>`.

### 6. Access Services

- **ClickHouse SQL shell**:
  ```bash
  docker compose exec clickhouse clickhouse-client -u analytics --password analytics
  ```
  HTTP interface at `localhost:8123`, native protocol at `localhost:9000`, database `analytics`.

- **Metabase UI**: [http://localhost:3000](http://localhost:3000)
  First run asks you to set up an admin account. To add ClickHouse as a data source, first download the [ClickHouse Metabase driver](https://github.com/ClickHouse/metabase-clickhouse-driver) jar into the Metabase plugins volume — it's a community plugin, not bundled by default.

---

## 🔄 Workflow

- `scripts/load_raw.sh`: Loads Olist CSVs into ClickHouse's `raw` database.
- `dbt run` / `dbt test` / `dbt build`: Transforms raw data through staging → intermediate → marts, and validates it.
- Metabase: Queries marts only, for dashboards and exploration.

---

## 🔐 Security

- ClickHouse and Metabase use insecure default credentials (`analytics` / `analytics`) intended only for local/portfolio use — do not reuse them in a real deployment.
- Do not commit any sensitive information (credentials, `.env` files with real secrets).

---

## 🙌 Acknowledgements

Built on the [Olist Brazilian E-Commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce).
