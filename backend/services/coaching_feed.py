from typing import List, Dict


def build_coaching_feed(
    feasibility: Dict,
    opportunities: List[Dict]
) -> List[Dict]:
    """
    Combine feasibility insight and opportunities into a unified coaching feed.
    """

    feed = []

    # 1. Add feasibility insight
    feed.append({
        "type": "feasibility",
        "priority": (
            "high"
            if feasibility["feasibility_status"] == "not_achievable"
            else "medium"
        ),
        "title": "Goal feasibility check",
        "message": feasibility["message"],
        "metadata": {
            "months_remaining": feasibility["months_remaining"],
            "required_monthly_savings": feasibility["required_monthly_savings"]
        }
    })

    # 2. Add opportunities
    for opp in opportunities:
        feed.append({
            "type": opp["type"],
            "priority": opp.get("confidence", "low"),
            "title": opp["title"],
            "message": opp["description"],
            "metadata": {
                "estimated_monthly_savings": opp["estimated_monthly_savings"]
            }
        })

    return feed
