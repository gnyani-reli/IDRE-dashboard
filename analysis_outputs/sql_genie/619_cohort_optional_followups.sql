-- Optional Genie follow-ups (after 619 cohort SQL is reconciled to dashboard KPI)
-- Run in Databricks SQL against the same silver table(s) as the 619 definition.

-- 1) Provider-level MEDIAN of provider_offer_as_pct_of_medicare (dispute-line median per NPI, then summarize across 619)
-- Compare to mean-based distribution already in the deck.

-- 2) Tail attribution: among disputes in dual cohort with provider_offer_as_pct_of_medicare >= 50,
--    group by HCPCS/CPT and rank by dispute count and (if available) dollars.

-- 3) Low-N flag: NPIs in dual cohort with fewer than 10 qualifying dispute lines (or fewer than K)
--    SELECT npi, COUNT(*) AS n_lines
--    FROM ...dual_cohort_lines...
--    GROUP BY npi
--    HAVING COUNT(*) < 10;

-- 4) Air ambulance sibling: repeat dual-style logic on fee_schedule_joined_oon_air_ambulance
--    with ambulance_benchmark_rate / analogous offer column — report NPI count separately.
