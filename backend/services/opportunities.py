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


def identify_high_frequency_expenses(
    expenses: List[Dict]
) -> List[Dict]:
    """
    Identify small but frequent expenses that add up over time.
    """

    from collections import defaultdict

    monthly_counts = defaultdict(lambda: defaultdict(int))
    monthly_amounts = defaultdict(lambda: defaultdict(float))

    for expense in expenses:
        exp_date = expense["date"]
        key = (exp_date.year, exp_date.month)
        merchant = expense.get("merchant", expense["category"])

        monthly_counts[key][merchant] += 1
        monthly_amounts[key][merchant] += expense["amount"]

    opportunities = []

    for month, merchants in monthly_counts.items():
        for merchant, count in merchants.items():
            if count >= 8:  # frequency threshold
                avg_amount = monthly_amounts[month][merchant] / count

                opportunities.append({
                    "type": "high_frequency",
                    "title": f"Frequent spending on {merchant}",
                    "description": (
                        f"You made {count} transactions related to {merchant} "
                        f"in a single month. Reducing this slightly could save money."
                    ),
                    "estimated_monthly_savings": round(avg_amount * 2, 2),
                    "confidence": "medium"
                })

    return opportunities


def identify_recurring_patterns(
    expenses: List[Dict]
) -> List[Dict]:
    """
    Identify expenses that appear to recur monthly with similar amounts.
    """

    from collections import defaultdict

    merchant_history = defaultdict(list)

    for expense in expenses:
        merchant = expense.get("merchant", expense["category"])
        merchant_history[merchant].append({
            "amount": expense["amount"],
            "date": expense["date"]
        })

    opportunities = []

    for merchant, records in merchant_history.items():
        if len(records) < 3:
            continue

        amounts = [r["amount"] for r in records]
        avg_amount = sum(amounts) / len(amounts)

        similar = [
            amt for amt in amounts
            if abs(amt - avg_amount) <= 0.1 * avg_amount
        ]

        if len(similar) >= 3:
            opportunities.append({
                "type": "recurring_pattern",
                "title": f"Recurring charge from {merchant}",
                "description": (
                    f"Charges from {merchant} appear to repeat monthly "
                    f"with similar amounts. You may want to review this."
                ),
                "estimated_monthly_savings": round(avg_amount, 2),
                "confidence": "low"
            })

    return opportunities
