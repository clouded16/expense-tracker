from datetime import date
from opportunities import identify_category_overspend_opportunities
from opportunities import (
    identify_high_frequency_expenses,
    identify_recurring_patterns
)

expenses = [
    {"amount": 12000, "category": "Food", "date": date(2026, 1, 5)},
    {"amount": 8000, "category": "Food", "date": date(2026, 1, 15)},
    {"amount": 6000, "category": "Transport", "date": date(2026, 1, 20)},
    {"amount": 11000, "category": "Food", "date": date(2026, 2, 10)},
    {"amount": 7000, "category": "Transport", "date": date(2026, 2, 12)},
    {"amount": 499, "merchant": "Netflix", "category": "OTT", "date": date(2025, 12, 1)},
    {"amount": 499, "merchant": "Netflix", "category": "OTT", "date": date(2026, 1, 1)},
    {"amount": 499, "merchant": "Netflix", "category": "OTT", "date": date(2026, 2, 1)},
]


result = identify_category_overspend_opportunities(expenses)
print(result)


result_freq = identify_high_frequency_expenses(expenses)
result_recurring = identify_recurring_patterns(expenses)

print("High Frequency:", result_freq)
print("Recurring:", result_recurring)
