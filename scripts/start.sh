#!/bin/bash
# ─── Startup script for RunPod Serverless container ──────────────────────────
set -e

echo "=== AI Dance Motion Serverless Worker Starting ==="
echo "Time: $(date)"

# ── Step 1: Link models from Network Volume ──────────────────────────────────
if [ -d "${NETWORK_VOLUME:-/runpod-volume}" ]; then
    echo "Network Volume found at ${NETWORK_VOLUME:-/runpod-volume}"
    /workspace/link_models.sh
else
    echo "⚠ WARNING: Network Volume not found at ${NETWORK_VOLUME:-/runpod-volume}"
    echo "  Models must be present locally or jobs will fail."
fi

# ── Step 2: Start ComfyUI in background ──────────────────────────────────────
echo ""
echo "=== Starting ComfyUI ==="
cd ${COMFY_DIR:-/workspace/ComfyUI}
python main.py \
    --listen 0.0.0.0 \
    --port 8188 \
    --disable-auto-launch \
    --disable-metadata \
    > /tmp/comfy.log 2>&1 &

COMFY_PID=$!
echo "ComfyUI PID: ${COMFY_PID}"

# Wait for ComfyUI to be ready
echo "Waiting for ComfyUI to be ready..."
MAX_WAIT=180
WAITED=0
while [ ${WAITED} -lt ${MAX_WAIT} ]; do
    if curl -s http://127.0.0.1:8188/system_stats > /dev/null 2>&1; then
        echo "✓ ComfyUI is ready! (waited ${WAITED}s)"
        break
    fi
    sleep 2
    WAITED=$((WAITED + 2))
    if [ $((WAITED % 20)) -eq 0 ]; then
        echo "  Still waiting... (${WAITED}s)"
    fi
done

if [ ${WAITED} -ge ${MAX_WAIT} ]; then
    echo "✗ ComfyUI failed to start within ${MAX_WAIT}s"
    echo "Last 50 lines of comfy.log:"
    tail -50 /tmp/comfy.log
    exit 1
fi

# ── Step 3: Start RunPod handler ─────────────────────────────────────────────
echo ""
echo "=== Starting RunPod Serverless Handler ==="
cd /workspace
exec python handler.py
