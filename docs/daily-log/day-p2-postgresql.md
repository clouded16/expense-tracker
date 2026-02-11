# Day P2 – PostgreSQL Integration (Retrospective)

## Context
This log documents the PostgreSQL integration work that was completed during Day P2
but not logged day-wise at the time. The goal of this entry is to preserve architectural
decisions, reasoning, and implementation steps for future reference and evaluation.

---

## Objectives
- Introduce a production-grade relational database
- Replace mock/in-memory data with persistent storage
- Establish clean ORM boundaries
- Prepare backend for analytics and intelligence layers

---

## Key Decisions
- Chose PostgreSQL for reliability, relational integrity, and production alignment
- Used SQLAlchemy ORM for database abstraction
- Avoided auto table creation on app startup
- Treated database schema as an explicit contract

---

## Database Schema Introduced
- merchant
- category
- source
- expense_draft
- expense

Key characteristics:
- Foreign key relationships enforced at DB level
- Timestamps added for traceability
- Draft vs approved expense separation maintained

---

## Environment & Security
- Database credentials stored in `.env`
- `.env` excluded via `.gitignore`
- `venv` excluded from version control
- No secrets committed to repository

---

## Backend Integration
- Database engine initialized via SQLAlchemy
- Session dependency injected into FastAPI routes
- `/expenses` endpoint migrated to real DB operations
- `/health` endpoint validates DB connectivity

---

## Validation & Testing
- Manual SQL execution via pgAdmin
- ORM insert tests via Python scripts
- Health check endpoint used to confirm runtime DB access

---

## Outcome
- Backend is now fully DB-backed
- Schema is stable and production-aligned
- Foundation is ready for intelligence / coaching layer

---

## Notes for Future Work
- Introduce Alembic for migrations
- Add indexes for analytics queries
- Expand schema for subscriptions and recurring charges
