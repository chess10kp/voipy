"""AWS Lambda handler for Twilio voice webhooks.

Flow:
  1. Caller dials your Twilio number
  2. Twilio POSTs to Lambda Function URL /voice/incoming
     -> Lambda returns TwiML telling Twilio to record the call
  3. When recording finishes, Twilio POSTs to /voice/recording-complete
     -> Lambda downloads audio from Twilio, uploads to S3,
        transcribes with ElevenLabs, saves transcript JSON to S3
"""

import os
import uuid
import json
import datetime
import tempfile
import boto3
from io import BytesIO
from urllib.parse import parse_qs
from urllib.request import urlopen, Request
import base64


# ── Configuration (set as Lambda environment variables) ────────
TWILIO_ACCOUNT_SID = os.environ.get("TWILIO_ACCOUNT_SID", "")
TWILIO_AUTH_TOKEN = os.environ.get("TWILIO_AUTH_TOKEN", "")
ELEVENLABS_API_KEY = os.environ.get("ELEVENLABS_API_KEY", "")
S3_BUCKET_NAME = os.environ.get("S3_BUCKET_NAME", "voipy")
S3_REGION = os.environ.get("S3_REGION", "us-east-2")

# The Function URL of this Lambda — set after first deploy,
# needed so TwiML callbacks point back to this same Lambda.
FUNCTION_URL = os.environ.get("FUNCTION_URL", "")

# ── Clients (reused across warm invocations) ───────────────────
s3_client = boto3.client("s3", region_name=S3_REGION)


# ── Helpers ────────────────────────────────────────────────────


def upload_bytes_to_s3(
    data: bytes, s3_key: str, content_type: str = "audio/wav"
) -> str:
    s3_client.put_object(
        Bucket=S3_BUCKET_NAME,
        Key=s3_key,
        Body=data,
        ContentType=content_type,
    )
    url = f"https://{S3_BUCKET_NAME}.s3.{S3_REGION}.amazonaws.com/{s3_key}"
    print(f"[S3] Uploaded: {url}")
    return url


def download_from_twilio(url: str) -> bytes:
    """Download a file from Twilio using basic auth."""
    credentials = base64.b64encode(
        f"{TWILIO_ACCOUNT_SID}:{TWILIO_AUTH_TOKEN}".encode()
    ).decode()
    req = Request(url, headers={"Authorization": f"Basic {credentials}"})
    with urlopen(req) as resp:
        return resp.read()


def transcribe_audio(audio_bytes: bytes, language: str = "eng") -> str:
    """Transcribe audio bytes using ElevenLabs scribe_v2."""
    # Lazy import — elevenlabs is in the Lambda layer
    from elevenlabs.client import ElevenLabs

    client = ElevenLabs(api_key=ELEVENLABS_API_KEY)
    transcription = client.speech_to_text.convert(
        file=BytesIO(audio_bytes),
        model_id="scribe_v2",
        tag_audio_events=True,
        language_code=language,
        diarize=True,
    )
    return transcription.text or ""


def parse_form_body(event: dict) -> dict:
    """Parse URL-encoded form body from Twilio POST."""
    body = event.get("body", "")
    if event.get("isBase64Encoded"):
        body = base64.b64decode(body).decode("utf-8")
    parsed = parse_qs(body)
    # parse_qs returns lists; flatten to single values
    return {k: v[0] if len(v) == 1 else v for k, v in parsed.items()}


def twiml_response(twiml_str: str) -> dict:
    """Return a Lambda response with TwiML content type."""
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "text/xml"},
        "body": twiml_str,
    }


# ── Route Handlers ─────────────────────────────────────────────


def handle_incoming(form: dict) -> dict:
    """Answer the call and tell Twilio to record it."""
    print(f"[INCOMING] Call from {form.get('From', 'unknown')}")

    twiml = f"""<?xml version="1.0" encoding="UTF-8"?>
<Response>
    <Say voice="alice">Hello, please leave your message after the tone. Press pound or hang up when you are done.</Say>
    <Record
        action="{FUNCTION_URL}/voice/recording-complete"
        recordingStatusCallback="{FUNCTION_URL}/voice/recording-status"
        recordingStatusCallbackEvent="completed"
        maxLength="300"
        timeout="5"
        finishOnKey="#"
        transcribe="false"
        playBeep="true" />
    <Say>No message received. Goodbye.</Say>
</Response>"""

    return twiml_response(twiml)


def handle_recording_complete(form: dict) -> dict:
    """Download recording from Twilio -> S3 -> ElevenLabs -> S3."""
    recording_url = form.get("RecordingUrl", "")
    recording_sid = form.get("RecordingSid", "unknown")
    call_sid = form.get("CallSid", "unknown")
    caller = form.get("From", "unknown")
    duration = form.get("RecordingDuration", "0")

    print(f"[RECORDING] SID={recording_sid} from={caller} duration={duration}s")

    if recording_url:
        audio_url = f"{recording_url}.wav"
        timestamp = datetime.datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        uid = str(uuid.uuid4())[:8]

        try:
            # 1. Download audio from Twilio
            print(f"[DOWNLOAD] {audio_url}")
            audio_data = download_from_twilio(audio_url)

            # 2. Upload audio to S3
            s3_audio_key = f"recordings/{timestamp}_{uid}_{recording_sid}.wav"
            audio_s3_url = upload_bytes_to_s3(audio_data, s3_audio_key, "audio/wav")

            # 3. Transcribe with ElevenLabs
            print("[TRANSCRIBE] Sending to ElevenLabs scribe_v2...")
            transcript = transcribe_audio(audio_data)
            print(f"[TRANSCRIPT] {transcript}")

            # 4. Save transcript JSON to S3
            transcript_payload = json.dumps(
                {
                    "call_sid": call_sid,
                    "recording_sid": recording_sid,
                    "caller": caller,
                    "duration_seconds": int(duration),
                    "timestamp": timestamp,
                    "audio_s3_url": audio_s3_url,
                    "transcript": transcript,
                },
                indent=2,
            )

            s3_transcript_key = f"transcriptions/{timestamp}_{uid}_{recording_sid}.json"
            transcript_s3_url = upload_bytes_to_s3(
                transcript_payload.encode("utf-8"),
                s3_transcript_key,
                "application/json",
            )

            print(f"[DONE] Audio:      {audio_s3_url}")
            print(f"[DONE] Transcript: {transcript_s3_url}")

        except Exception as e:
            print(f"[ERROR] Processing failed: {e}")

    twiml = """<?xml version="1.0" encoding="UTF-8"?>
<Response>
    <Say>Thank you for your message. Goodbye.</Say>
    <Hangup />
</Response>"""

    return twiml_response(twiml)


def handle_recording_status(form: dict) -> dict:
    """Log recording status events (optional, for debugging)."""
    status = form.get("RecordingStatus", "unknown")
    sid = form.get("RecordingSid", "unknown")
    print(f"[STATUS] Recording {sid}: {status}")
    return {"statusCode": 204, "body": ""}


# ── Lambda Entry Point ─────────────────────────────────────────


def handler(event, context):
    """Single Lambda handler that routes based on the URL path.

    Lambda Function URL passes the path in event.rawPath.
    """
    path = event.get("rawPath", "/")
    method = event.get("requestContext", {}).get("http", {}).get("method", "GET")

    print(f"[LAMBDA] {method} {path}")

    # Health check
    if path == "/health" and method == "GET":
        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"status": "ok", "service": "voipy-twilio-webhook"}),
        }

    # All Twilio webhooks are POST with form-encoded body
    form = parse_form_body(event)

    if path == "/voice/incoming":
        return handle_incoming(form)

    elif path == "/voice/recording-complete":
        return handle_recording_complete(form)

    elif path == "/voice/recording-status":
        return handle_recording_status(form)

    else:
        return {
            "statusCode": 404,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "not found", "path": path}),
        }
