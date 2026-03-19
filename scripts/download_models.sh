#!/bin/bash
# ─── Download all models to Network Volume ────────────────────────────────────
# Run this script ONCE on a RunPod pod with the Network Volume mounted
# Usage: bash download_models.sh [/path/to/network/volume]
# Default: /runpod-volume
# ──────────────────────────────────────────────────────────────────────────────
set -e

NV="${1:-/runpod-volume}"
MODELS="${NV}/models"

echo "=== Downloading models to: ${MODELS} ==="
echo "This may take a while depending on your connection speed."
echo ""

mkdir -p "${MODELS}/checkpoints"
mkdir -p "${MODELS}/loras"
mkdir -p "${MODELS}/clip"
mkdir -p "${MODELS}/vae"
mkdir -p "${MODELS}/clip_vision"
mkdir -p "${MODELS}/sam2"
mkdir -p "${MODELS}/onnx"

# ── Helper function ──────────────────────────────────────────────────────────
download() {
    local url="$1"
    local dest="$2"
    local name=$(basename "${dest}")
    
    if [ -f "${dest}" ]; then
        echo "  ✓ ${name} already exists, skipping"
        return 0
    fi
    
    echo "  ↓ Downloading ${name}..."
    wget -q --show-progress -O "${dest}" "${url}"
    echo "  ✓ ${name} done"
}

# ─── 1. Main Model: Wan2.2 Animate 14B (fp8) ─────────────────────────────────
echo ""
echo "[1/10] Wan2.2 Animate 14B fp8 (main checkpoint)"
download \
    "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/Wan22Animate/Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors" \
    "${MODELS}/checkpoints/Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors"

# ─── 2. LoRA: Fun-A14B-InP ───────────────────────────────────────────────────
echo ""
echo "[2/10] LoRA: Wan2.2-Fun-A14B-InP-low-noise-HPS2.1"
download \
    "https://huggingface.co/alibaba-pai/Wan2.2-Fun-Reward-LoRAs/resolve/main/Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors" \
    "${MODELS}/loras/Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors"

# ─── 3. LoRA: LightX2V 4-steps ───────────────────────────────────────────────
echo ""
echo "[3/10] LoRA: LightX2V 4-steps"
download \
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors" \
    "${MODELS}/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors"

# ─── 4. Text Encoder: UMT5-XXL fp8 ───────────────────────────────────────────
echo ""
echo "[4/10] UMT5-XXL fp8 (text encoder / CLIP)"
download \
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5-xxl-enc-fp8_e4m3fn.safetensors" \
    "${MODELS}/clip/umt5_xxl_fp8_e4m3fn_scaled.safetensors"

# ─── 5. VAE: Wan 2.1 ─────────────────────────────────────────────────────────
echo ""
echo "[5/10] Wan 2.1 VAE"
download \
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors" \
    "${MODELS}/vae/wan_2.1_vae.safetensors"

# ─── 6. CLIP Vision H ────────────────────────────────────────────────────────
echo ""
echo "[6/10] CLIP Vision H"
download \
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors" \
    "${MODELS}/clip_vision/clip_vision_h.safetensors"

# ─── 7. SAM2.1 Hiera Base+ ───────────────────────────────────────────────────
echo ""
echo "[7/10] SAM2.1 Hiera Base+"
download \
    "https://huggingface.co/facebook/sam2.1-hiera-base-plus/resolve/main/sam2.1_hiera_base_plus.safetensors" \
    "${MODELS}/sam2/sam2.1_hiera_base_plus.safetensors"

# ─── 8. VitPose-L Wholebody ──────────────────────────────────────────────────
echo ""
echo "[8/10] VitPose-L Wholebody (ONNX)"
download \
    "https://huggingface.co/facok/wanimate_preprocess_models/resolve/main/vitpose-l-wholebody.onnx" \
    "${MODELS}/onnx/vitpose-l-wholebody.onnx"

# ─── 9. YOLOv10m + YOLOX-L ───────────────────────────────────────────────────
echo ""
echo "[9/10] YOLOv10m (ONNX)"
download \
    "https://huggingface.co/facok/wanimate_preprocess_models/resolve/main/yolov10m.onnx" \
    "${MODELS}/onnx/yolov10m.onnx"

echo ""
echo "[9b/10] YOLOX-L (ONNX)"
download \
    "https://huggingface.co/yzd-v/DWPose/resolve/main/yolox_l.onnx" \
    "${MODELS}/onnx/yolox_l.onnx"

# ─── 10. DW-LL UCoCo ─────────────────────────────────────────────────────────
echo ""
echo "[10/10] DW-LL UCoCo (TorchScript)"
download \
    "https://huggingface.co/yzd-v/DWPose/resolve/main/dw-ll_ucoco_384_bs5.torchscript.pt" \
    "${MODELS}/onnx/dw-ll_ucoco_384_bs5.torchscript.pt"

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo "========================================="
echo "=== Download complete!               ==="
echo "========================================="
echo ""
echo "Model sizes:"
du -sh "${MODELS}"/*/ 2>/dev/null || true
echo ""
echo "Total:"
du -sh "${MODELS}"
echo ""
echo "Next steps:"
echo "  1. Build the Docker image: docker build -t dance-motion-serverless ."
echo "  2. Push to Docker Hub: docker push yourusername/dance-motion-serverless"
echo "  3. Create a Serverless Endpoint on RunPod with this image"
echo "  4. Attach the Network Volume containing these models"
