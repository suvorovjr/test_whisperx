# === BUILDER STAGE ==========================================================
FROM nvidia/cuda:12.8.1-devel-ubuntu24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# Устанавливаем системные зависимости
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv python3-dev \
    build-essential git curl wget ca-certificates gcc g++ make && \
    ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    rm -f /usr/lib/python*/EXTERNALLY-MANAGED && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Устанавливаем PyTorch с поддержкой CUDA 12.8
RUN pip install --no-cache-dir torch torchvision torchaudio \
    --extra-index-url https://download.pytorch.org/whl/cu128

# Создаём виртуальное окружение
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Устанавливаем зависимости проекта (через requirements.txt или poetry)
COPY requirements.txt /tmp/requirements.txt
RUN pip install --upgrade pip setuptools wheel && \
    pip install -r /tmp/requirements.txt

# === RUNTIME STAGE ==========================================================
FROM nvidia/cuda:12.8.1-runtime-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    CUDA_HOME=/usr/local/cuda

# Устанавливаем минимальный набор библиотек для FastAPI
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-venv python3-pip git curl wget ca-certificates \
    libsm6 libxext6 libxrender-dev libglib2.0-0 libgomp1 && \
    ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    rm -f /usr/lib/python*/EXTERNALLY-MANAGED && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Копируем окружение и зависимости
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Копируем код микросервиса
WORKDIR /app
COPY . .

# Открываем порт FastAPI
EXPOSE 8000

# Запуск через uvicorn
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]