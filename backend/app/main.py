from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.config import get_settings
from app.routers.auth import router as auth_router
from app.routers.documents import router as documents_router
from app.routers.errors import build_error_detail
from app.routers.user import router as user_router

settings = get_settings()

app = FastAPI(title="DocuMind AI API", version="0.1.0")

# Keep CORS explicit for local development origins from settings.
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(RequestValidationError)
async def request_validation_exception_handler(_, exc: RequestValidationError) -> JSONResponse:
    field_name: str | None = None
    for error in exc.errors():
        location = error.get("loc", ())
        if len(location) >= 2 and location[0] == "body":
            field_name = str(location[-1])
            break

    return JSONResponse(
        status_code=422,
        content={
            "detail": build_error_detail(
                code="VALIDATION_ERROR",
                message="Invalid request payload.",
                field=field_name,
            )
        },
    )


app.include_router(auth_router, prefix="/api/v1/auth", tags=["auth"])
app.include_router(documents_router, prefix="/api/v1/documents", tags=["documents"])
app.include_router(user_router, prefix="/api/v1/user", tags=["user"])


@app.get("/health", tags=["health"])
async def health_check() -> dict[str, str]:
    return {"status": "ok"}
