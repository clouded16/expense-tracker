from datetime import date
from feasibility import analyze_goal_feasibility


expenses = [
    {"amount": 1200, "date": date(2026, 1, 5)},
    {"amount": 1500, "date": date(2026, 1, 15)},
    {"amount": 1300, "date": date(2026, 2, 10)},
]

goal = {
    "id": 1,
    "target_amount": 120000,
    "target_date": date(2027, 1, 1)
}

today = date(2026, 2, 15)

result = analyze_goal_feasibility(expenses, goal, today)
print(result)
