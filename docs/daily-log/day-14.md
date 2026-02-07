# Day 14 – Unified Coaching Feed

## What was built
- Coaching feed service to aggregate insights
- Unified feed combining feasibility and opportunities
- Read-only API endpoint: /coaching-feed/{goal_id}
- Defensive handling for optional merchant data

## Key decisions
- Orchestration layer instead of duplicating logic
- Single feed abstraction for UX clarity
- No persistence of derived insights

## Issues faced
- Import typo
- Missing merchant attribute in Expense ORM

## What I learned
- How data maturity affects intelligence layers
- Why defensive mapping prevents breakage
- How orchestration improves system coherence

## Status
Day 14 completed successfully. System now delivers unified coaching insights.
