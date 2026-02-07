from datetime import date
from opportunities import identify_category_overspend_opportunities


expenses = [
    {"amount": 12000, "category": "Food", "date": date(2026, 1, 5)},
    {"amount": 8000, "category": "Food", "date": date(2026, 1, 15)},
    {"amount": 6000, "category": "Transport", "date": date(2026, 1, 20)},
    {"amount": 11000, "category": "Food", "date": date(2026, 2, 10)},
    {"amount": 7000, "category": "Transport", "date": date(2026, 2, 12)},
]


result = identify_category_overspend_opportunities(expenses)
print(result)
