from __future__ import annotations

import os
from typing import Generator
from pathlib import Path
from uuid import uuid4
from datetime import datetime
from uuid import UUID
from pydantic import BaseModel, Field
import logging
from enum import Enum
from dotenv import load_dotenv
import time

import whisperx # type: ignore
from whisperx.diarize import DiarizationPipeline # type: ignore
from pydub import AudioSegment # type: ignore
from pydub import silence # type: ignore

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv(".env")

SILENCE_TIME = 5.0 # seconds



class TimestampMixin(BaseModel):
    """Миксин для работы с временными метками"""

    created_at: datetime = Field(default_factory=datetime.now)
    updated_at: datetime = Field(default_factory=datetime.now)

    def touch(self) -> None:
        self.updated_at = datetime.now()

class TranscriptionStatus(str, Enum):
    """Статус транскрипции"""

    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"


class Transcription(TimestampMixin):
    """Доменная модель транскрипции"""

    audio_id: UUID
    audio_url: str
    project_id: UUID
    status: TranscriptionStatus
    segments: list["TranscriptionSegment"] = Field(default_factory=list)

    def __repr__(self) -> str:
        return (
            f"Transcription(audio_id={self.audio_id}, audio_url={self.audio_url}, "
            f"project_id={self.project_id}, status={self.status}, segments={self.segments})"
        )

    @classmethod
    def create(cls, audio_id: UUID, audio_url: str, project_id: UUID) -> "Transcription":
        return cls(audio_id=audio_id, audio_url=audio_url, project_id=project_id, status=TranscriptionStatus.PROCESSING)

    def create_segment(self, text: str, start_time: float, end_time: float) -> TranscriptionSegment:
        segment = TranscriptionSegment.create(self.audio_id, start_time, end_time, text)
        self.segments.append(segment)
        self.touch()
        return segment

    def complete_status(self) -> None:
        self.status = TranscriptionStatus.COMPLETED
        self.touch()

    def fail_status(self) -> None:
        self.status = TranscriptionStatus.FAILED
        self.touch()

    def add_segment(self, segment: "TranscriptionSegment") -> None:
        self.segments.append(segment)
        self.touch()

    def create_silence_segment(self, start_time: float, end_time: float) -> TranscriptionSegment | None:
        if (end_time - start_time) < SILENCE_TIME:
            return None
        if self._silence_overlaps_existing_segment(start_time, end_time):
            return None
        segment = self.create_segment(text="", start_time=start_time, end_time=end_time)
        segment.mark_as_silence()
        self.segments.append(segment)
        return segment

    def _silence_overlaps_existing_segment(self, start_time: float, end_time: float) -> bool:
        for segment in self.segments:
            if not (end_time <= segment.start_time or start_time >= segment.end_time):
                return True
        return False

class TranscriptionSegment(TimestampMixin):
    """Доменная модель сегмента транскрипции"""

    id: UUID = Field(default_factory=uuid4)
    audio_id: UUID
    start_time: float
    end_time: float
    text: str
    speaker: str | None = Field(default=None)
    is_silence: bool = Field(default=False)

    def __str__(self) -> str:
        return f"start_time: {self.start_time}, end_time: {self.end_time}, text: {self.text}"

    def __repr__(self) -> str:
        return (
            f"TranscriptionSegment(id={self.id}, audio_id={self.audio_id}, start_time={self.start_time}, "
            f"end_time={self.end_time}, text={self.text}, speaker={self.speaker})"
        )

    @classmethod
    def create(cls, audio_id: UUID, start_time: float, end_time: float, text: str) -> "TranscriptionSegment":
        return cls(id=uuid4(), audio_id=audio_id, start_time=start_time, end_time=end_time, text=text)

    def update_speaker(self, speaker: str) -> None:
        self.speaker = speaker
        self.touch()

    def mark_as_silence(self):
        self.is_slience = True
        self.text = ""
        self.speaker = None
        self.touch()

class WhisperXTranscriber:
    def __init__(self, model_size: str, device: str, compute_type: str, hg_token: str):
        self._device = device
        self._model = whisperx.load_model(model_size, device, compute_type=compute_type)
        self._diarize_model = DiarizationPipeline(use_auth_token=hg_token, device=device)
        self._hg_token = hg_token

    def transcribe(self, audio: str | Path) -> Generator[TranscriptionSegment, None]:
        result = self._model.transcribe(audio, batch_size=16, chunk_size=30)
        model_a, metadata = whisperx.load_align_model(language_code=result["language"], device=self._device)
        result = whisperx.align(result["segments"], model_a, metadata, audio, self._device, return_char_alignments=False)
        diarize_segments = self._diarize_model(audio)
        result = whisperx.assign_word_speakers(diarize_segments, result)
        for seg in result["segments"]:
            yield TranscriptionSegment(
                audio_id=uuid4(),
                start_time=float(seg["start"]),
                end_time=float(seg["end"]),
                text=seg["text"].strip(),
                speaker=seg.get("speaker")
            )
    
    def find_silence(self, transcription: Transcription, path: str | Path) -> Generator[TranscriptionSegment, None]:
        audio = AudioSegment.from_file(path)
        silent_ranges = silence.detect_nonsilent(audio, min_silence_len=int(SILENCE_TIME * 1000), silence_thresh=-10)
        for start, end in silent_ranges:
            silence_segment = transcription.create_silence_segment(start / 1000, end / 1000)
            if silence_segment is not None:
                yield silence_segment


if __name__ == "__main__":
    model_size = os.getenv("MODEL_SIZE")
    device = os.getenv("DEVICE")
    compute_type = os.getenv("COMPUTE_TYPE")
    hg_token = os.getenv("HG_TOKEN")
    
    if model_size is None or device is None or compute_type is None or hg_token is None:
        raise ValueError("MODEL_SIZE, DEVICE, COMPUTE_TYPE, HG_TOKEN must be set")
    logger.info(f"Starting transcription with model size: {model_size}, device: {device}, compute type: {compute_type}")
    transcriber = WhisperXTranscriber(model_size, device, compute_type, hg_token)
    start_time = time.time()
    logger.info(f"Start time: {start_time}")
    transcription = Transcription.create(audio_id=uuid4(), audio_url="", project_id=uuid4())
    for segment in transcriber.transcribe("audios/test.mp3"):
        logger.info(f"Transcribing segment: {segment}")
        transcription.add_segment(segment)
    for segment in transcriber.find_silence(transcription, "audios/test.mp3"):
        logger.info(f"Finding silence segment: {segment}")
    end_time = time.time()
    logger.info(f"End time: {end_time}")
    logger.info(f"Time taken: {end_time - start_time} seconds")
    print(transcription)
