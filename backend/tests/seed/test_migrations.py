import re
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]
MIGRATIONS = ROOT / "supabase" / "migrations"

PUBLIC_TABLES = (
    "profiles",
    "moods",
    "journals",
    "connections",
    "invite_codes",
    "observations",
    "professional_notes",
)


def _sql() -> str:
    parts = []
    for path in sorted(MIGRATIONS.glob("*.sql")):
        lines = [
            line.split("--", 1)[0]
            for line in path.read_text(encoding="utf-8").splitlines()
        ]
        parts.append("\n".join(lines))
    return "\n".join(parts)


def test_every_migration_is_well_named_and_ordered():
    names = sorted(path.name for path in MIGRATIONS.glob("*.sql"))
    assert names, "no migrations found"

    prefixes = []
    for name in names:
        match = re.fullmatch(r"(\d{14})_[a-z0-9_]+\.sql", name)
        assert match, f"unexpected migration name: {name}"
        prefixes.append(int(match.group(1)))

    assert prefixes == sorted(set(prefixes)), (
        "migration order is not strictly ascending by timestamp: "
        f"{list(zip(names, prefixes))}"
    )


def test_every_public_table_is_closed_to_the_public_roles():
    sql = _sql()
    created = set(re.findall(r"create table public\.(\w+)", sql))
    enabled = set(
        re.findall(r"alter table public\.(\w+)\s+enable row level security", sql)
    )
    revoked = set(
        re.findall(
            r"revoke all on table public\.(\w+)\s+from anon, authenticated", sql
        )
    )

    assert created, "no tables parsed; the SQL shape or the parser changed"
    assert set(PUBLIC_TABLES) <= created, (
        f"expected tables missing from the migrations: "
        f"{sorted(set(PUBLIC_TABLES) - created)}"
    )
    assert created <= enabled, (
        f"tables without row level security: {sorted(created - enabled)}"
    )
    assert created <= revoked, (
        f"tables whose grants are not revoked: {sorted(created - revoked)}"
    )


def _last_create_table(sql: str, table: str) -> str:
    matches = re.findall(
        rf"create table public\.{table}\s*\((.*?)\)\s*;", sql, flags=re.DOTALL
    )
    assert matches, f"no create table found for public.{table}"
    return matches[-1]


@pytest.mark.parametrize("table", ["moods", "journals"])
def test_one_row_per_profile_per_day_is_a_constraint(table):
    body = _last_create_table(_sql(), table)
    constraints = re.findall(r"unique\s*\(([^)]*)\)", body)
    column_sets = {
        tuple(column.strip() for column in constraint.split(","))
        for constraint in constraints
    }

    assert ("user_id", "created_at") in column_sets, (
        f"public.{table} has no UNIQUE (user_id, created_at); "
        f"found {sorted(column_sets)}"
    )
