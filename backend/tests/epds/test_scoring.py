
import pytest

from app.epds.schemas import (
    EPDSAnswer,
    EPDSEvaluateRequest,
)
from app.epds.scoring import (
    calculate_total_score,
    score_answer,
)


@pytest.mark.parametrize(
    ("item_id", "expected"),
    [
        ("Q1", [0, 1, 2, 3]),
        ("Q2", [0, 1, 2, 3]),
        ("Q4", [0, 1, 2, 3]),
        ("Q3", [3, 2, 1, 0]),
        ("Q5", [3, 2, 1, 0]),
        ("Q6", [3, 2, 1, 0]),
        ("Q7", [3, 2, 1, 0]),
        ("Q8", [3, 2, 1, 0]),
        ("Q9", [3, 2, 1, 0]),
        ("Q10", [3, 2, 1, 0]),
    ],
)
def test_score_answer_mapping(item_id, expected):
    actual = [
        score_answer(item_id, index)
        for index in range(4)
    ]

    assert actual == expected


def test_calculate_total_score_maximum():
    answers = []

    for i in range(1, 11):
        item_id = f"Q{i}"
        option_index = 3 if item_id in {"Q1", "Q2", "Q4"} else 0

        answers.append(
            EPDSAnswer(
                item_id=item_id,
                option_index=option_index,
            )
        )

    request = EPDSEvaluateRequest(answers=answers)

    assert calculate_total_score(request) == 30


def test_calculate_total_score_minimum():
    answers = []

    for i in range(1, 11):
        item_id = f"Q{i}"
        option_index = 0 if item_id in {"Q1", "Q2", "Q4"} else 3

        answers.append(
            EPDSAnswer(
                item_id=item_id,
                option_index=option_index,
            )
        )

    request = EPDSEvaluateRequest(answers=answers)

    assert calculate_total_score(request) == 0
