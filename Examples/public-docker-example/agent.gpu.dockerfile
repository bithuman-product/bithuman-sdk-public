ARG PYTHON_VERSION=3.13.1
FROM python:${PYTHON_VERSION}-slim


ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libatomic1 \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install uv
RUN pip install uv

# Create virtual environment
RUN uv venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

# Copy requirements and install dependencies
COPY requirements.txt .
RUN uv pip install -r requirements.txt --upgrade && \
    uv pip uninstall opencv-python && \
    uv pip install opencv-python-headless --no-deps

# Install LiveKit agents and plugins from specific commit for GPU endpoint support
ENV LIVEKIT_COMMIT=ca532f35f600f87c8b37c166c9ffec2fea279977
RUN uv pip uninstall livekit-agents livekit-plugins-bithuman livekit-plugins-openai && \
    GIT_LFS_SKIP_SMUDGE=1 uv pip install git+https://github.com/livekit/agents@${LIVEKIT_COMMIT}#subdirectory=livekit-agents && \
    GIT_LFS_SKIP_SMUDGE=1 uv pip install git+https://github.com/livekit/agents@${LIVEKIT_COMMIT}#subdirectory=livekit-plugins/livekit-plugins-openai && \
    GIT_LFS_SKIP_SMUDGE=1 uv pip install git+https://github.com/livekit/agents@${LIVEKIT_COMMIT}#subdirectory=livekit-plugins/livekit-plugins-bithuman

# Copy unified agent code
COPY agent.py .

# Ensure that any dependent models are downloaded at build-time
RUN python agent.py download-files

# Run the application
ENTRYPOINT ["python", "agent.py"]
CMD ["start"]
