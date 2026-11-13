# Spec: Password policy

Status: implemented 2026-11-14; **not deployed** (waiting for commit/push
approval). Superseded by none.

Goal: the API never answers a password Supabase rejects as a `503` outage.
A password that does not meet the project's rule is refused as `422` with a
message that names the rule, before any upstream call.

## Observed starting point

`sudo journalctl -u dampingi-backend` on 2026-11-14 04:10 CST:

```
upstream failure method=POST path=/auth/password status=422 error_code=weak_password
INFO:     140.213.173.175:0 - "POST /auth/password HTTP/1.1" 503 Service Unavailable
```

The caller was told the service was down and to retry later, for a request
that could never succeed. The same chain was reachable from
`POST /auth/register` and `POST /auth/reset-password`, which also write a
password through Supabase.

The hosted project config (`GET /v1/projects/levixakixujggtwohweq/config/auth`)
at the same time:

| Setting | Value |
|---|---|
| `password_min_length` | `8` |
| `password_required_characters` | lowercase : uppercase : digits : symbols |
| `password_hibp_enabled` | `false` |

Local validation only enforced 8–72 characters, so a password with no uppercase
letter, digit, or symbol cleared the API and was refused upstream.

## Decisions

| # | Decision |
|---|----------|
| 1 | Mirror `password_required_characters` locally in `app/auth/schemas.py` as `enforce_password_policy`, applied to `RegisterRequest.password`, `ResetPasswordRequest.new_password`, and `ChangePasswordRequest.new_password`. One function, three fields — no field can be forgotten the way the length bound was not |
| 2 | A policy violation is **`422`**, not `400`. It is a validation refusal, it matches the status the existing `test_change_password_rejects_short_new` already expects for the length bound, and it keeps the two halves of the same rule on one status |
| 3 | The upstream echo `error_code == "weak_password"` maps to the same `422` in `register`, `reset_password`, and `change_password` — a backstop for the case where the Supabase config changes and the local mirror is stale |
| 4 | The message is single-sourced as `PASSWORD_RULE` and is Indonesian, with the rest of the user-facing auth copy. `change_password`'s older English refusals (`Current password is incorrect`, `New password must differ from the current one`) are left as they are: changing them is a separate contract decision, not part of this fix |
| 5 | Local validation stays at 8–72 characters plus the four required classes. No length or class beyond what Supabase enforces — a stricter local rule would refuse passwords the platform accepts |
| 6 | The rule is a literal copy of the hosted config, not a runtime read. The hosted value is read by hand and recorded here; a drift is caught by decision 3, which turns the mismatch into a `422` instead of a `503` |

## API contract

No endpoint gains or loses a route. The three password-writing endpoints gain
one documented refusal:

- `POST /auth/register` — `422` `"Kata sandi minimal 8 karakter dan harus
  memuat huruf kecil, huruf besar, angka, dan simbol."`
- `POST /auth/reset-password` — same `422`, same message
- `POST /auth/password` — same `422`, same message

Unchanged: `409` duplicate Gmail on register, `400` wrong recovery code, `400`
unchanged password, `401` bad credentials, `403` unverified or deleted, `429`
throttle, `503` genuine upstream outage.

## Non-goals

- **Client-side validation.** The observed `422` burst on `POST /auth/register`
  (15+ in one minute from a single address) came from a client that accepts any
  email domain and any non-empty password. That is the client module's fix; it
  has been reported to that module's owner and is out of this backend's scope.
- **`409` on `POST /moods` and `POST /journals`.** Not a defect: the client
  upserts a day by posting, reading the clash, then patching. Recorded here so
  it is not re-reported as an error.
- **`GET /` answering `404`.** There is no root route by design.
- Password-strength meter, breached-password check, per-role rules.

## Tests

Offline (`pytest -m local`), the whole suite green at 234 passed:

- `tests/auth/password/test_password_policy.py` — each missing character class
  is refused; the three models share the policy; a strong password passes; a
  change to a weak password and a register refused upstream are `422` with
  `PASSWORD_RULE`, and never `503`.
- `tests/auth/offline/test_reset_password.py` — one added case: an upstream
  `weak_password` on reset is `422`, not `503`.

## Docs

`docs/api/auth.md`: the password rule, three example bodies updated to a
compliant password, the `422` row of the status table, and the message block
that names the rule and the endpoints it applies to.
