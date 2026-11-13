
from app.epds.schemas import EPDSEvaluateRequest
from app.epds.service import evaluate_epds


def test_evaluate_epds_returns_demo_only_result():
    request = EPDSEvaluateRequest(
        answers=[
            {"item_id": f"Q{i}", "option_index": 0}
            for i in range(1, 11)
        ]
    )

    result = evaluate_epds(request)

    assert result.evaluation_mode == "demo_only"
    assert result.instrument == "EPDS-10"
    assert result.total_score == 21
    assert result.follow_up_required is True
    assert result.item10_positive is True
    assert result.immediate_review_required is True
    assert "belum divalidasi" in result.disclaimer


def test_item10_flag_is_independent_from_total_score():
    answers = []

    for i in range(1, 11):
        item_id = f"Q{i}"
        option_index = 0 if item_id in {"Q1", "Q2", "Q4"} else 3

        answers.append({
            "item_id": item_id,
            "option_index": option_index,
        })

    answers[-1]["option_index"] = 2

    request = EPDSEvaluateRequest(answers=answers)
    result = evaluate_epds(request)

    assert result.total_score == 1
    assert result.follow_up_required is False
    assert result.item10_positive is True
    assert result.immediate_review_required is True
