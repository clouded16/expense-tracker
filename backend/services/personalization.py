from datetime import datetime, timedelta
from typing import List, Dict


def apply_personalization(
    feed: List[Dict],
    feedback_entries: List[Dict]
) -> List[Dict]:
    """
    Adjust coaching feed order and visibility based on user feedback.
    """

    # Build lookup for feedback
    feedback_map = {}
    for fb in feedback_entries:
        key = (fb["insight_type"], fb["insight_reference"])
        feedback_map[key] = fb

    personalized_feed = []

    for item in feed:
        score = 0

        # 1. Base priority
        if item["priority"] == "high":
            score += 30
        elif item["priority"] == "medium":
            score += 20
        else:
            score += 10

        # 2. Confidence boost
        if item.get("priority") == "medium":
            score += 5

        # 3. Feedback adjustment
        fb_key = (item["type"], item.get("title", ""))
        fb = feedback_map.get(fb_key)

        if fb:
            if fb["action"] == "accept":
                score += 20
            elif fb["action"] == "ignore":
                score -= 30
            elif fb["action"] == "snooze":
                # hide for now
                snooze_until = fb["created_at"] + timedelta(days=7)
                if datetime.utcnow() < snooze_until:
                    continue

        item["score"] = score
        personalized_feed.append(item)

    # 4. Sort by score
    personalized_feed.sort(key=lambda x: x["score"], reverse=True)

    return personalized_feed
