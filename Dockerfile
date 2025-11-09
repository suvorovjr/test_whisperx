# === BUILDER STAGE ==========================================================
FROM nvidia/cuda:12.8.0-runtime-ubuntu24.04 AS builder

# Build environment
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PATH="/venv/bin:$PATH"

# 1️⃣ Устанавливаем системные зависимости
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-dev build-essential git curl ca-certificates python3.12-dev gcc g++ make && \
    ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    rm -f /usr/lib/python*/EXTERNALLY-MANAGED && \
    apt-get clean && rm -rf /var/lib/apt/lists/* \
    python -m pip install --no-cache-dir poetry==1.8.4 \
    && poetry config virtualenvs.create false

COPY poetry.lock pyproject.toml ./

RUN poetry install --without dev --no-interaction --no-ansi \
    && rm -rf $(poetry config cache-dir)/{cache,artifacts}

RUN pip install --no-cache-dir torch torchvision torchaudio \
    --extra-index-url https://download.pytorch.org/whl/cu128


COPY . .

FROM nvidia/cuda:12.8.1-runtime-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    CUDA_HOME=/usr/local/cuda

# 8️⃣ Устанавливаем системные зависимости для runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-venv python3-pip git curl wget ca-certificates \
    libsm6 libxext6 libxrender-dev libglib2.0-0 libgomp1 && \
    ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    rm -f /usr/lib/python*/EXTERNALLY-MANAGED && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 9️⃣ Копируем окружение и установленные зависимости
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# 🔟 Копируем приложение
WORKDIR /app
COPY . .


COPY entrypoint.sh /web/entrypoint.sh
RUN chmod +x /web/entrypoint.sh

CMD ["/web/entrypoint.sh"]