
from app.epds.rules import (
    DEMO_RULES_VERSION,
    evaluate_rules,
)
from app.epds.schemas import (
    EPDSEvaluateRequest,
    EPDSEvaluateResponse,
)
from app.epds.scoring import (
    calculate_total_score,
    score_answer,
)


DEMO_DISCLAIMER = (
    "Hasil ini merupakan simulasi untuk demonstrasi aplikasi. "
    "EPDS adalah instrumen skrining, bukan diagnosis. "
    "Konfigurasi dan ambang pada demo ini belum divalidasi "
    "atau disahkan untuk penggunaan klinis di Indonesia."
)


def evaluate_epds(
    request: EPDSEvaluateRequest,
) -> EPDSEvaluateResponse:
    total_score = calculate_total_score(request)

    item10_answer = next(
        answer
        for answer in request.answers
        if answer.item_id == "Q10"
    )

    item10_score = score_answer(
        item10_answer.item_id,
        item10_answer.option_index,
    )

    rules = evaluate_rules(total_score, item10_score)

    return EPDSEvaluateResponse(
        rules_version=DEMO_RULES_VERSION,
        total_score=total_score,
        follow_up_required=rules["follow_up_required"],
        item10_positive=rules["item10_positive"],
        immediate_review_required=rules[
            "immediate_review_required"
        ],
        disclaimer=DEMO_DISCLAIMER,
    )
