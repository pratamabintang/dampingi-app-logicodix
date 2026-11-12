EXPECTED_PATHS = (
    "/auth/login",
    "/me",
    "/moods",
    "/journals",
    "/connections",
    "/observations",
    "/professional-notes",
    "/health",
)

INTERNAL_PREFIXES = ("/ai", "/admin", "/seed")


def _paths(offline_env) -> set:
    import app.main as main

    return set(main.app.openapi()["paths"])


def test_every_domain_has_a_route(offline_env):
    paths = _paths(offline_env)

    missing = [path for path in EXPECTED_PATHS if path not in paths]
    assert not missing, f"routes missing: {missing}; served: {sorted(paths)}"


def test_internal_modules_expose_no_routes(offline_env):
    offenders = sorted(
        path for path in _paths(offline_env) if path.startswith(INTERNAL_PREFIXES)
    )

    assert not offenders, f"internal modules exposed over HTTP: {offenders}"
