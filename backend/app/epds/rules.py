
DEMO_RULES_VERSION = "demo-cope-2023-v1"
DEMO_FOLLOW_UP_THRESHOLD = 13


def evaluate_rules(total_score: int, item10_score: int) -> dict:
    follow_up_required = (
        total_score >= DEMO_FOLLOW_UP_THRESHOLD
    )

    item10_positive = item10_score > 0

    return {
        "follow_up_required": follow_up_required,
        "item10_positive": item10_positive,
        "immediate_review_required": item10_positive,
    }
