# 01: A weak password is a 422, not a 503 outage

**Type:** fix

**What to build:** A caller who picks a password Supabase refuses gets a `422`
that names the rule, instead of a `503` telling them the service is temporarily
unavailable.

Verifiable on its own: the log line that carried `error_code=weak_password`
alongside a `503` is gone, and an offline request with a policy-breaking
password answers `422` with `PASSWORD_RULE` without reaching the upstream.

**Blocked by:** None

**Status:** resolved — implemented and green offline; **not deployed** (a deploy
waits on commit/push approval).

- [x] The rule Supabase enforces is enforced locally, on every field that
      writes a password. — `app/auth/schemas.py` `enforce_password_policy`
      requires one lowercase letter, one uppercase letter, one digit, and one
      symbol from Supabase's own character sets; `RegisterRequest.password`,
      `ResetPasswordRequest.new_password`, and `ChangePasswordRequest.new_password`
      each call it through a `field_validator`. The literal set is copied from
      the hosted `password_required_characters`.
- [x] A policy violation is `422`, and it names the rule. — `PASSWORD_RULE` =
      `"Kata sandi minimal 8 karakter dan harus memuat huruf kecil, huruf besar, angka, dan simbol."`,
      raised as a pydantic `ValueError` so FastAPI answers `422` with the same
      message it uses for the length bound.
- [x] The upstream echo cannot regress to a `503` if the hosted rule changes. —
      `app/auth/router.py` maps `error_code == "weak_password"` to the same
      `422` + `PASSWORD_RULE` in `register`, `reset_password`, and
      `change_password`, the way `same_password` and `user_banned` are already
      mapped.
- [x] A caller-actionable `400`/`409`/`403` branch keeps its exact status and
      message. — Untouched. `tests/auth/offline/test_unreachable_branches.py`
      and `tests/auth/offline/test_reset_password.py` pass unchanged, including
      the throttled-password-change assertion that a `429` upstream still
      surfaces as `503` with the rate-limit text.
- [x] Offline tests prove the fix from both directions: the local refusal, and
      the upstream echo. — `tests/auth/password/test_password_policy.py` (new):
      four parametrised character classes refused, the three models share the
      policy, a strong password passes, and the `422`-not-`503` assertion for
      both change-password and register.
      `tests/auth/offline/test_reset_password.py`: one added `422`-not-`503`
      case for the reset flow.
- [x] The contract is documented where a client developer reads it. —
      `docs/api/auth.md`: the rule under "Aturan umum" and on the register and
      reset request bodies, the `422` row of the status table, and a message
      block naming `PASSWORD_RULE` and the three endpoints.
- [x] The full offline suite is green. — `python -m pytest -m local -q` →
      **234 passed, 574 deselected**.
- [ ] Deployed and confirmed in the journal. — Pending: `setup.sh` does
      `git reset --hard origin/main`, and `origin/main` does not yet carry this
      change, so a deploy cannot pick it up until the change is pushed.

## Comments

**Root cause.** The error boundary (`app/errors.py`,
`upstream_failure_handler`) answers every upstream failure that is not a `429`
and not a transport failure as a sanitised `503`. That mapping was correct for
the leaks ticket, which enumerated the caller-actionable branches of the day
and left the rest as outages. `weak_password` was not among them: the local
schema never produced it, so the branch looked unreachable. It was reachable —
it was simply the local validator that was short, not the upstream.

**Why the local mirror rather than only the mapping.** Mapping alone would turn
the `503` into a `422` after a round trip that writes nothing; mirroring makes
the refusal local, keeps the message identical to the documented one, and makes
the drift case (hosted rule tightens, mirror stale) the only path to the
upstream branch. Both are kept for that reason.

**Why `422` and not `400`.** The other auth refusals that come back from the
upstream are `400` (`same_password`, wrong recovery code), because they are
semantic refusals the caller must interpret. A password that fails a stated
validation rule is the same class as `short`: the request body itself is not
acceptable. Keeping both halves of one rule on `422` means a client does not
have to branch on which half failed.

**Drift.** The mirrored rule is a literal copy of the hosted
`password_required_characters`, which is read by hand, not at runtime. If that
setting changes, decision 3 catches it as a `422` instead of a `503`; the
message would then understate the rule, and this file is where the new value
gets recorded.

**Not touched.** The `409` upsert flow on `POST /moods` and `POST /journals`,
the `404` on `GET /`, and the client-side validation gap that produced the
register `422` burst — the last is the client module's, reported to its owner.
See the spec's Non-goals.

**Suites.** Offline: 234 passed, 574 deselected. Live suite not run for this
ticket; no live assertion depends on the local password rule, and the live
`register` fixture mints users through the admin API with an already-compliant
password.
