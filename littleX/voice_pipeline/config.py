"""Configuration from environment. See .env.example for required variables."""

import os
from pathlib import Path

from dotenv import load_dotenv

# Load .env from voice_pipeline dir or project root
_env_path = Path(__file__).resolve().parent / ".env"
if not _env_path.exists():
    _env_path = Path(__file__).resolve().parent.parent / ".env"
load_dotenv(_env_path)


class Config:
    """App config from env."""

    # Server
    HOST: str = os.getenv("VOICE_PIPELINE_HOST", "0.0.0.0")
    PORT: int = int(os.getenv("VOICE_PIPELINE_PORT", "8002"))

    # 11Labs (required for STT/TTS in M1.3+)
    ELEVENLABS_API_KEY: str = os.getenv("ELEVENLABS_API_KEY", "")

    # MCP tool backend (browser automation)
    MCP_BASE_URL: str = os.getenv("MCP_BASE_URL", "http://localhost:8001").rstrip("/")

    # Optional: WhatsApp / outbound (M1.5+)
    # OUTBOUND_WHATSAPP_URL: str = os.getenv("OUTBOUND_WHATSAPP_URL", "")


config = Config()
