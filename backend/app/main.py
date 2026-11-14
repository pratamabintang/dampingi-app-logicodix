
from fastapi import FastAPI, Request
from fastapi.responses import Response

from app.auth import router as auth_router
from app.connections.router import router as connections_router
from app.journals.router import router as journals_router
from app.moods.router import router as moods_router
from app.summaries.router import router as summaries_router
from app.chat.router import router as chat_router
from app.observations.router import router as observations_router
from app.professional_notes.router import router as professional_notes_router
from app.patient_summaries.router import router as patient_summaries_router
from app.config import get_settings
from app import errors, security
from app.epds.router import router as epds_router
from app.epds.assessment_router import router as epds_assessment_router

app = FastAPI(
    title="dampingi",
    description="FastAPI backend backed by Supabase Auth",
)

errors.install(app)

_DOC_PATHS = frozenset(
    {"/docs", "/docs/", "/redoc", "/redoc/", "/openapi.json"}
)


@app.middleware("http")
async def docs_only_in_development(request: Request, call_next):
    if (
        request.url.path in _DOC_PATHS
        and not get_settings().is_development
    ):
        return Response(status_code=404)

    return await call_next(request)


security.install(app)

app.include_router(auth_router)
app.include_router(moods_router)
app.include_router(summaries_router)
app.include_router(epds_router)
app.include_router(epds_assessment_router)
app.include_router(chat_router)
app.include_router(journals_router)
app.include_router(connections_router)
app.include_router(observations_router)
app.include_router(professional_notes_router)
app.include_router(patient_summaries_router)


@app.get("/health")
async def health_check():
    return {"status": "healthy"}
