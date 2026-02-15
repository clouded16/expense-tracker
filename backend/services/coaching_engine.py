from datetime import date
from typing import Callable, Dict, List, Sequence

from services.feasibility import analyze_goal_feasibility
from services.opportunities import (
    identify_category_overspend_opportunities,
    identify_high_frequency_expenses,
    identify_recurring_patterns,
)

InsightDict = Dict[str, object]
Signal = Callable[[List[Dict], Dict, date], List[InsightDict]]



def feasibility_signal(expenses: List[Dict], goal: Dict, today: date) -> List[InsightDict]:
    result = analyze_goal_feasibility(expenses=expenses, goal=goal, today=today)

    status = result["feasibility_status"]
    priority_by_status = {
        "achievable": "low",
        "tight": "medium",
        "not_achievable": "high",
    }
    score_by_status = {
        "achievable": 20,
        "tight": 65,
        "not_achievable": 95,
    }

    return [
        {
            "type": "feasibility",
            "priority": priority_by_status.get(status, "medium"),
            "title": "Goal feasibility check",
            "message": result["message"],
            "metadata": {
                "goal_id": result["goal_id"],
                "feasibility_status": status,
                "months_remaining": result["months_remaining"],
                "required_monthly_savings": result["required_monthly_savings"],
                "observed_avg_monthly_spend": result["observed_avg_monthly_spend"],
            },
            "score": score_by_status.get(status, 50),
        }
    ]



def overspend_signal(expenses: List[Dict], goal: Dict, today: date) -> List[InsightDict]:
    del goal, today
    opportunities = identify_category_overspend_opportunities(expenses)

    insights: List[InsightDict] = []
    for opportunity in opportunities:
        estimated_savings = float(opportunity["estimated_monthly_savings"])
        score = max(30, min(90, int(estimated_savings / 10) + 30))

        insights.append(
            {
                "type": "overspend",
                "priority": "medium",
                "title": opportunity["title"],
                "message": opportunity["description"],
                "metadata": {
                    "estimated_monthly_savings": estimated_savings,
                    "raw_signal_type": opportunity["type"],
                },
                "score": score,
            }
        )

    return insights



def frequency_signal(expenses: List[Dict], goal: Dict, today: date) -> List[InsightDict]:
    del goal, today
    opportunities = identify_high_frequency_expenses(expenses)

    insights: List[InsightDict] = []
    for opportunity in opportunities:
        estimated_savings = float(opportunity["estimated_monthly_savings"])
        score = max(35, min(85, int(estimated_savings / 5) + 35))

        insights.append(
            {
                "type": "frequency",
                "priority": "medium",
                "title": opportunity["title"],
                "message": opportunity["description"],
                "metadata": {
                    "estimated_monthly_savings": estimated_savings,
                    "raw_signal_type": opportunity["type"],
                },
                "score": score,
            }
        )

    return insights



def recurring_signal(expenses: List[Dict], goal: Dict, today: date) -> List[InsightDict]:
    del goal, today
    opportunities = identify_recurring_patterns(expenses)

    insights: List[InsightDict] = []
    for opportunity in opportunities:
        estimated_savings = float(opportunity["estimated_monthly_savings"])
        score = max(45, min(95, int(estimated_savings / 5) + 45))

        insights.append(
            {
                "type": "recurring",
                "priority": "high" if score >= 80 else "medium",
                "title": opportunity["title"],
                "message": opportunity["description"],
                "metadata": {
                    "estimated_monthly_savings": estimated_savings,
                    "raw_signal_type": opportunity["type"],
                },
                "score": score,
            }
        )

    return insights


DEFAULT_SIGNALS: Sequence[Signal] = (
    feasibility_signal,
    overspend_signal,
    recurring_signal,
    frequency_signal,
)



def generate_coaching_insights(
    expenses: List[Dict],
    goal: Dict,
    today: date,
    signals: Sequence[Signal] | None = None,
) -> List[InsightDict]:
    configured_signals = signals or DEFAULT_SIGNALS

    insights: List[InsightDict] = []
    for signal in configured_signals:
        insights.extend(signal(expenses, goal, today))

    insights.sort(key=lambda insight: int(insight["score"]), reverse=True)

    return insights
