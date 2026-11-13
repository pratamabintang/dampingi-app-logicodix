
from app.epds.schemas import EPDSEvaluateRequest


DIRECT_SCORING_ITEMS = {"Q1", "Q2", "Q4"}


def score_answer(item_id: str, option_index: int) -> int:
    if item_id in DIRECT_SCORING_ITEMS:
        return option_index

    return 3 - option_index


def calculate_total_score(
    request: EPDSEvaluateRequest,
) -> int:
    return sum(
        score_answer(answer.item_id, answer.option_index)
        for answer in request.answers
    )
