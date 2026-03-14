# Voice Pipeline (M1)

Python orchestration service for the VoiceAgent MVP: webhook for 11Labs/WhatsApp, then STT → agent → TTS → outbound.

## Setup

From the **littleX** repo root:

```bash
cd /path/to/littleX
python -m venv voice_pipeline/.venv
source voice_pipeline/.venv/bin/activate   # or .venv\Scripts\activate on Windows
pip install -r voice_pipeline/requirements.txt
cp voice_pipeline/.env.example voice_pipeline/.env
# Edit voice_pipeline/.env: set ELEVENLABS_API_KEY (and others as needed)
```

## Run

From the **littleX** repo root (parent of `voice_pipeline/`), so the package resolves:

```bash
cd /path/to/littleX
uvicorn voice_pipeline.main:app --host 0.0.0.0 --port 8002
# or
python -m voice_pipeline.main
```

- Health: `GET http://localhost:8002/health`
- Webhook: `POST http://localhost:8002/webhook/inbound` (see below)

### Webhook payload (M1.2)

Request must be `Content-Type: application/json`. Body must be a JSON object with **at least one** of:

| Field | Type | Purpose |
|-------|------|---------|
| `audio_url` | string | HTTPS URL to fetch audio (e.g. 11Labs or WhatsApp media URL). |
| `audio_base64` | string | Inline audio as base64 or `data:audio/...;base64,...` data URI. |
| `conversation_id` | string (optional) | For session affinity (M4). |
| `sender_id` | string (optional) | WhatsApp sender or user id. |

Exact field names may change after P1 (11Labs webhook payload confirmation).

**Responses:**

| Status | When | Body |
|--------|------|------|
| **415** | Request not `application/json` | `{"error": "Content-Type must be application/json"}` |
| **400** | Invalid JSON or validation failed (e.g. missing audio, invalid URL/base64) | `{"error": "Validation failed", "details": ["...", ...]}` |
| **202** | Valid payload accepted | `{"received": true, "audio": {"url": "..."} or {"base64": true}, "conversation_id": "...", "sender_id": "..."}` |

## Public URL (M1.7)

Use ngrok or a deployed host (Railway, Render, Fly.io) and set that URL in 11Labs webhook config, e.g. `https://your-host/webhook/inbound`.

## Config

| Env | Default | Description |
|-----|---------|-------------|
| `VOICE_PIPELINE_HOST` | `0.0.0.0` | Bind host |
| `VOICE_PIPELINE_PORT` | `8002` | Bind port |
| `ELEVENLABS_API_KEY` | — | Required for STT/TTS |
| `MCP_BASE_URL` | `http://localhost:8001` | MCP server for browser tools |
