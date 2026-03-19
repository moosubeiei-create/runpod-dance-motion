#!/bin/bash
# ─── Symlink model directories from Network Volume ───────────────────────────
# Run at container startup to connect ComfyUI model dirs to Network Volume
# Network Volume path: /runpod-volume
# ──────────────────────────────────────────────────────────────────────────────
set -e

COMFY_DIR="${COMFY_DIR:-/workspace/ComfyUI}"
NV="${NETWORK_VOLUME:-/runpod-volume}"
MODELS_DIR="${NV}/models"

echo "=== Linking models from Network Volume: ${NV} ==="

# Create model subdirectories on Network Volume if they don't exist
mkdir -p "${MODELS_DIR}/checkpoints"
mkdir -p "${MODELS_DIR}/loras"
mkdir -p "${MODELS_DIR}/clip"
mkdir -p "${MODELS_DIR}/vae"
mkdir -p "${MODELS_DIR}/clip_vision"
mkdir -p "${MODELS_DIR}/sam2"
mkdir -p "${MODELS_DIR}/onnx"           # vitpose, yolo models
mkdir -p "${MODELS_DIR}/controlnet"

# ── Symlink each model category ──────────────────────────────────────────────
# Remove existing dirs and replace with symlinks
MODEL_CATEGORIES=(
    "checkpoints"
    "loras"
    "clip"
    "vae"
    "clip_vision"
)

for cat in "${MODEL_CATEGORIES[@]}"; do
    target="${COMFY_DIR}/models/${cat}"
    source="${MODELS_DIR}/${cat}"
    if [ -L "${target}" ]; then
        echo "  ✓ ${cat} already linked"
    elif [ -d "${target}" ]; then
        # Move any existing files to Network Volume, then symlink
        cp -rn "${target}"/* "${source}/" 2>/dev/null || true
        rm -rf "${target}"
        ln -sf "${source}" "${target}"
        echo "  → Linked ${cat}"
    else
        ln -sf "${source}" "${target}"
        echo "  → Linked ${cat} (new)"
    fi
done

# ── SAM2 model path (custom node specific) ───────────────────────────────────
# ComfyUI-SAM2 typically looks for models in models/sam2/
SAM2_TARGET="${COMFY_DIR}/models/sam2"
if [ ! -L "${SAM2_TARGET}" ]; then
    rm -rf "${SAM2_TARGET}" 2>/dev/null || true
    ln -sf "${MODELS_DIR}/sam2" "${SAM2_TARGET}"
    echo "  → Linked sam2"
fi

# ── ONNX models for pose detection ───────────────────────────────────────────
# wananimatepreprocess looks for models in its own directory or models/onnx
ONNX_TARGET="${COMFY_DIR}/models/onnx"
if [ ! -L "${ONNX_TARGET}" ]; then
    rm -rf "${ONNX_TARGET}" 2>/dev/null || true
    ln -sf "${MODELS_DIR}/onnx" "${ONNX_TARGET}"
    echo "  → Linked onnx"
fi

# ── Detection models (wananimatepreprocess) ─────────────────────────────────
DETECT_TARGET="${COMFY_DIR}/models/detection"
if [ ! -L "${DETECT_TARGET}" ]; then
    rm -rf "${DETECT_TARGET}" 2>/dev/null || true
    ln -sf "${MODELS_DIR}/onnx" "${DETECT_TARGET}"
    echo "  → Linked detection"
fi

# ── DWPreprocessor models (controlnet_aux) ────────────────────────────────────
DW_TARGET="${COMFY_DIR}/custom_nodes/comfyui_controlnet_aux/ckpts"
mkdir -p "${DW_TARGET}" 2>/dev/null || true
# Link dwpose models
if [ -d "${MODELS_DIR}/onnx" ]; then
    ln -sf "${MODELS_DIR}/onnx/dw-ll_ucoco_384_bs5.torchscript.pt" "${DW_TARGET}/" 2>/dev/null || true
    ln -sf "${MODELS_DIR}/onnx/yolox_l.onnx" "${DW_TARGET}/" 2>/dev/null || true
    echo "  → Linked DWPreprocessor models"
fi

echo "=== Model linking complete ==="

# ── Verify critical models exist ─────────────────────────────────────────────
echo ""
echo "=== Checking critical models ==="
MISSING=0

check_model() {
    local path="$1"
    local name="$2"
    if [ -f "${path}" ]; then
        local size=$(du -h "${path}" | cut -f1)
        echo "  ✓ ${name} (${size})"
    else
        echo "  ✗ MISSING: ${name} → ${path}"
        MISSING=$((MISSING + 1))
    fi
}

check_model "${MODELS_DIR}/checkpoints/Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors" "Wan2.2 Animate 14B (main model)"
check_model "${MODELS_DIR}/loras/Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors" "LoRA: Fun-A14B-InP"
check_model "${MODELS_DIR}/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors" "LoRA: LightX2V 4-steps"
check_model "${MODELS_DIR}/clip/umt5_xxl_fp8_e4m3fn_scaled.safetensors" "UMT5-XXL (text encoder)"
check_model "${MODELS_DIR}/vae/wan_2.1_vae.safetensors" "Wan 2.1 VAE"
check_model "${MODELS_DIR}/clip_vision/clip_vision_h.safetensors" "CLIP Vision H"
check_model "${MODELS_DIR}/sam2/sam2.1_hiera_base_plus.safetensors" "SAM2.1 Hiera Base+"
check_model "${MODELS_DIR}/onnx/vitpose-l-wholebody.onnx" "VitPose-L Wholebody"
check_model "${MODELS_DIR}/onnx/yolov10m.onnx" "YOLOv10m"
check_model "${MODELS_DIR}/onnx/yolox_l.onnx" "YOLOX-L"
check_model "${MODELS_DIR}/onnx/dw-ll_ucoco_384_bs5.torchscript.pt" "DW-LL UCoCo"

if [ ${MISSING} -gt 0 ]; then
    echo ""
    echo "⚠ ${MISSING} model(s) missing! Run download_models.sh on the Network Volume first."
    echo "  The handler will still start, but jobs will fail if models are missing."
fi
