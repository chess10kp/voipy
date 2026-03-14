import os
import uuid

import assemblyai as aai

from typing import List
from termcolor import colored
from datetime import timedelta
from dotenv import load_dotenv
load_dotenv()
import sounddevice as sd
import numpy as np
from scipy.io.wavfile import write
import keyboard
import time

# Configuration
FS = 44100  # Sample rate
CHANNELS = 1
FILENAME = "output.wav"

# State management
RECORD = False
audio_data = []
ASSEMBLY_AI_API_KEY = os.getenv("ASSEMBLY_AI_API_KEY")
# print(f'{ASSEMBLY_AI_API_KEY=}')
def add_audio():
    toggle_record()    
    if not RECORD and os.path.exists(FILENAME):
        print("Generating subtitles...")
        subtitles = __generate_subtitles_assemblyai(FILENAME, voice="en")
        subtitle_file = "subtitles.txt"
        with open(subtitle_file, "a", encoding="utf-8") as f:
            t = [subtitles[i:i+111]+'\n' for i in range(0,len(subtitles),111)]
            f.writelines(t)

        print(f"Subtitles saved to {subtitle_file}")
# Add the hotkey toggle
keyboard.add_hotkey('`', add_audio)

def toggle_record():
    global RECORD, audio_data
    RECORD = not RECORD
    if RECORD:
        audio_data = [] # Reset buffer for new recording
        print("--- Recording Started ---")
    else:
        print("--- Recording Stopped ---")
        save_recording()

def save_recording():
    if audio_data:
        # Stack all the recorded chunks into one array
        recording_array = np.concatenate(audio_data, axis=0)
        write(FILENAME, FS, recording_array)
        print(f"File saved as {FILENAME}")

def callback(indata, frames, time, status):
    """This is called by sounddevice for every audio chunk"""
    if RECORD:
        audio_data.append(indata.copy())



def __generate_subtitles_assemblyai(audio_path: str, voice: str = "en") -> str:
    """
    Generates subtitles from a given audio file and returns the path to the subtitles.

    Args:
        audio_path (str): The path to the audio file to generate subtitles from.

    Returns:
        str: The generated subtitles
    """

    language_mapping = {
        "br": "pt",
        "id": "en", #AssemblyAI doesn't have Indonesian 
        "jp": "ja",
        "kr": "ko",
    }

    if voice in language_mapping:
        lang_code = language_mapping[voice]
    else:
        lang_code = voice

    aai.settings.api_key = ASSEMBLY_AI_API_KEY
    config = aai.TranscriptionConfig(language_code=lang_code)
    transcriber = aai.Transcriber(config=config)
    transcript = transcriber.transcribe(audio_path)
    subtitles = transcript.text or ''

    return subtitles


print("Press '`' to start/stop recording. Press 'Esc' to exit.")

# Start the stream in the background
with sd.InputStream(samplerate=FS, channels=CHANNELS, callback=callback):
    # Keep the main thread alive until we hit 'esc'
    keyboard.wait('esc')
