from datetime import date
from collections import defaultdict
from typing import List, Dict


def analyze_goal_feasibility(
    expenses: List[Dict],
    goal: Dict,
    today: date
) -> Dict:
    """
    Analyze whether a financial goal is feasible based on past spending.
    This function is pure logic: no DB, no API, no side effects.
    """

    target_date = goal["target_date"]
    target_amount = goal["target_amount"]

    # 1. Calculate months remaining
    months_remaining = (
        (target_date.year - today.year) * 12
        + (target_date.month - today.month)
    )

    if months_remaining <= 0:
        return {
            "goal_id": goal["id"],
            "months_remaining": 0,
            "required_monthly_savings": None,
            "observed_avg_monthly_spend": None,
            "feasibility_status": "not_achievable",
            "message": "The goal deadline has already passed."
        }

    # 2. Required monthly savings
    required_monthly_savings = target_amount / months_remaining

    # 3. Compute average monthly spending
    monthly_spend = defaultdict(float)

    for expense in expenses:
        exp_date = expense["date"]
        month_key = (exp_date.year, exp_date.month)
        monthly_spend[month_key] += expense["amount"]

    if not monthly_spend:
        avg_monthly_spend = 0.0
    else:
        avg_monthly_spend = sum(monthly_spend.values()) / len(monthly_spend)

    # 4. Feasibility classification (policy-based)
    if avg_monthly_spend == 0:
        feasibility = "achievable"
    elif required_monthly_savings <= 0.2 * avg_monthly_spend:
        feasibility = "achievable"
    elif required_monthly_savings <= 0.4 * avg_monthly_spend:
        feasibility = "tight"
    else:
        feasibility = "not_achievable"

    # 5. Human-readable explanation
    message = (
        f"To reach this goal, you need to save approximately "
        f"{required_monthly_savings:.2f} per month. "
        f"Your average monthly spending is {avg_monthly_spend:.2f}, "
        f"making this goal {feasibility.replace('_', ' ')} at your current pace."
    )

    return {
        "goal_id": goal["id"],
        "months_remaining": months_remaining,
        "required_monthly_savings": round(required_monthly_savings, 2),
        "observed_avg_monthly_spend": round(avg_monthly_spend, 2),
        "feasibility_status": feasibility,
        "message": message
    }
