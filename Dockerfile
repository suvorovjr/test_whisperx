# === BUILDER STAGE ==========================================================
FROM nvidia/cuda:12.8.1-devel-ubuntu24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# 1️⃣ Устанавливаем системные зависимости
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv python3-dev \
    build-essential git curl wget ca-certificates gcc g++ make && \
    ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    rm -f /usr/lib/python*/EXTERNALLY-MANAGED && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 2️⃣ Создаём виртуальное окружение
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# 3️⃣ Устанавливаем Poetry (в окружение)
RUN pip install --upgrade pip setuptools wheel && \
    pip install poetry

# 4️⃣ Копируем файлы зависимостей Poetry
WORKDIR /app
COPY pyproject.toml poetry.lock* ./

# 5️⃣ Устанавливаем зависимости проекта без дев-зависимостей
RUN poetry config virtualenvs.create false && \
    poetry install --no-root --only main

# 6️⃣ Устанавливаем PyTorch с поддержкой CUDA 12.8
RUN pip install --no-cache-dir torch torchvision torchaudio \
    --extra-index-url https://download.pytorch.org/whl/cu128

# 7️⃣ Копируем код микросервиса
COPY . .

# === RUNTIME STAGE ==========================================================
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

# Открываем порт FastAPI
EXPOSE 8000

# Запуск через uvicorn (можно заменить на gunicorn)
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]