# Day 11 – Goal Feasibility Insight API

## What was built
- Feasibility response model
- /goals/{id}/feasibility endpoint
- DB → service → API data flow
- Read-only derived insights

## Key decisions
- Feasibility treated as computed data
- No DB writes for insights
- Service layer reused without modification

## Issues faced
- Missing feasibility response model file
- Python module resolution error

## What I learned
- Importance of package structure
- Why insights should not be persisted
- How to expose reasoning safely via APIs

## Status
Day 11 completed successfully. System now provides goal feasibility insights.
