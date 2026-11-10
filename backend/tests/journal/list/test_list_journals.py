from conftest import captured, supabase_json

AUTH = {"Authorization": "Bearer offline-token"}

PROFILE = captured("profiles-select-2026-11-10")

JOURNAL_ROW = captured("journals-select-2026-11-10")[0]

OTHER = "00000000-0000-4000-8000-0000000000f1"

MAX_ROWS = 1000

def _row(user_id, day, title="A day"):
    return {
        **JOURNAL_ROW,
        "user_id": user_id,
        "created_at": day,
        "title": title,
        "content": f"Content for {day}.",
    }

def _postgrest(upstream, profile, journals=None, max_rows=MAX_ROWS):
    rows = journals or []

    def profile_get(request):
        asked = request.url.params["select"].split(",")
        return supabase_json(200, [{k: profile[k] for k in asked if k in profile}])

    def journal_get(request):
        asked = request.url.params["select"].split(",")
        order = request.url.params.get("order")

        wanted_user = request.url.params.get("user_id")
        hits = [
            row
            for row in rows
            if wanted_user is None
            or row["user_id"] == wanted_user.removeprefix("eq.")
        ]
        if order == "created_at.desc":
            hits = sorted(hits, key=lambda r: r["created_at"], reverse=True)
        elif order == "created_at.asc":
            hits = sorted(hits, key=lambda r: r["created_at"])

        offset = int(request.url.params.get("offset", 0))
        limit = int(request.url.params.get("limit", max_rows))
        page = hits[offset : offset + min(limit, max_rows)]

        return supabase_json(
            200, [{k: row[k] for k in asked if k in row} for row in page]
        )

    return upstream(
        {
            ("GET", "/rest/v1/profiles"): profile_get,
            ("GET", "/rest/v1/journals"): journal_get,
        }
    )

def test_an_author_with_no_journals_gets_an_empty_list(mock_client, upstream):
    client, _ = mock_client
    _postgrest(upstream, {**PROFILE, "role": "mother"})

    resp = client.get("/journals", headers=AUTH)

    assert resp.status_code == 200, resp.text
    assert resp.json() == {"journals": [], "count": 0, "offset": 0, "limit": 0, "total": 0}

def test_the_list_holds_only_the_requesting_authors_journals(mock_client, upstream):
    client, _ = mock_client
    _postgrest(
        upstream,
        {**PROFILE, "role": "mother"},
        journals=[
            _row(PROFILE["user_id"], "2026-10-30", "Mine"),
            _row(OTHER, "2026-10-30", "Theirs"),
            _row(OTHER, "2026-10-29", "Also theirs"),
        ],
    )

    resp = client.get("/journals", headers=AUTH)

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["count"] == 1
    assert body["total"] == 1
    assert [j["title"] for j in body["journals"]] == ["Mine"]
    assert all(j["user_id"] == PROFILE["user_id"] for j in body["journals"])

def test_journals_are_listed_newest_first(mock_client, upstream):
    client, _ = mock_client
    _postgrest(
        upstream,
        {**PROFILE, "role": "mother"},
        journals=[
            _row(PROFILE["user_id"], "2026-10-28"),
            _row(PROFILE["user_id"], "2026-10-31"),
            _row(PROFILE["user_id"], "2026-10-29"),
        ],
    )

    resp = client.get("/journals", headers=AUTH)

    assert resp.status_code == 200, resp.text
    days = [j["created_at"] for j in resp.json()["journals"]]
    assert days == ["2026-10-31", "2026-10-29", "2026-10-28"]

def test_two_authors_listing_the_same_dates_see_only_their_own(
    mock_client, upstream, real_gate, as_author
):
    client, _ = mock_client
    _postgrest(
        upstream,
        {**PROFILE, "role": "mother"},
        journals=[
            _row(PROFILE["user_id"], "2026-10-30", "Mine"),
            _row(OTHER, "2026-10-30", "Theirs"),
        ],
    )

    as_author(PROFILE["user_id"])
    mine = client.get("/journals", headers=AUTH)
    assert mine.status_code == 200, mine.text
    assert [j["title"] for j in mine.json()["journals"]] == ["Mine"]

    as_author(OTHER)
    theirs = client.get("/journals", headers=AUTH)
    assert theirs.status_code == 200, theirs.text
    assert [j["title"] for j in theirs.json()["journals"]] == ["Theirs"]

def test_the_list_is_not_truncated_by_the_projects_row_cap(mock_client, upstream):
    client, _ = mock_client
    total = MAX_ROWS + 5

    from datetime import date, timedelta

    newest = date(2026, 10, 31)
    journals = [
        _row(
            PROFILE["user_id"],
            (newest - timedelta(days=offset)).isoformat(),
            f"Day {offset}",
        )
        for offset in range(total)
    ]
    _postgrest(upstream, {**PROFILE, "role": "mother"}, journals=journals)

    resp = client.get("/journals", headers=AUTH)

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["count"] == total, "the row cap truncated the Author's history"
    assert body["total"] == total
    assert body["journals"][0]["title"] == "Day 0"
    assert body["journals"][-1]["title"] == f"Day {total - 1}"
    days = [j["created_at"] for j in body["journals"]]
    assert days == sorted(days, reverse=True)

def test_the_list_survives_a_server_cap_lower_than_the_page_size(
    mock_client, upstream
):
    client, _ = mock_client
    total = 7

    from datetime import date, timedelta

    newest = date(2026, 10, 31)
    journals = [
        _row(
            PROFILE["user_id"],
            (newest - timedelta(days=offset)).isoformat(),
            f"Day {offset}",
        )
        for offset in range(total)
    ]
    _postgrest(
        upstream, {**PROFILE, "role": "mother"}, journals=journals, max_rows=2
    )

    resp = client.get("/journals", headers=AUTH)

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["count"] == total, "a short page was mistaken for the last page"
    assert body["total"] == total
    days = [j["created_at"] for j in body["journals"]]
    assert days == sorted(days, reverse=True)

def test_an_upstream_that_ignores_offset_does_not_hang(mock_client, upstream):
    client, _ = mock_client

    def profile_get(request):
        asked = request.url.params["select"].split(",")
        return supabase_json(200, [{k: PROFILE[k] for k in asked if k in PROFILE}])

    def journal_get(request):
        return supabase_json(
            200,
            [
                _row(PROFILE["user_id"], f"2026-10-{day:02d}")
                for day in range(1, 11)
            ]
            * 100,
        )

    upstream(
        {
            ("GET", "/rest/v1/profiles"): profile_get,
            ("GET", "/rest/v1/journals"): journal_get,
        }
    )

    resp = client.get("/journals", headers=AUTH)

    assert resp.status_code == 503, resp.text


def test_a_professional_is_refused_by_the_real_gate(
    mock_client, upstream, real_gate
):
    client, _ = mock_client
    _postgrest(upstream, {**PROFILE, "role": "professional"})

    resp = client.get("/journals", headers=AUTH)

    assert resp.status_code == 403, resp.text
    detail = resp.json()["detail"]
    assert "mother" in detail and "companion" in detail


def test_no_token_is_refused(offline_env):
    from fastapi.testclient import TestClient

    import app.main as main

    resp = TestClient(main.app).get("/journals")

    assert resp.status_code == 401