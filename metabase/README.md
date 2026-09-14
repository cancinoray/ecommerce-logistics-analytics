# Metabase reporting output

This directory holds everything needed to recreate the project's Metabase
state from scratch:

- `exports/` — the authoritative export of the 4 dashboards, 18 cards, and
  `tables.json` (the table/field name map used to remap live IDs).
- `setup_metabase.py` — replays the exports through the Metabase REST API.
  Python stdlib only. Run it with `docker compose run --rm metabase-init`
  (the one-shot `metabase-init` service in `docker-compose.yml`, #43).
- `Dockerfile` — the Metabase image with the ClickHouse driver pre-installed.

## Three analysis dashboards, not four

Four *dashboards* exist, but only **three are analysis dashboards**:

| Dashboard | Role |
|---|---|
| Executive Overview | analysis dashboard — *"How are we performing?"* (#31) |
| Problem Analysis | analysis dashboard — *"Where are the problems?"* (#32) |
| Root Cause & Drill-Down | analysis dashboard — *"Why are we seeing these problems?"* (#33) |
| Home | landing page / index of 3 link cards to the three analysis dashboards, set as the instance homepage (#42, #43) |

`_docs/plan.md` §9's "three dashboards" refers to the three analysis
dashboards. `Home` is a navigation page, not a fourth analysis dashboard,
and is preserved verbatim (its link cards are remapped to the recreated
dashboard IDs by name).

## Insight labels

Every dashboard and every card `description` carries at least one canonical
insight label. Every card description also names the single mart it reads.

- **Insight 1 — Delivery performance**: the six-value severity mix (On Time /
  1-3 days late / 4-7 days late / 8+ days late / Delivery data unavailable /
  Canceled or unavailable).
- **Insight 2 — Logistics cost**: freight vs order value, by seller,
  geography, and time.
- **Insight 3 — Seller performance**: on-time rate + order volume.
- **Insight 4 — Customer experience**: review score vs severity —
  association, not causation.
- **Insight 5 — Data quality**: kept separate from the score.

The six-value severity taxonomy (including `Canceled or unavailable`) comes
from #50. `Canceled or unavailable` and `Delivery data unavailable` are always
listed as their own buckets, never folded into a lateness bucket.

## Card → insight → mart map

| Card | Dashboard | Insight | Mart source |
|---|---|---|---|
| Logistics Performance Score & Components | Executive Overview | Insight 1 (composite) | `mart_logistics_performance_score` |
| Delivery KPIs | Executive Overview | Insight 1 | `fct_orders` |
| Customer Experience (Review Score) | Executive Overview | Insight 4 | `fct_orders` |
| Logistics Cost (Freight Ratio) | Executive Overview | Insight 2 | `fct_orders` |
| Seller Performance | Executive Overview | Insight 3 | `mart_seller_performance` |
| Data Quality | Executive Overview | Insight 5 | `mart_data_quality` |
| Trends — Order Volume & Review Score (MoM/YoY) | Executive Overview | Insight 1, Insight 4 | `fct_orders` |
| Late-Delivery Severity by Month | Problem Analysis | Insight 1 | `fct_orders` |
| On-Time Rate by Seller (Worst First) | Problem Analysis | Insight 3 | `mart_seller_performance` |
| Logistics Cost by Month | Problem Analysis | Insight 2 | `fct_orders` |
| Late-Delivery Severity by Customer State/City | Problem Analysis | Insight 1 | `fct_orders` |
| Freight Ratio by Seller | Problem Analysis | Insight 2 | `mart_seller_freight` |
| Freight Ratio by Customer State | Problem Analysis | Insight 2 | `fct_orders` |
| Review Score by Delivery Severity | Root Cause & Drill-Down | Insight 4 | `fct_orders` |
| Freight Ratio by Delivery Severity (Order-Level, from fct_orders) | Root Cause & Drill-Down | Insight 2 | `fct_orders` |
| Seller Drill-Down (Order Items, from fct_order_items joined to fct_orders) | Root Cause & Drill-Down | Insight 1, Insight 2, Insight 3, Insight 4 | `fct_order_items` joined to `fct_orders` |
| Location Drill-Down (Orders, from fct_orders) | Root Cause & Drill-Down | Insight 1, Insight 2 | `fct_orders` |
| Order Drill-Down (Order + Line Items, from fct_orders joined to fct_order_items) | Root Cause & Drill-Down | Insight 1, Insight 2, Insight 3, Insight 4 | `fct_orders` joined to `fct_order_items` |

All five insight labels appear above (Insight 1, 2, 3, 4, and 5).

## Dashboard-level filters

Filters are authored in the exports and replayed by `setup_metabase.py`.
IDs are transient; everything is resolved by name.

| Dashboard | Filters (name → slug) |
|---|---|
| Executive Overview | Month → `month` |
| Problem Analysis | Month → `month`; Customer State → `customer_state`; Seller ID → `seller_id` |
| Root Cause & Drill-Down | Month → `month`; Seller ID → `seller_id`; Customer City → `city`; Customer State → `state`; Order ID → `order_id` |
| Home | none |

Every query dashcard on the three analysis dashboards is wired to at least
one dashboard parameter; the only unmapped dashcard is the Root Cause
`Association only — not a causal claim` text card (#33, preserved verbatim).

Card-level filters (a `WHERE` predicate, explicitly allowed by plan.md §12 —
not recomputed business logic):

- `On-Time Rate by Seller (Worst First)` — `WHERE order_volume >= 5`, so a
  seller-month with only a handful of orders cannot top the worst-first
  ranking with a noisy 0–100% on-time rate (#28).
- `Late-Delivery Severity by Customer State/City` — accepts a `customer_state`
  filter mapped to the Problem Analysis `Customer State` parameter.

## Card defects fixed (#51)

- `Data Quality` now selects all four `pct_orders_*` metrics, including
  `pct_orders_canceled_or_unavailable` (#50).
- `Logistics Performance Score & Components` now surfaces `delivery_coverage`
  and `order_count` (#48), so a re-weighted month is not misread as a
  collapse.
- `Customer Experience (Review Score)` no longer averages the column it
  groups by (the breakout `review_score` is not an aggregation).
- `Logistics Cost (Freight Ratio)` renders all three aggregations it selects
  (a table, not a `scalar` with two aggregations).
- Two missing Insight 2 dimensions got cards: `Freight Ratio by Seller`
  (from `mart_seller_freight`, #49) and `Freight Ratio by Customer State`
  (from `fct_orders`), both on Problem Analysis and both wired to `Month`.

## No business logic in Metabase

Every question reads exactly one `fct_*` / `mart_*` table; none reads `stg_`
or `int_`. No `CASE` / scoring / normalization / classification is authored in
Metabase. The `fct_order_items ⋈ fct_orders` join in the two Root Cause
drill-downs is the exception explicitly permitted by #33.

## Replaying

```sh
docker compose run --rm metabase-init
```

`setup_metabase.py` is idempotent: it matches dashboards and cards by name,
reconciles dashboard-level `parameters` and matched cards'
`description` / `dataset_query` / `display` in place, and never duplicates
state on re-run. On a fresh instance, run `docker compose exec -T dbt dbt
build` first so the `marts` tables exist before `metabase-init`.
