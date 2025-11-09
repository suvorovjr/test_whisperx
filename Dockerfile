FROM nvidia/cuda:12.8.0-runtime-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TRANSFORMERS_CACHE=/root/.cache/huggingface \
    HF_HOME=/root/.cache/huggingface

WORKDIR /app

# system deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common build-essential wget curl git ca-certificates && \
    add-apt-repository ppa:deadsnakes/ppa && apt-get update && \
    apt-get install -y --no-install-recommends python3.12 python3.12-dev && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN python3.12 -m venv /opt/venv && \
    /opt/venv/bin/python -m ensurepip && \
    /opt/venv/bin/pip install  --upgrade pip setuptools wheel

ENV PATH="/opt/venv/bin:$PATH"

RUN pip install --no-cache-dir "poetry==1.8.4" \
    && poetry config virtualenvs.create false

COPY pyproject.toml poetry.lock ./

# install deps
RUN poetry install --no-interaction --no-ansi \
    && rm -rf $(poetry config cache-dir)/{cache,artifacts}

COPY . .

COPY entrypoint.sh /web/entrypoint.sh
RUN chmod +x /web/entrypoint.sh

ENTRYPOINT ["/web/entrypoint.sh"]