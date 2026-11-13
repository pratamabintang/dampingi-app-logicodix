
from app.epds.rules import evaluate_rules


def test_score_below_demo_threshold():
    result = evaluate_rules(12, 0)

    assert result["follow_up_required"] is False


def test_score_at_demo_threshold():
    result = evaluate_rules(13, 0)

    assert result["follow_up_required"] is True


def test_item10_positive_triggers_independent_review():
    result = evaluate_rules(2, 1)

    assert result["follow_up_required"] is False
    assert result["item10_positive"] is True
    assert result["immediate_review_required"] is True
