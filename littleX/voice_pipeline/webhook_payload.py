"""
Webhook payload parsing and validation for 11Labs/WhatsApp inbound.

Payload shape will be confirmed in P1; current schema is provisional.
"""
import base64
import json
import re
from dataclasses import dataclass
from typing import Optional
from urllib.parse import urlparse


@dataclass
class WebhookPayload:
    """Parsed inbound webhook payload. At least one of audio_url or audio_base64 is set."""

    audio_url: Optional[str] = None
    audio_base64: Optional[str] = None
    conversation_id: Optional[str] = None
    sender_id: Optional[str] = None


# Simple HTTP(S) URL check
_URL_RE = re.compile(r"^https?://", re.IGNORECASE)


def _is_valid_url(s: str) -> bool:
    try:
        parsed = urlparse(s)
        return bool(parsed.scheme and parsed.netloc and _URL_RE.match(s))
    except Exception:
        return False


def _is_valid_base64(s: str) -> bool:
    """Check that the string is non-empty and decodable base64 (or data URI with base64)."""
    s = s.strip()
    if not s:
        return False
    if s.startswith("data:"):
        # data:audio/...;base64,<payload>
        if ";base64," in s:
            s = s.split(";base64,", 1)[1]
        else:
            return False
    try:
        base64.b64decode(s, validate=True)
        return True
    except Exception:
        return False


def parse_and_validate(
    body: bytes, content_type: str
) -> tuple[Optional[WebhookPayload], list[str]]:
    """
    Parse JSON body and validate webhook payload.

    Returns (payload, []) on success, or (None, list of error strings) on failure.
    """
    errors: list[str] = []

    if not (content_type and "application/json" in content_type.split(";")[0].strip().lower()):
        return None, ["Content-Type must be application/json"]

    if not body or not body.strip():
        return None, ["Invalid or missing JSON body"]

    try:
        data = json.loads(body)
    except json.JSONDecodeError as e:
        return None, [f"Invalid or missing JSON body: {e}"]

    if not isinstance(data, dict):
        return None, ["Payload must be a JSON object"]

    audio_url = data.get("audio_url")
    audio_base64 = data.get("audio_base64")
    conversation_id = data.get("conversation_id")
    sender_id = data.get("sender_id")

    # Normalize to strings if present
    if audio_url is not None and not isinstance(audio_url, str):
        audio_url = str(audio_url)
    if audio_base64 is not None and not isinstance(audio_base64, str):
        audio_base64 = str(audio_base64)
    if conversation_id is not None and not isinstance(conversation_id, str):
        conversation_id = str(conversation_id)
    if sender_id is not None and not isinstance(sender_id, str):
        sender_id = str(sender_id)

    has_url = audio_url and str(audio_url).strip()
    has_base64 = audio_base64 and str(audio_base64).strip()
    if not has_url and not has_base64:
        errors.append("Missing audio: provide audio_url or audio_base64")
    else:
        if has_url and not _is_valid_url(str(audio_url)):
            errors.append("audio_url must be a valid HTTP or HTTPS URL")
        if has_base64 and not _is_valid_base64(str(audio_base64)):
            errors.append("audio_base64 must be valid base64 or a data URI with base64 payload")

    if errors:
        return None, errors

    payload = WebhookPayload(
        audio_url=(str(audio_url).strip() or None) if has_url else None,
        audio_base64=(str(audio_base64).strip() or None) if has_base64 else None,
        conversation_id=(str(conversation_id).strip() or None) if conversation_id else None,
        sender_id=(str(sender_id).strip() or None) if sender_id else None,
    )
    return payload, []
