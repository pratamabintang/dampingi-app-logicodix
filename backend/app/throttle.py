from __future__ import annotations

import logging
import time
from typing import Callable, Dict, Optional, Protocol, Tuple

from fastapi import Request

log = logging.getLogger("dampingi.throttle")

WINDOW_SECONDS = 15 * 60

LOGIN_PER_ADDRESS = 30
LOGIN_PER_ACCOUNT = 10

REGISTER_PER_ADDRESS = 10
REGISTER_PER_ACCOUNT = 5

REDEEM_PER_USER = 10


class RateLimited(Exception):

    def __init__(self, retry_after: int):
        super().__init__(f"rate limited; retry after {retry_after}s")
        self.retry_after = max(1, int(retry_after))


class RateLimiter(Protocol):

    def hit(self, key: str, limit: int, window: int) -> Optional[int]:
        ...


class InMemoryRateLimiter:

    def __init__(self, clock: Callable[[], float] = time.monotonic):
        self._clock = clock
        self._windows: Dict[str, Tuple[float, int]] = {}

    def hit(self, key: str, limit: int, window: int) -> Optional[int]:
        now = self._clock()
        start, count = self._windows.get(key, (now, 0))
        if now - start >= window:
            start, count = now, 0
        count += 1
        self._windows[key] = (start, count)
        if count > limit:
            return int(window - (now - start)) or 1
        return None


class NullRateLimiter:

    def hit(self, key: str, limit: int, window: int) -> Optional[int]:
        return None


_limiter: Optional[RateLimiter] = None


def get_limiter() -> RateLimiter:
    global _limiter
    if _limiter is None:
        _limiter = InMemoryRateLimiter()
    return _limiter


def set_limiter(limiter: Optional[RateLimiter]) -> None:
    global _limiter
    _limiter = limiter


def caller_address(request: Request) -> str:
    client = request.client
    return client.host if client else "unknown"


def _hit(scope: str, key: str, limit: int) -> Optional[int]:
    retry_after = get_limiter().hit(key, limit, WINDOW_SECONDS)
    if retry_after is not None:
        log.warning("throttle refused scope=%s limit=%d", scope, limit)
    return retry_after


def _login_keys(request: Request, email: str):
    return (
        ("login:address", f"login:address:{caller_address(request)}", LOGIN_PER_ADDRESS),
        ("login:account", f"login:account:{_normalise(email)}", LOGIN_PER_ACCOUNT),
    )


def record_login(request: Request, email: str) -> Optional[int]:
    for scope, key, limit in _login_keys(request, email):
        retry = _hit(scope, key, limit)
        if retry is not None:
            return retry
    return None


def record_registration(request: Request, email: str) -> None:
    for scope, key, limit in (
        ("register:address", f"register:address:{caller_address(request)}", REGISTER_PER_ADDRESS),
        ("register:account", f"register:account:{_normalise(email)}", REGISTER_PER_ACCOUNT),
    ):
        retry = _hit(scope, key, limit)
        if retry is not None:
            raise RateLimited(retry)


def record_redemption(user_id: str) -> None:
    retry = _hit("redeem:user", f"redeem:user:{user_id}", REDEEM_PER_USER)
    if retry is not None:
        raise RateLimited(retry)


def _normalise(email: str) -> str:
    return email.strip().lower()
