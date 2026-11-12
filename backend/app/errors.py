import logging

from fastapi import Request
from fastapi.responses import JSONResponse

from app.supabase import SupabaseError
from app.throttle import RateLimited

log = logging.getLogger("dampingi.upstream")

_UNAVAILABLE = "The service is temporarily unavailable. Please try again later."
_UNREACHABLE = "The service is temporarily unavailable: upstream unreachable."
_RATE_LIMITED = (
    "Too many requests: the upstream rate limit was reached. "
    "Please try again later."
)
_THROTTLED = "Too many requests. Please try again later."


def caller_safe_message(exc: SupabaseError) -> str:
    if exc.status == 429:
        return _RATE_LIMITED
    if exc.is_transport:
        return _UNREACHABLE
    return _UNAVAILABLE


def log_upstream_failure(request: Request, exc: SupabaseError) -> None:
    log.warning(
        "upstream failure method=%s path=%s status=%s error_code=%s",
        request.method,
        request.url.path,
        exc.status,
        exc.error_code,
    )


async def upstream_failure_handler(request: Request, exc: SupabaseError):
    log_upstream_failure(request, exc)
    return JSONResponse(status_code=503, content={"detail": caller_safe_message(exc)})


async def rate_limited_handler(request: Request, exc: RateLimited):
    log.warning(
        "throttled request method=%s path=%s retry_after=%s",
        request.method,
        request.url.path,
        exc.retry_after,
    )
    return JSONResponse(
        status_code=429,
        content={"detail": _THROTTLED},
        headers={"Retry-After": str(exc.retry_after)},
    )


async def unexpected_failure_handler(request: Request, exc: Exception):
    log.error(
        "unhandled error method=%s path=%s type=%s",
        request.method,
        request.url.path,
        type(exc).__name__,
    )
    return JSONResponse(status_code=500, content={"detail": "Internal server error"})


def install(app) -> None:
    """Register the handlers. Called once from `app.main`."""
    app.add_exception_handler(SupabaseError, upstream_failure_handler)
    app.add_exception_handler(RateLimited, rate_limited_handler)
    app.add_exception_handler(Exception, unexpected_failure_handler)
