import os
import logging
import whisperx # type: ignore
from whisperx.diarize import DiarizationPipeline # type: ignore

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("prewarm")

WHISPERX_MODEL = os.getenv("WHISPERX_MODEL_SIZE", "large-v3")
DEVICE = os.getenv("WHISPERX_DEVICE", "cuda")
COMPUTE_TYPE = os.getenv("WHISPERX_COMPUTE_TYPE", "float16")
HG_TOKEN = os.getenv("HUGGING_FACE_TOKEN")

def main():
    logger.info(f"🔹 Loading WhisperX model: {WHISPERX_MODEL} on {DEVICE} ({COMPUTE_TYPE})")
    asr_model = whisperx.load_model(
        WHISPERX_MODEL,
        device=DEVICE,
        compute_type=COMPUTE_TYPE,
        download_root="/models"
    )

    logger.info("🔹 Loading alignment model...")
    model_a, metadata = whisperx.load_align_model(
        language_code="ru",
        device=DEVICE,
        download_root="/models"
    )

    if HG_TOKEN:
        logger.info("🔹 Loading diarization model (pyannote)...")
        diarize_model = DiarizationPipeline(
            use_auth_token=HG_TOKEN,
            device=DEVICE,
            cache_dir="/models"
        )
    else:
        logger.warning("⚠️ HUGGING_FACE_TOKEN not set — diarization will NOT be cached")

    logger.info("✅ WhisperX models prewarm completed successfully.")

if __name__ == "__main__":
    main()