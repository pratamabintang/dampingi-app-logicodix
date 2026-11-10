from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import pytest

from app.summaries.provider import generate_summary


pytestmark = pytest.mark.local


@patch("app.summaries.provider.genai.Client")
def test_generate_summary_returns_response_text(mock_client_class):
    mock_client = MagicMock()
    mock_client.models.generate_content.return_value = SimpleNamespace(
        text="Ringkasan mood mingguan."
    )
    mock_client_class.return_value = mock_client

    result = generate_summary(
        moods=[{"date": "2026-11-09", "mood": 4}],
        period_start="2026-11-04",
        period_end="2026-11-10",
        api_key="fake-test-key",
        model="gemini-3.1-flash-lite",
    )

    assert result == "Ringkasan mood mingguan."

    mock_client.models.generate_content.assert_called_once()
    call_kwargs = mock_client.models.generate_content.call_args.kwargs

    assert call_kwargs["model"] == "gemini-3.1-flash-lite"
    assert "mood" in call_kwargs["contents"]
    assert "2026-11-09" in call_kwargs["contents"]
    assert "summarizes weekly mood records" in call_kwargs["contents"]

def test_generate_summary_rejects_missing_api_key():
    with pytest.raises(RuntimeError, match="API key"):
        generate_summary(
            moods=[],
            period_start="2026-11-04",
            period_end="2026-11-10",
            api_key=None,
            model="gemini-3.1-flash-lite",
        )


@patch("app.summaries.provider.genai.Client")
def test_generate_summary_rejects_empty_response(mock_client_class):
    mock_client = MagicMock()
    mock_client.models.generate_content.return_value = SimpleNamespace(
        text="  "
    )
    mock_client_class.return_value = mock_client

    with pytest.raises(ValueError, match="empty response"):
        generate_summary(
            moods=[{"date": "2026-11-09", "mood": 4}],
            period_start="2026-11-04",
            period_end="2026-11-10",
            api_key="fake-test-key",
            model="gemini-3.1-flash-lite",
        )