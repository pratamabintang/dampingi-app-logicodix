
import asyncio

import pytest
from pydantic import ValidationError

from app.ai import AIGateway, AITimeout
from app.ai.providers import FakeProvider
from app.journals.extraction import extract_journal_themes
from app.journals.extraction_schemas import JournalExtractionInput


pytestmark = pytest.mark.local


def run(coro):
    return asyncio.run(coro)


def sample_journals():
    return [
        JournalExtractionInput(
            id="journal-001",
            title="Hari yang melelahkan",
            content="Hari ini saya merasa lelah karena mengurus bayi.",
            date="2026-11-09",
        ),
        JournalExtractionInput(
            id="journal-002",
            title="Dukungan keluarga",
            content="Ibu saya membantu menjaga bayi hari ini.",
            date="2026-11-10",
        ),
    ]


def test_extract_themes_preserves_source_journal_ids():
    provider = FakeProvider(
        response={
            "themes": [
                {
                    "label": "kelelahan mengurus bayi",
                    "source_journal_id": "journal-001",
                },
                {
                    "label": "dukungan keluarga",
                    "source_journal_id": "journal-002",
                },
            ]
        }
    )

    result = run(
        extract_journal_themes(
            sample_journals(),
            AIGateway(provider),
        )
    )

    assert result.processing_status == "completed"
    assert len(result.themes) == 2
    assert result.themes[0].source_journal_id == "journal-001"
    assert result.themes[1].source_journal_id == "journal-002"


def test_empty_journals_return_completed_without_calling_ai():
    provider = FakeProvider(response={"themes": []})

    result = run(
        extract_journal_themes(
            [],
            AIGateway(provider),
        )
    )

    assert result.processing_status == "completed"
    assert result.themes == []
    assert provider.calls == []


def test_unknown_source_journal_id_is_rejected():
    provider = FakeProvider(
        response={
            "themes": [
                {
                    "label": "tema palsu",
                    "source_journal_id": "unknown-journal",
                }
            ]
        }
    )

    result = run(
        extract_journal_themes(
            sample_journals(),
            AIGateway(provider),
        )
    )

    assert result.processing_status == "failed"
    assert result.themes == []


def test_invalid_ai_output_returns_failed():
    provider = FakeProvider(
        response={
            "themes": [
                {
                    "label": "tema tanpa sumber",
                }
            ]
        }
    )

    result = run(
        extract_journal_themes(
            sample_journals(),
            AIGateway(provider),
        )
    )

    assert result.processing_status == "failed"
    assert result.themes == []


def test_duplicate_source_journal_ids_return_failed():
    journals = [
        JournalExtractionInput(
            id="journal-001",
            title="Judul pertama",
            content="Isi pertama.",
            date="2026-11-09",
        ),
        JournalExtractionInput(
            id="journal-001",
            title="Judul kedua",
            content="Isi kedua.",
            date="2026-11-10",
        ),
    ]

    provider = FakeProvider(response={"themes": []})

    result = run(
        extract_journal_themes(
            journals,
            AIGateway(provider),
        )
    )

    assert result.processing_status == "failed"
    assert result.themes == []
    assert provider.calls == []


def test_ai_timeout_returns_failed():
    provider = FakeProvider(
        response={"themes": []},
        delay=1,
    )
    gateway = AIGateway(provider, timeout_s=0.05)

    result = run(
        extract_journal_themes(
            sample_journals(),
            gateway,
        )
    )

    assert result.processing_status == "failed"
    assert result.themes == []

def test_failed_result_never_contains_themes():
    provider = FakeProvider(
        response={
            "themes": [
                {
                    "label": "dukungan keluarga",
                    "source_journal_id": "unknown-journal",
                }
            ]
        }
    )

    result = run(
        extract_journal_themes(
            sample_journals(),
            AIGateway(provider),
        )
    )

    assert result.processing_status == "failed"
    assert result.themes == []

def test_journal_input_rejects_invalid_date():
    with pytest.raises(ValidationError):
        JournalExtractionInput(
            id="journal-003",
            title="Judul",
            content="Isi jurnal.",
            date="2026-02-30",
        )


def test_journal_input_rejects_blank_id():
    with pytest.raises(ValidationError):
        JournalExtractionInput(
            id="   ",
            title="Judul",
            content="Isi jurnal.",
            date="2026-11-09",
        )


def test_journal_input_rejects_blank_content():
    with pytest.raises(ValidationError):
        JournalExtractionInput(
            id="journal-003",
            title="Judul",
            content="   ",
            date="2026-11-09",
        )