"""Twilio webhook server for inbound calls.

Flow:
  1. Caller dials your Twilio number
  2. Twilio POSTs to /voice/incoming -> we respond with TwiML to record
  3. When recording finishes, Twilio POSTs to /voice/recording-complete
  4. We download the audio, upload to S3, transcribe with ElevenLabs
  5. Transcription is saved to S3 and printed for processing
"""

import os
import uuid
import json
import datetime
import tempfile
import requests
import boto3
from io import BytesIO
from flask import Flask, request, jsonify
from twilio.twiml.voice_response import VoiceResponse
from twilio.request_validator import RequestValidator
from dotenv import load_dotenv
from elevenlabs.client import ElevenLabs

load_dotenv()

# ── Configuration ──────────────────────────────────────────────
TWILIO_ACCOUNT_SID = os.getenv("TWILIO_ACCOUNT_SID", "")
TWILIO_AUTH_TOKEN = os.getenv("TWILIO_AUTH_TOKEN", "")
ELEVENLABS_API_KEY = os.getenv("ELEVENLABS_API_KEY", "")
AWS_ACCESS_KEY = os.getenv("AWS_ACCESS_KEY", "")
AWS_SECRET_KEY = os.getenv("AWS_SECRET_KEY", "")
S3_BUCKET_NAME = os.getenv("S3_BUCKET_NAME", "voipy")
S3_REGION = os.getenv("S3_REGION", "us-east-2")
WEBHOOK_PORT = int(os.getenv("WEBHOOK_PORT", "5000"))

# Base URL for your public-facing server (ngrok, etc.)
# Twilio needs to reach this URL from the internet.
BASE_URL = os.getenv("BASE_URL", f"http://localhost:{WEBHOOK_PORT}")

# ── Clients ────────────────────────────────────────────────────
elevenlabs_client = ElevenLabs(api_key=ELEVENLABS_API_KEY)
s3_client = boto3.client(
    "s3",
    aws_access_key_id=AWS_ACCESS_KEY,
    aws_secret_access_key=AWS_SECRET_KEY,
    region_name=S3_REGION,
)

app = Flask(__name__)


# ── Helpers ────────────────────────────────────────────────────


def upload_to_s3(file_path: str, s3_key: str) -> str:
    """Upload a local file to S3 and return the public URL."""
    s3_client.upload_file(file_path, S3_BUCKET_NAME, s3_key)
    url = f"https://{S3_BUCKET_NAME}.s3.{S3_REGION}.amazonaws.com/{s3_key}"
    print(f"[S3] Uploaded: {url}")
    return url


def upload_bytes_to_s3(
    data: bytes, s3_key: str, content_type: str = "audio/wav"
) -> str:
    """Upload bytes directly to S3."""
    s3_client.put_object(
        Bucket=S3_BUCKET_NAME,
        Key=s3_key,
        Body=data,
        ContentType=content_type,
    )
    url = f"https://{S3_BUCKET_NAME}.s3.{S3_REGION}.amazonaws.com/{s3_key}"
    print(f"[S3] Uploaded: {url}")
    return url


def transcribe_audio(audio_path: str, language: str = "eng") -> str:
    """Transcribe an audio file using ElevenLabs scribe_v2."""
    with open(audio_path, "rb") as f:
        audio_bytes = BytesIO(f.read())

    transcription = elevenlabs_client.speech_to_text.convert(
        file=audio_bytes,
        model_id="scribe_v2",
        tag_audio_events=True,
        language_code=language,
        diarize=True,
    )
    return transcription.text or ""


# ── Webhook Routes ─────────────────────────────────────────────


@app.route("/voice/incoming", methods=["POST"])
def handle_incoming_call():
    """Twilio calls this when someone dials your number.

    Responds with TwiML that:
      1. Plays a greeting
      2. Records the caller (up to 5 min, stops on silence or '#')
      3. Sends the recording to /voice/recording-complete
    """
    resp = VoiceResponse()

    # Optional greeting before recording
    resp.say(
        "Hello, please leave your message after the tone. "
        "Press pound or hang up when you're done.",
        voice="alice",
    )

    # Record the call
    resp.record(
        action=f"{BASE_URL}/voice/recording-complete",
        recording_status_callback=f"{BASE_URL}/voice/recording-status",
        recording_status_callback_event="completed",
        max_length=300,  # max 5 minutes
        timeout=5,  # stop after 5s of silence
        finish_on_key="#",  # or press # to stop
        transcribe=False,  # we use ElevenLabs, not Twilio's transcription
        play_beep=True,
    )

    # If they don't record anything, hang up gracefully
    resp.say("No message received. Goodbye.")

    print(f"[INCOMING] Call from {request.form.get('From', 'unknown')}")
    return str(resp), 200, {"Content-Type": "text/xml"}


@app.route("/voice/recording-complete", methods=["POST"])
def handle_recording_complete():
    """Twilio calls this after the caller finishes recording.

    The recording URL is in the POST body. We:
      1. Download the audio from Twilio
      2. Upload it to S3
      3. Transcribe with ElevenLabs
      4. Upload the transcription to S3
      5. Return TwiML to end the call
    """
    recording_url = request.form.get("RecordingUrl", "")
    recording_sid = request.form.get("RecordingSid", "unknown")
    call_sid = request.form.get("CallSid", "unknown")
    caller = request.form.get("From", "unknown")
    duration = request.form.get("RecordingDuration", "0")

    print(f"[RECORDING] SID={recording_sid} from={caller} duration={duration}s")

    if not recording_url:
        print("[ERROR] No RecordingUrl in callback")
        resp = VoiceResponse()
        resp.say("Thank you. Goodbye.")
        resp.hangup()
        return str(resp), 200, {"Content-Type": "text/xml"}

    # Twilio serves recordings as .wav at RecordingUrl.wav
    audio_url = f"{recording_url}.wav"
    timestamp = datetime.datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    uid = str(uuid.uuid4())[:8]

    try:
        # 1. Download the recording from Twilio (requires auth)
        print(f"[DOWNLOAD] Fetching {audio_url}")
        audio_response = requests.get(
            audio_url,
            auth=(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN),
        )
        audio_response.raise_for_status()
        audio_data = audio_response.content

        # 2. Upload audio to S3
        s3_audio_key = f"recordings/{timestamp}_{uid}_{recording_sid}.wav"
        audio_s3_url = upload_bytes_to_s3(audio_data, s3_audio_key, "audio/wav")

        # 3. Save to temp file and transcribe with ElevenLabs
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            tmp.write(audio_data)
            tmp_path = tmp.name

        print("[TRANSCRIBE] Sending to ElevenLabs scribe_v2...")
        transcript = transcribe_audio(tmp_path)
        os.unlink(tmp_path)

        print(f"[TRANSCRIPT] {transcript}")

        # 4. Upload transcription to S3
        transcript_data = json.dumps(
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
            transcript_data.encode("utf-8"),
            s3_transcript_key,
            "application/json",
        )

        print(f"[DONE] Audio: {audio_s3_url}")
        print(f"[DONE] Transcript: {transcript_s3_url}")

    except Exception as e:
        print(f"[ERROR] Processing recording failed: {e}")

    # Respond with TwiML to end the call
    resp = VoiceResponse()
    resp.say("Thank you for your message. Goodbye.")
    resp.hangup()
    return str(resp), 200, {"Content-Type": "text/xml"}


@app.route("/voice/recording-status", methods=["POST"])
def handle_recording_status():
    """Optional: Twilio sends recording status events here.

    Useful for logging/debugging. Not required for the main flow.
    """
    status = request.form.get("RecordingStatus", "unknown")
    sid = request.form.get("RecordingSid", "unknown")
    print(f"[STATUS] Recording {sid}: {status}")
    return "", 204


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok", "service": "twilio-webhook"}), 200


# ── Entry Point ────────────────────────────────────────────────

if __name__ == "__main__":
    print("=" * 50)
    print("Twilio Webhook Server")
    print("=" * 50)
    print(f"Port:     {WEBHOOK_PORT}")
    print(f"Base URL: {BASE_URL}")
    print()
    print("Endpoints:")
    print(
        f"  POST {BASE_URL}/voice/incoming           <- Twilio 'A Call Comes In' webhook"
    )
    print(f"  POST {BASE_URL}/voice/recording-complete  <- Recording callback (auto)")
    print(f"  POST {BASE_URL}/voice/recording-status    <- Status callback (auto)")
    print(f"  GET  {BASE_URL}/health                    <- Health check")
    print()
    print("Make sure BASE_URL is publicly reachable (use ngrok if local).")
    print("=" * 50)

    app.run(host="0.0.0.0", port=WEBHOOK_PORT, debug=False)
