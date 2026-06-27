# Airbnb Analytics — dbt + Snowflake Project

A dbt project built on Snowflake that transforms raw Airbnb data into analytics-ready models. It covers core dbt concepts including dimensional modeling, incremental loading, snapshots, testing, macros, hooks, grants, and documentation.

---

## Table of Contents

- [Overview](#overview)
- [Project Structure](#project-structure)
- [Data Models](#data-models)
- [Hooks and Grants](#hooks-and-grants)
- [Macros](#macros)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Running the Project](#running-the-project)
- [Testing](#testing)
- [Documentation](#documentation)
- [Project Architecture](#project-architecture)
- [What I Learned](#what-i-learned)

---

## Overview

This project takes raw Airbnb data (hosts, listings, reviews) loaded into Snowflake and transforms it through a layered architecture into clean, tested, analytics-ready tables.

**Stack**: dbt Core + Snowflake

**Concepts covered**:
- Source definitions and freshness checks
- Ephemeral, table, and incremental materializations
- Dimensional modeling (star schema)
- Slowly Changing Dimensions via snapshots (SCD Type 2)
- Generic, singular, custom generic, and dbt-expectations tests
- Source-level tests
- Custom macros including schema name generation and environment teardown
- Post-run audit logging via hooks
- Automated role-based grants on model build
- Seed files
- Variable-driven incremental loads
- dbt documentation and lineage graph

---

## Project Structure

```
airbnb/
├── models/
│   ├── src/                      # Source models (ephemeral)
│   │   ├── src_hosts.sql
│   │   ├── src_listings.sql
│   │   └── src_reviews.sql
│   ├── dim/                      # Dimension tables
│   │   ├── dim_hosts_cleansed.sql
│   │   ├── dim_listings_cleansed.sql
│   │   └── dim_listings_w_hosts.sql
│   ├── fct/                      # Fact tables
│   │   └── fct_reviews.sql
│   ├── mart/                     # Mart/reporting models
│   │   └── mart_fullmoon_reviews.sql
│   ├── schema.yml
│   └── sources.yml
├── tests/
│   ├── consistent_created_at.sql
│   ├── dim_listings_minimum_nights.sql
│   └── generic/
│       ├── minimum_row_count.sql
│       └── positive_values.sql
├── macros/
│   ├── select_positive_values.sql
│   ├── no_empty_strings.sql
│   ├── drop_dev_schemas.sql
│   ├── variables.sql
│   └── get_custom_name/
│       └── get_custom_schema.sql
├── seeds/
│   └── seed_full_moon_dates.csv
├── snapshots/
│   ├── raw_hosts_snapshot.yml
│   └── raw_listings_snapshot.yml
├── dbt_project.yml
├── profiles.yml                  # Not committed — see Configuration
└── packages.yml
```

---

## Data Models

### Source Models (`src/`)
**Materialization**: Ephemeral

Thin wrappers over the raw Snowflake tables. These compile to CTEs and don't create any database objects — just a clean abstraction layer before cleansing.

- `src_hosts` — raw host records
- `src_listings` — raw listings with pricing
- `src_reviews` — raw review events with timestamps

### Dimension Models (`dim/`)
**Materialization**: Table

- `dim_hosts_cleansed` — deduplication, null name handling (defaulted to `Anonymous`)
- `dim_listings_cleansed` — price cast to numeric, minimum nights validated, room type categorized
- `dim_listings_w_hosts` — denormalized join of listings and host info for downstream use

### Fact Models (`fct/`)
**Materialization**: Incremental

- `fct_reviews` — review events with surrogate keys generated via `dbt_utils.generate_surrogate_key`. Supports two incremental load modes depending on whether date range variables are passed at runtime (see Incremental Logic below). Schema drift is caught with `on_schema_change='fail'`.

### Mart Models (`mart/`)
**Materialization**: Table

- `mart_fullmoon_reviews` — joins review data with seed full moon dates to enable analysis of review sentiment patterns around full moon periods.

---

## Incremental Logic (`fct_reviews`)

The incremental model supports two load modes controlled by runtime variables:

```sql
{% if is_incremental() %}
  {% if var("start_date", False) and var("end_date", False) %}
    {{ log('Loading ' ~ this ~ ' incrementally (start_date: ' ~ var("start_date") ~ ', end_date: ' ~ var("end_date") ~ ')', info=True) }}
    AND review_date >= '{{ var("start_date") }}'
    AND review_date <  '{{ var("end_date") }}'
  {% else %}
    {{ log('Loading ' ~ this ~ ' incrementally (all missing dates)', info=True) }}
    AND review_date > (SELECT MAX(review_date) FROM {{ this }})
  {% endif %}
{% endif %}
```

**Date range mode** — pass `start_date` and `end_date` vars to load a specific window:
```bash
dbt run --select fct_reviews --vars '{"start_date": "2024-01-01", "end_date": "2024-02-01"}'
```

**Default mode** — omit the vars and only new rows beyond the current max date are loaded:
```bash
dbt run --select fct_reviews
```

Use `dbt run --full-refresh` to rebuild from scratch.

---

## Hooks and Grants

All models in this project are configured with a post-run hook and automated role grants at the project level via `dbt_project.yml`.

### Audit Logging

After every successful model build, a record is inserted into an `audit_log` table:

```sql
INSERT INTO {{ target.schema }}.audit_log (model_name, run_timestamp)
VALUES ('{{ this.name }}', CURRENT_TIMESTAMP)
```

This gives a full run history of which models executed and when, without needing an external orchestration tool to track it.

### Role Grants

On every model build, `SELECT` is automatically granted to the `transform` and `reporter` roles:

```yaml
grants:
  select: ['transform', 'reporter']
```

This ensures downstream consumers always have access to the latest version of a model without manual permission management after each run.

---

## Macros

| Macro | Purpose |
|-------|---------|
| `generate_schema_name` | Overrides dbt's default schema naming to support custom schema routing per environment |
| `generate_schema_name_for_env` | Environment-aware variant that routes dev and prod schemas separately |
| `drop_dev_schemas` | Tears down all dev schemas — useful for cleanup between runs in development |
| `no_empty_strings` | Reusable macro that filters out empty string values in model logic |
| `select_positive_values` | Reusable macro used by the `positive_values` custom generic test |
| `learn_variables` | Demonstrates dbt variable usage patterns |

---

## Prerequisites

- Python 3.10+
- A Snowflake account with a warehouse, database, and schema set up
- Git

---

## Installation

```bash
# Clone the repo
git clone https://github.com/joshuachris1107/dbt-airbnb-project
cd airbnb

# Create and activate virtual environment
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

Key packages:
- `dbt-core >= 1.11.0`
- `dbt-snowflake >= 1.11.0`
- `dbt-utils >= 1.3.0`
- `dbt-expectations >= 0.10.0`

---

## Configuration

Create `~/.dbt/profiles.yml` with your Snowflake credentials:

```yaml
airbnb:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: [your-account-id]
      user: [your-username]
      password: [your-password]
      role: [your-role]
      database: [your-database]
      schema: [your-dev-schema]
      warehouse: [your-warehouse]
      threads: 4
      client_session_keep_alive: False
```

> **Note**: `profiles.yml` is gitignored. Never commit credentials.

---

## Running the Project

```bash
# Validate connection and config
dbt debug

# Run all models
dbt run

# Run a specific model
dbt run --select dim_listings_cleansed

# Full refresh (rebuilds all incremental models from scratch)
dbt run --full-refresh

# Run models with upstream and downstream dependencies
dbt run --select +fct_reviews+

# Run with date range variables (incremental window load)
dbt run --select fct_reviews --vars '{"start_date": "2024-01-01", "end_date": "2024-02-01"}'

# Run snapshots
dbt snapshot

# Check source freshness
dbt source freshness

# Tear down dev schemas
dbt run-operation drop_dev_schemas

# Generate and serve docs
dbt docs generate
dbt docs serve
```

---

## Testing

```bash
# Run all tests
dbt test

# Run tests for a specific model
dbt test --select dim_hosts_cleansed

# Stop on first failure
dbt test --fail-fast
```

Test failures are stored in a `test_failures` schema for debugging.

### Test types used in this project

| Type | Examples |
|------|----------|
| Generic (built-in) | `unique`, `not_null`, `relationships`, `accepted_values` |
| Custom singular | `consistent_created_at`, `dim_listings_minimum_nights` |
| Custom generic | `positive_values` (minimum_nights > 0), `minimum_row_count` (dim_listings_cleansed >= 1000 rows) |
| dbt-expectations | `expect_column_quantile_values_to_be_between` (price p99 between $50-$500), `expect_column_max_to_be_between` (price max <= $5,000), `expect_column_values_to_be_of_type` (price is numeric), `expect_table_row_count_to_equal_other_table` (dim_listings_w_hosts row count matches source), `expect_column_distinct_count_to_equal` (4 distinct room types on source), `expect_column_values_to_match_regex` (price format matches `^\\$[0-9][0-9\\.]+$` on source) |

Note: the last two dbt-expectations tests run directly against the `airbnb.listings` source, not a model — validating data quality at ingestion before any transformation runs.

---

## Documentation

```bash
dbt docs generate
dbt docs serve
# Visit http://localhost:8080
```

The docs site includes model descriptions, column definitions, the full lineage DAG, and test coverage per model.

---

## Project Architecture

### Lineage Graph

![Airbnb dbt Lineage DAG](./lineage_dag.svg)

### Materialization Strategy

| Layer | Materialization | Reason |
|-------|-----------------|--------|
| `src_*` | Ephemeral | No DB objects needed; pure abstraction layer |
| `dim_*` | Table | Stable dimensions, fully rebuilt each run |
| `fct_*` | Incremental | Append-only events; efficient for large volumes |
| `mart_*` | Table | Business-ready; optimised for reporting queries |

---

## What I Learned

A few things worth noting about the design decisions made in this project:

**Materialization trade-offs matter more than I expected.** Choosing between ephemeral, table, and incremental isn't just a performance decision — it shapes how you think about your DAG and what objects actually exist in your warehouse.

**Snapshots are elegant but specific.** SCD Type 2 tracking via `dbt snapshot` is clean to implement, but understanding when to use it (slowly changing attributes you need history on, not event data) took a bit to internalize.

**The testing layer is what makes dbt production-grade.** Generic tests are easy to add but custom singular and generic tests are where you encode actual business logic. Writing `consistent_created_at` and `dim_listings_minimum_nights` made the data quality story feel real. Adding dbt-expectations on top — particularly cross-table row count parity and source-level regex validation — pushed the test suite closer to what you'd expect in a real pipeline.

**Hooks and grants remove operational toil.** Manually tracking which models ran and when, or re-granting permissions after a full refresh, are exactly the kinds of things that get missed in production. Encoding both into the project config means they happen automatically on every run.

**Incremental models require more thought than they look.** `on_schema_change='fail'` is a simple flag but it forces you to be intentional about schema evolution. Adding variable-driven date range support on top of the default max-date pattern means the model can handle both scheduled incremental loads and ad hoc backfills without a full refresh.

**Custom schema routing matters in team environments.** Overriding `generate_schema_name` to control where models land per environment is a small change that prevents a lot of confusion when multiple developers share a Snowflake account.

---

**Stack**: dbt Core 1.11+ · Snowflake · dbt-utils · dbt-expectations