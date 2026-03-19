# ─── RunPod Serverless: AI Dance Motion (Face Lock) ──────────────────────────
# ComfyUI + WanVideo + SAM2 + VitPose + ControlNet
# Models are loaded from Network Volume at /runpod-volume
# ──────────────────────────────────────────────────────────────────────────────

FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04 AS base

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    COMFY_DIR=/workspace/ComfyUI \
    NETWORK_VOLUME=/runpod-volume

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ─── System packages ─────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.10 python3.10-venv python3-pip python3.10-dev \
    git wget curl ffmpeg libgl1-mesa-glx libglib2.0-0 \
    libsm6 libxext6 libxrender-dev build-essential \
    && ln -sf /usr/bin/python3.10 /usr/bin/python \
    && ln -sf /usr/bin/python3.10 /usr/bin/python3 \
    && rm -rf /var/lib/apt/lists/*

# ─── Python base packages ────────────────────────────────────────────────────
RUN pip install --upgrade pip setuptools wheel

# ─── Install ComfyUI ─────────────────────────────────────────────────────────
RUN git clone https://github.com/comfyanonymous/ComfyUI.git ${COMFY_DIR} && \
    cd ${COMFY_DIR} && \
    pip install -r requirements.txt

# ─── Install ComfyUI Manager ─────────────────────────────────────────────────
RUN cd ${COMFY_DIR}/custom_nodes && \
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git

# ─── Install Custom Nodes (required by workflow) ──────────────────────────────
COPY scripts/install_custom_nodes.sh /tmp/install_custom_nodes.sh
RUN chmod +x /tmp/install_custom_nodes.sh && bash /tmp/install_custom_nodes.sh

# ─── Install RunPod SDK ───────────────────────────────────────────────────────
RUN pip install runpod requests

# ─── Copy handler + startup scripts ──────────────────────────────────────────
COPY handler.py /workspace/handler.py
COPY scripts/start.sh /workspace/start.sh
RUN chmod +x /workspace/start.sh

# ─── Create workflow directory ────────────────────────────────────────────────
RUN mkdir -p ${COMFY_DIR}/workflows ${COMFY_DIR}/input ${COMFY_DIR}/output ${COMFY_DIR}/temp

# ─── Copy workflow JSON (must be provided at build time) ──────────────────────
# Place your dance_workflow.json in the project root before building
COPY dance_workflow.json ${COMFY_DIR}/workflows/dance_workflow.json

# ─── Symlink model directories to Network Volume ─────────────────────────────
# Models will be loaded from Network Volume at runtime
COPY scripts/link_models.sh /workspace/link_models.sh
RUN chmod +x /workspace/link_models.sh

WORKDIR /workspace

# RunPod health check port
EXPOSE 8188

CMD ["/workspace/start.sh"]
