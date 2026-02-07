# Day 8 – Database Integration (Expenses)

## What was built
- SQLite database setup
- SQLAlchemy engine and session management
- ORM models for Expense and Goal
- Table creation on app startup
- Persistent POST and GET /expenses endpoints

## Key decisions
- Separated API models from ORM models
- Stored raw merchant data for future analytics
- Explicit mapping between DB objects and API responses

## Issues faced
- Missing SQLAlchemy dependency
- ResponseValidationError due to API/DB mismatch

## What I learned
- Why persistence layers must be isolated
- How FastAPI enforces response contracts
- Why explicit mapping prevents future breakage

## Status
Day 8 completed successfully. Backend now persists expenses reliably.
