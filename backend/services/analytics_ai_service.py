from __future__ import annotations

from typing import Any

from sqlalchemy.orm import Session

from services.analytics_service import (
    get_category_breakdown,
    get_financial_summary,
    get_monthly_expenses,
    get_savings_trend,
)


def get_ai_insights(db: Session, user_id: int) -> dict[str, Any]:
    monthly = get_monthly_expenses(db, user_id, months=3)
    categories = get_category_breakdown(db, user_id)
    savings_trend = get_savings_trend(db, user_id, months=3)
    summary = get_financial_summary(db, user_id)

    insights: list[str] = []

    if len(monthly) >= 2 and monthly[-2]["total"] > 0:
        prev = monthly[-2]["total"]
        curr = monthly[-1]["total"]
        delta_pct = ((curr - prev) / prev) * 100
        if abs(delta_pct) >= 1:
            trend_word = "more" if delta_pct > 0 else "less"
            insights.append(
                f"You spent {abs(delta_pct):.0f}% {trend_word} this month compared to last month."
            )

    if categories:
        top_category = categories[0]
        potential_save = top_category["amount"] * 0.10
        insights.append(
            f"You could save Rs {potential_save:.0f}/month by reducing {top_category['category']} spending."
        )

    monthly_budget = summary["monthly_budget"]
    if monthly_budget > 0:
        budget_used = (summary["total_spent"] / monthly_budget) * 100
        insights.append(f"You are spending {budget_used:.0f}% of your monthly budget.")

    if len(categories) >= 2:
        insights.append(
            f"{categories[0]['category']} is your largest category. Consider balancing discretionary expenses."
        )

    latest_savings = savings_trend[-1]["savings"] if savings_trend else 0.0
    savings_rate = (latest_savings / monthly_budget) if monthly_budget > 0 else 0.0
    stability_score = 70
    if len(monthly) >= 3:
        totals = [x["total"] for x in monthly]
        avg = sum(totals) / len(totals) if totals else 0
        if avg > 0:
            volatility_ratio = (max(totals) - min(totals)) / avg
            stability_score = max(30, min(95, int(100 - volatility_ratio * 60)))
    savings_score = max(0, min(100, int(savings_rate * 200)))
    diversity_score = max(20, 100 - int((categories[0]["amount"] / sum(c["amount"] for c in categories)) * 100)) if categories else 50
    financial_health_score = int((savings_score * 0.45) + (stability_score * 0.35) + (diversity_score * 0.20))
    financial_health_score = max(0, min(100, financial_health_score))

    if monthly_budget > 0:
        insights.append(f"You saved {(savings_rate * 100):.0f}% of your budget this month.")
    insights.append("Your savings rate is healthy." if savings_rate >= 0.2 else "Your savings rate can improve with small spending adjustments.")

    return {
        "financial_health_score": financial_health_score,
        "insights": insights[:6],
    }
