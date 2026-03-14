"""Voice recorder with ElevenLabs transcription and S3 upload."""

import os;
import uuid;
import time;
import boto3;
import keyboard;
import numpy as np;
import sounddevice as sd;
import from io { BytesIO }
import from scipy.io.wavfile { write as wav_write }
import from dotenv { load_dotenv }
import from elevenlabs.client { ElevenLabs }

load_dotenv();

# ── Configuration ──────────────────────────────────────────────
glob FS: int = 44100;
glob CHANNELS: int = 1;
glob FILENAME: str = "output.wav";

# ── State ──────────────────────────────────────────────────────
glob RECORD: bool = False;
glob audio_data: list = [];

# ── API keys from environment ─────────────────────────────────
glob ELEVENLABS_API_KEY: str = os.getenv("ELEVENLABS_API_KEY", "");
glob AWS_ACCESS_KEY: str = os.getenv("AWS_ACCESS_KEY", "");
glob AWS_SECRET_KEY: str = os.getenv("AWS_SECRET_KEY", "");
glob S3_BUCKET_NAME: str = os.getenv("S3_BUCKET_NAME", "");
glob S3_REGION: str = os.getenv("S3_REGION", "us-east-1");

# ── Clients ───────────────────────────────────────────────────
glob elevenlabs_client: Any = ElevenLabs(api_key=ELEVENLABS_API_KEY);
glob s3_client: Any = boto3.client(
    "s3",
    aws_access_key_id=AWS_ACCESS_KEY,
    aws_secret_access_key=AWS_SECRET_KEY,
    region_name=S3_REGION
);

# ── S3 Upload ─────────────────────────────────────────────────
def upload_to_s3(file_path: str, s3_key: str) -> str {
    s3_client.upload_file(file_path, S3_BUCKET_NAME, s3_key);
    url = f"https://{S3_BUCKET_NAME}.s3.{S3_REGION}.amazonaws.com/{s3_key}";
    print(f"Uploaded to S3: {url}");
    return url;
}

# ── ElevenLabs Transcription ──────────────────────────────────
def generate_subtitles_elevenlabs(audio_path: str, language: str = "eng") -> str {
    f = open(audio_path, "rb");
    audio_bytes = BytesIO(f.read());
    f.close();

    transcription = elevenlabs_client.speech_to_text.convert(
        file=audio_bytes,
        model_id="scribe_v2",
        tag_audio_events=True,
        language_code=language,
        diarize=True
    );
    return transcription.text or "";
}

# ── Recording helpers ─────────────────────────────────────────
def save_recording() -> None {
    if audio_data {
        recording_array = np.concatenate(audio_data, axis=0);
        wav_write(FILENAME, FS, recording_array);
        print(f"File saved as {FILENAME}");
    }
}

def callback(indata: Any, frames: int, time_info: Any, status: Any) -> None {
    """Called by sounddevice for every audio chunk."""
    if RECORD {
        audio_data.append(indata.copy());
    }
}

def toggle_record() -> None {
    RECORD = not RECORD;
    if RECORD {
        audio_data.clear();
        print("--- Recording Started ---");
    } else {
        print("--- Recording Stopped ---");
        save_recording();
    }
}

def add_audio() -> None {
    toggle_record();
    if not RECORD and os.path.exists(FILENAME) {
        print("Transcribing with ElevenLabs...");
        subtitles = generate_subtitles_elevenlabs(FILENAME, language="eng");
        subtitle_file = "subtitles.txt";
        f = open(subtitle_file, "a", encoding="utf-8");
        t = [subtitles[i:i + 111] + "\n" for i in range(0, len(subtitles), 111)];
        f.writelines(t);
        f.close();
        print(f"Subtitles saved to {subtitle_file}");

        # Upload audio and subtitles to S3
        timestamp = str(uuid.uuid4())[:8];
        audio_s3_key = f"recordings/{timestamp}_{FILENAME}";
        subtitle_s3_key = f"transcriptions/{timestamp}_{subtitle_file}";
        upload_to_s3(FILENAME, audio_s3_key);
        upload_to_s3(subtitle_file, subtitle_s3_key);
    }
}

# ── Main entry ────────────────────────────────────────────────
with entry {
    keyboard.add_hotkey("`", add_audio);
    print("Press '`' to start/stop recording. Press 'Esc' to exit.");
    stream = sd.InputStream(samplerate=FS, channels=CHANNELS, callback=callback);
    stream.start();
    keyboard.wait("esc");
    stream.stop();
    stream.close();
}
