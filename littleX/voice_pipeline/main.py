"""
Voice pipeline orchestration service.

Public webhook for 11Labs/WhatsApp inbound payloads. STT/TTS/LLM wiring in later tasks.
Run: uvicorn voice_pipeline.main:app --host 0.0.0.0 --port 8002
"""
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from voice_pipeline.config import config
from voice_pipeline.webhook_payload import parse_and_validate

app = FastAPI(
    title="Voice Pipeline",
    description="Webhook + orchestration for 11Labs/WhatsApp voice flow",
    version="0.1.0",
)


@app.get("/health")
async def health():
    """Liveness/readiness for deployment."""
    return {"status": "ok", "service": "voice_pipeline"}


@app.post("/webhook/inbound")
async def webhook_inbound(request: Request):
    """
    Public webhook: accepts 11Labs/WhatsApp inbound payloads (JSON).

    Expects JSON with at least one of: audio_url, audio_base64.
    Optional: conversation_id, sender_id. Returns 415 if not JSON, 400 on
    validation failure, 202 with extracted payload on success.
    """
    body = await request.body()
    content_type = request.headers.get("content-type", "")

    # 415 when Content-Type is not application/json
    if not content_type or "application/json" not in content_type.split(";")[0].strip().lower():
        return JSONResponse(
            status_code=415,
            content={"error": "Content-Type must be application/json"},
        )

    payload, errors = parse_and_validate(body, content_type)

    # 400 for parse or validation errors (invalid JSON or missing/invalid audio)
    if errors:
        return JSONResponse(
            status_code=400,
            content={"error": "Validation failed", "details": errors},
        )

    # 202 Accepted with structured response for M1.3 to consume
    audio_info = {}
    if payload.audio_url:
        audio_info["url"] = payload.audio_url
    if payload.audio_base64:
        audio_info["base64"] = True

    return JSONResponse(
        status_code=202,
        content={
            "received": True,
            "audio": audio_info,
            "conversation_id": payload.conversation_id,
            "sender_id": payload.sender_id,
        },
    )


def run():
    import uvicorn
    uvicorn.run(
        "voice_pipeline.main:app",
        host=config.HOST,
        port=config.PORT,
        reload=True,
    )


if __name__ == "__main__":
    run()
