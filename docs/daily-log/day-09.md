# Day 9 – Goals Persistence

## What was built
- GoalCreate and GoalResponse API models
- Goal ORM table wired to database
- POST /goals endpoint
- GET /goals endpoint
- Persistent storage for user goals

## Key decisions
- Goals stored separately from expenses
- Explicit ORM to API mapping
- Same DB session pattern as expenses

## What I learned
- How intent (goals) complements factual data (expenses)
- How shared infrastructure reduces new complexity
- Why clean wiring enables future analytics easily

## Status
Day 9 completed successfully. System now stores both expenses and goals.
