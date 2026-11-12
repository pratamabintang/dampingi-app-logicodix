from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse

from app.config import get_settings

SECURITY_HEADERS = {
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
    "Permissions-Policy": "accelerometer=(), camera=(), geolocation=(), "
    "gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()",
    "Content-Security-Policy": (
        "default-src 'self'; "
        "img-src 'self' data: https://fastapi.tiangolo.com; "
        "script-src 'self' https://cdn.jsdelivr.net 'unsafe-inline'; "
        "style-src 'self' https://cdn.jsdelivr.net 'unsafe-inline'; "
        "connect-src 'self'; "
        "frame-ancestors 'none'; "
        "base-uri 'none'"
    ),
}


def _host_only(value: str) -> str:
    value = (value or "").strip().lower()
    if value.startswith("["):
        return value.split("]")[0] + "]"
    if value.count(":") == 1:
        name, _, port = value.partition(":")
        if port.isdigit():
            return name
    return value


def _host_allowed(host: str, allowed: list) -> bool:
    for pattern in allowed:
        if pattern == "*" or pattern == host:
            return True
        if pattern.startswith("*") and host.endswith(pattern[1:]):
            return True
    return False


MAX_BODY_BYTES = 2 * 1024 * 1024


class BodySizeMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        declared = request.headers.get("content-length")
        if declared is not None:
            try:
                if int(declared) > MAX_BODY_BYTES:
                    return JSONResponse(
                        status_code=413,
                        content={"detail": "Request body too large"},
                    )
            except ValueError:
                return JSONResponse(
                    status_code=400, content={"detail": "Invalid Content-Length"}
                )
        return await call_next(request)


class HostCheckMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        host = _host_only(request.headers.get("host", ""))
        if not _host_allowed(host, get_settings().allowed_hosts):
            return JSONResponse(status_code=400, content={"detail": "Invalid host header"})
        return await call_next(request)


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        response = await call_next(request)
        for name, value in SECURITY_HEADERS.items():
            response.headers.setdefault(name, value)
        return response


def install(app) -> None:
    app.add_middleware(BodySizeMiddleware)
    app.add_middleware(HostCheckMiddleware)
    app.add_middleware(SecurityHeadersMiddleware)
