from datetime import date
from typing import Optional

from app.auth import supabase as auth_supabase
from app.observations import supabase
from app.observations.schemas import (
    ObservationAnswerIn,
    ObservationAnswerOut,
    ObservationListOut,
    ObservationOptionOut,
    ObservationOut,
    ObservationQuestionCreate,
    ObservationQuestionOut,
)
from app.shared.day import today_for
from app.shared.profile import active_profile

_UNIQUE_VIOLATION = "23505"


class ObservationCompanionNotFound(Exception):
    pass


class ObservationMotherNotFound(Exception):
    pass


class ObservationNotFound(Exception):
    pass


class ObservationAlreadyCompleted(Exception):
    pass


class ObservationFutureDay(Exception):
    pass


class ObservationDuplicate(Exception):

    def __init__(self, day: str):
        super().__init__(day)
        self.day = day


class ObservationInvalidAnswers(Exception):
    pass


def _normalise_questions(
    questions: list[ObservationQuestionCreate],
) -> list[ObservationQuestionOut]:
    return [
        ObservationQuestionOut(
            id=f"q{question_index}",
            prompt=question.prompt,
            options=[
                ObservationOptionOut(
                    id=f"q{question_index}o{option_index}",
                    label=option.label,
                )
                for option_index, option in enumerate(question.options, start=1)
            ],
        )
        for question_index, question in enumerate(questions, start=1)
    ]


def _validate_answers(
    questions: list[dict], answers: list[ObservationAnswerIn]
) -> list[dict]:
    options_by_question = {
        question["id"]: {option["id"] for option in question["options"]}
        for question in questions
    }
    chosen: dict[str, str] = {}

    for answer in answers:
        if answer.question_id in chosen:
            raise ObservationInvalidAnswers()
        options = options_by_question.get(answer.question_id)
        if options is None or answer.option_id not in options:
            raise ObservationInvalidAnswers()
        chosen[answer.question_id] = answer.option_id

    if set(chosen) != set(options_by_question):
        raise ObservationInvalidAnswers()

    return [
        {"question_id": question_id, "option_id": chosen[question_id]}
        for question_id in options_by_question
    ]


def _to_out(row: dict, connection: Optional[dict] = None) -> ObservationOut:
    linked = connection or row["connection"]
    return ObservationOut(
        id=row["id"],
        connection_id=row["connection_id"],
        companion_id=linked["counterpart_id"],
        mother_id=linked["mother_id"],
        questions=[
            ObservationQuestionOut(
                id=question["id"],
                prompt=question["prompt"],
                options=[
                    ObservationOptionOut(id=option["id"], label=option["label"])
                    for option in question["options"]
                ],
            )
            for question in row["questions"]
        ],
        answers=(
            [
                ObservationAnswerOut(
                    question_id=answer["question_id"],
                    option_id=answer["option_id"],
                )
                for answer in row["answers"]
            ]
            if row["answers"] is not None
            else None
        ),
        day=row["day"],
        completed_at=row["completed_at"],
        created_at=row["created_at"],
        status="completed" if row["completed_at"] is not None else "draft",
    )


def create_observation(
    companion_id: str,
    mother_id: str,
    questions: list[ObservationQuestionCreate],
) -> ObservationOut:
    if active_profile(companion_id) is None:
        raise ObservationCompanionNotFound()

    mother = auth_supabase.fetch_profile(mother_id)
    if (
        not mother
        or mother.get("deleted_at")
        or mother.get("role") != "mother"
    ):
        raise ObservationMotherNotFound()

    connection = supabase.fetch_active_connection(companion_id, mother_id)
    if connection is None:
        raise ObservationMotherNotFound()

    row = supabase.create_observation(
        connection["id"],
        [question.model_dump() for question in _normalise_questions(questions)],
    )
    return _to_out(row, connection)


def submit_observation(
    companion_id: str,
    observation_id: str,
    answers: list[ObservationAnswerIn],
    day: date,
) -> ObservationOut:
    if active_profile(companion_id) is None:
        raise ObservationCompanionNotFound()

    row = supabase.fetch_observation(companion_id, observation_id)
    if row is None:
        raise ObservationNotFound()
    if row["completed_at"] is not None:
        raise ObservationAlreadyCompleted()

    normalised = _validate_answers(row["questions"], answers)

    connection = row["connection"]
    mother = auth_supabase.fetch_profile(connection["mother_id"])
    if mother is None:
        raise ObservationNotFound()
    if day > today_for(mother):
        raise ObservationFutureDay()

    try:
        updated = supabase.complete_observation(observation_id, normalised, day)
    except supabase.SupabaseError as exc:
        if exc.error_code == _UNIQUE_VIOLATION:
            raise ObservationDuplicate(day.isoformat()) from exc
        raise

    if updated is None:
        raise ObservationAlreadyCompleted()
    return _to_out(updated, connection)


def get_observation(companion_id: str, observation_id: str) -> ObservationOut:
    row = supabase.fetch_observation(companion_id, observation_id)
    if row is None:
        raise ObservationNotFound()
    return _to_out(row)


def list_observations(
    companion_id: str,
    connection_id: Optional[str] = None,
    day: Optional[date] = None,
    status: Optional[str] = None,
    offset: Optional[int] = None,
    limit: Optional[int] = None,
) -> ObservationListOut:
    if offset is None and limit is None:
        rows = supabase.list_observations_all(
            companion_id, connection_id, day, status
        )
        observations = [_to_out(row) for row in rows]
        return ObservationListOut(
            observations=observations,
            count=len(observations),
            offset=0,
            limit=len(observations),
            total=len(observations),
        )

    offset = offset or 0
    limit = limit or 20
    rows, total = supabase.list_observations(
        companion_id, connection_id, day, status, offset, limit
    )
    observations = [_to_out(row) for row in rows]
    return ObservationListOut(
        observations=observations,
        count=len(observations),
        offset=offset,
        limit=limit,
        total=total,
    )
