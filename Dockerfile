FROM nvidia/cuda:13.0.2-cudnn-devel-ubuntu24.04


WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TZ=Europe/Moscow \
    PATH="/venv/bin:$PATH" \
    TRANSFORMERS_CACHE=/root/.cache/huggingface \
    HUGGINGFACE_HUB_CACHE=/root/.cache/huggingface \
    HF_HOME=/root/.cache/huggingface

RUN apt-get update && apt-get install -y \
    software-properties-common curl ffmpeg libgomp1 git \
    python3.12 python3.12-venv python3.12-dev \
    && ln -sf /usr/bin/python3.12 /usr/bin/python \
    && curl -sS https://bootstrap.pypa.io/get-pip.py | python \
    && pip install --upgrade pip

RUN pip install --no-cache-dir "poetry==1.8.4" \
    && poetry config virtualenvs.create false

COPY poetry.lock pyproject.toml ./

RUN poetry install --no-interaction --no-ansi \
    && rm -rf $(poetry config cache-dir)/{cache,artifacts}

COPY . .

COPY entrypoint.sh /web/entrypoint.sh

RUN chmod +x /web/entrypoint.sh

ENTRYPOINT [ "/web/entrypoint.sh" ]