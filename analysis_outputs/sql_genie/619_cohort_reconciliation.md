# 619 cohort — warehouse reconciliation vs Tab 2 (High-Ask) dashboard

This document ties the **published KPI (619)** to the **JavaScript definition** in `analysis_outputs/index.html` and gives **Databricks SQL** skeleton text to paste into Genie so warehouse counts match the shipped dashboard.

## What the dashboard actually measures

In `#tab-l4`, KPI **619** is bound to `L4_KPI_DATA[quarter].provs_gt3x_medicare` (see `l4RenderKpis` → `kpi5`).

The **funnel chart** (`l4CreateFunnel`) uses three **provider counts**:

| Bar label (UI) | JS field | Meaning |
|----------------|----------|---------|
| All elevated (≥ 2× federal benchmark) | `provs_gt2x` | Providers in ≥2× QPA universe |
| Extreme billing (≥ 6× federal benchmark) | `provs6x` | Providers in ≥6× QPA universe |
| Medicare-confirmed (≥ 3× Medicare rate) | `provs_gt3x_medicare` | **619** — providers passing **both** the extreme QPA gate used for bar 2 **and** the Medicare multiple gate |

So **619 is not** “any provider with ≥3× Medicare on any line in the extract.” It is the **provider count at the third funnel step**, i.e. the **intersection** of the dashboard’s **≥6× QPA provider population** with **Medicare offer multiple ≥ 3×** (non-null fee join), aligned to the same silver source and quarters used to build `L4_KPI_DATA`.

**Air ambulance:** Tab 2 narrative and KPIs here are built from the **OON Emergency / Non-Emergency** storyline. If Genie uses `fee_schedule_joined_oon_emergency_nonemergency` only, that matches this tab. **Do not** merge air-ambulance NPIs into this 619 without a separate panel.

**“Won most disputes”:** The hero copy says providers charged 6×+ **and won most** of their disputes. The numeric **619** comes from `provs_gt3x_medicare`, not from a separate win-rate filter in `L4_KPI_DATA`. If the warehouse cohort applies an extra win-rate condition, **NPI counts may diverge** from 619 — Genie should document that and either match the KPI or label the chart “distribution under stricter win-rate cohort.”

## Genie checklist (must pass before replacing embedded distribution JSON)

1. **Step counts:** After each CTE, report `COUNT(*)`, `COUNT(DISTINCT provider_npi)` (or your grain column).
2. **Intersection:** Show NPI set **A** = providers with ≥1 dispute at **≥6× vs QPA** (same field the pipeline uses for `disputes6x` / `provs6x`), **B** = lines with `provider_offer_as_pct_of_medicare >= 3` and not null. Final cohort = **A ∩ B** at provider grain.
3. **Match 619:** `COUNT(DISTINCT npi)` on the final cohort must equal **`L4_KPI_DATA.all.provs_gt3x_medicare`** (619) for the same quarter scope (all / Q1 / Q2 as applicable).
4. **If counts differ:** Do not overwrite dashboard embedded stats; fix SQL or document the delta in this file.

## SQL skeleton for Genie (Databricks SQL)

Replace catalog/schema/table/column names with your confirmed `fee_schedule_joined_oon_emergency_nonemergency` fields (see `medicare_fee_dashboard_update_plan.md` for column mapping).

```sql
-- Step 0: base dispute lines (Q1+Q2 2025, OON E+NE fee-joined silver only)
-- WITH base AS (
--   SELECT *
--   FROM idre.idre_silver.fee_schedule_joined_oon_emergency_nonemergency
--   WHERE ... quarter filter ...
-- ),

-- Step 1: lines in "6x QPA" extreme population (use SAME formula as pipeline for provider_offer / QPA multiple)
-- , extreme_6x AS (
--   SELECT *, <qpa_multiple_expr> AS qpa_mult
--   FROM base
--   WHERE <qpa_multiple_expr> >= 6
--     AND <winning_party / merit filters if any align with pipeline>
-- ),

-- Step 2: providers in 6x universe
-- , prov_6x AS (
--   SELECT DISTINCT Provider_Facility_NPI_Number AS npi
--   FROM extreme_6x
-- ),

-- Step 3: lines with valid Medicare multiple >= 3
-- , med_ge3 AS (
--   SELECT *
--   FROM base
--   WHERE provider_offer_as_pct_of_medicare IS NOT NULL
--     AND provider_offer_as_pct_of_medicare >= 3
-- ),

-- Step 4: dual cohort NPIs (intersection)
-- , dual_npi AS (
--   SELECT DISTINCT m.Provider_Facility_NPI_Number AS npi
--   FROM med_ge3 m
--   INNER JOIN prov_6x p ON p.npi = m.Provider_Facility_NPI_Number
-- )

-- SELECT COUNT(*) AS dual_npi_count FROM dual_npi;
-- Expect dual_npi_count = 619 for "all" scope when aligned to dashboard build.
```

## Embedded dashboard data

The Tab 2 **Sarah distribution** panel reads from `L4_619_DISTRIBUTION` and `L4_619_LOG_SCATTER` in `index.html`. Row-level export: **`analysis_outputs/cohort_619_audited.csv`** (`npi`, `name`, `n_lines`, `mean_medicare_mult`, `median_medicare_mult`, `win_rate`).

---

## Audited warehouse run (Genie — passed)

**Table:** `idre.idre_silver.fee_schedule_joined_oon_emergency_nonemergency` · **Grain:** `Provider_Facility_NPI_Number` · **Period:** `data_quarter IN ('Q1_2025','Q2_2025')`

- **Set A:** NPIs with ≥1 line where `TRY_CAST(Provider_Facility_Offer_as_of_QPA AS DOUBLE) >= 6` → **4,236** NPIs (842,565 lines).
- **Set B:** NPIs with ≥1 line where `provider_offer_as_pct_of_medicare IS NOT NULL AND >= 3` → **619** NPIs (8,053 lines).
- **Intersection:** **|A ∩ B| = 619**; empirically **B ⊆ A** (|B − A| = 0), so the published third funnel bar equals **Set B**.
- **Win-rate filter:** Not in KPI; with a provider-win filter applied, **572** NPIs remain (**47** dropped).
- **Thin lines:** **484 / 619** NPIs have **&lt;10** qualifying lines; **135** have ≥10.
- **Air ambulance:** Separate cohort **87** NPIs (different benchmark); **86** net-new vs 619, **1** overlap.

Funnel step counts (dispute lines / distinct NPIs) documented in Genie output: S0 2,747,354 / 11,530 → … → S4 **619** NPIs, S5 **8,053** qualifying lines for A∩B NPIs.

Dashboard copy and `L4_619_*` constants were updated to match this audit (including median-of-medians **4.36×** for Sarah vs mean-of-means **67.5×**).
