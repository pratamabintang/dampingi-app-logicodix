
import pytest
from pydantic import ValidationError

from app.epds.schemas import (
    EPDSAnswer,
    EPDSEvaluateRequest,
)


def make_answers():
    return [
        {"item_id": f"Q{i}", "option_index": 0}
        for i in range(1, 11)
    ]


def test_accepts_exactly_ten_unique_answers():
    request = EPDSEvaluateRequest(answers=make_answers())

    assert len(request.answers) == 10


def test_rejects_missing_answer():
    answers = make_answers()[:-1]

    with pytest.raises(ValidationError):
        EPDSEvaluateRequest(answers=answers)


def test_rejects_duplicate_item():
    answers = make_answers()
    answers[-1]["item_id"] = "Q1"

    with pytest.raises(ValidationError):
        EPDSEvaluateRequest(answers=answers)


def test_rejects_unknown_item():
    answers = make_answers()
    answers[0]["item_id"] = "Q11"

    with pytest.raises(ValidationError):
        EPDSEvaluateRequest(answers=answers)


@pytest.mark.parametrize("option_index", [-1, 4])
def test_rejects_invalid_option_index(option_index):
    with pytest.raises(ValidationError):
        EPDSAnswer(
            item_id="Q1",
            option_index=option_index,
        )


def test_rejects_extra_fields():
    answers = make_answers()
    answers[0]["unexpected"] = "value"

    with pytest.raises(ValidationError):
        EPDSEvaluateRequest(answers=answers)
