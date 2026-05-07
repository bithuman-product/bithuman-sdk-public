ARG PYTHON_VERSION=3.13.1
FROM python:${PYTHON_VERSION}-slim

ENV PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libatomic1 \
    libglib2.0-0 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN pip install uv

RUN uv venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

COPY requirements.txt .
RUN uv pip install -r requirements.txt --upgrade && \
    uv pip uninstall opencv-python && \
    uv pip install opencv-python-headless --reinstall

COPY agent.py .

RUN python agent.py download-files

ENTRYPOINT ["python", "agent.py"]
CMD ["start"]
