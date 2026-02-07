from collections import defaultdict
from typing import List, Dict


def identify_category_overspend_opportunities(
    expenses: List[Dict]
) -> List[Dict]:
    """
    Identify categories that consume a large portion of monthly spending
    and suggest gentle reduction opportunities.
    """

    # 1. Group expenses by (year, month, category)
    monthly_category_spend = defaultdict(lambda: defaultdict(float))
    monthly_total_spend = defaultdict(float)

    for expense in expenses:
        exp_date = expense["date"]
        category = expense["category"]
        amount = expense["amount"]

        month_key = (exp_date.year, exp_date.month)

        monthly_category_spend[month_key][category] += amount
        monthly_total_spend[month_key] += amount

    if not monthly_total_spend:
        return []

    # 2. Compute average monthly totals
    avg_monthly_total = sum(monthly_total_spend.values()) / len(monthly_total_spend)

    # 3. Compute average monthly spend per category
    category_monthly_totals = defaultdict(list)

    for month, categories in monthly_category_spend.items():
        for category, amount in categories.items():
            category_monthly_totals[category].append(amount)

    avg_category_spend = {
        category: sum(amounts) / len(amounts)
        for category, amounts in category_monthly_totals.items()
    }

    opportunities = []

    # 4. Identify overspend categories
    for category, avg_spend in avg_category_spend.items():
        share = avg_spend / avg_monthly_total

        if share >= 0.30:  # policy threshold
            estimated_savings = round(avg_spend * 0.15, 2)  # gentle 15%

            opportunities.append({
                "type": "category_overspend",
                "title": f"High spending on {category}",
                "description": (
                    f"On average, {category} makes up about "
                    f"{int(share * 100)}% of your monthly spending. "
                    f"Reducing this category slightly could help your goals."
                ),
                "estimated_monthly_savings": estimated_savings,
                "confidence": "medium"
            })

    return opportunities
