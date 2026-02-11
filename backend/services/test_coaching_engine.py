from datetime import date

from services.coaching_engine import generate_coaching_insights


def test_generate_coaching_insights_returns_universal_shape_and_ranking():
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

    goal = {
        "id": 1,
        "target_amount": 120000,
        "target_date": date(2026, 12, 1),
    }

    insights = generate_coaching_insights(expenses=expenses, goal=goal, today=date(2026, 2, 15))

    assert insights, "Expected at least one insight"

    valid_types = {"overspend", "recurring", "feasibility", "frequency"}
    valid_priorities = {"low", "medium", "high"}

    for insight in insights:
        assert set(insight.keys()) == {
            "type",
            "priority",
            "title",
            "message",
            "metadata",
            "score",
        }
        assert insight["type"] in valid_types
        assert insight["priority"] in valid_priorities
        assert isinstance(insight["title"], str)
        assert isinstance(insight["message"], str)
        assert isinstance(insight["metadata"], dict)
        assert isinstance(insight["score"], int)

    scores = [insight["score"] for insight in insights]
    assert scores == sorted(scores, reverse=True)


def test_generate_coaching_insights_is_pluggable():
    def custom_signal(expenses, goal, today):
        del expenses, goal, today
        return [
            {
                "type": "frequency",
                "priority": "high",
                "title": "Custom signal",
                "message": "Custom explainable signal",
                "metadata": {"source": "custom"},
                "score": 99,
            }
        ]

    insights = generate_coaching_insights(
        expenses=[],
        goal={"id": 1, "target_amount": 1000, "target_date": date(2027, 1, 1)},
        today=date(2026, 1, 1),
        signals=[custom_signal],
    )

    assert insights == [
        {
            "type": "frequency",
            "priority": "high",
            "title": "Custom signal",
            "message": "Custom explainable signal",
            "metadata": {"source": "custom"},
            "score": 99,
        }
    ]
