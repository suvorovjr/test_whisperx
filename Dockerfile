FROM nvidia/cuda:12.8.1-runtime-ubuntu24.04

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TZ=Europe/Moscow \
    PATH="/venv/bin:$PATH" \
    TRANSFORMERS_CACHE=/root/.cache/huggingface \
    HF_HOME=/root/.cache/huggingface \
    WHISPERX_CACHE_DIR=/root/.cache/whisperx

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-venv python3-pip python3-dev python-is-python3 \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /venv

RUN pip install --upgrade pip setuptools wheel

RUN python -m pip install --no-cache-dir poetry==1.8.4

COPY poetry.lock pyproject.toml ./

RUN poetry install --no-interaction --no-ansi \
    && rm -rf $(poetry config cache-dir)/{cache,artifacts}


    
COPY . .

COPY entrypoint.sh /web/entrypoint.sh
RUN chmod +x /web/entrypoint.sh

ENTRYPOINT ["/web/entrypoint.sh"]