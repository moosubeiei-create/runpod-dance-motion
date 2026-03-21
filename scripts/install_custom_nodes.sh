#!/bin/bash
# ─── Install Custom Nodes required by Dance Motion workflow ──────────────────

CUSTOM_DIR="${COMFY_DIR}/custom_nodes"
cd "${CUSTOM_DIR}"

echo "=== Installing Custom Nodes ==="

clone_and_install() {
    local name=$1
    local url=$2
    echo "→ ${name}"
    if [ -d "${name}" ]; then
        echo "  Already exists, skipping..."
        return 0
    fi
    git clone --depth 1 "${url}" "${name}" || { echo "  WARNING: Failed to clone ${name}"; return 0; }
    if [ -f "${name}/requirements.txt" ]; then
        pip install -r "${name}/requirements.txt" 2>/dev/null || true
    fi
}

# 1. ComfyUI-VideoHelperSuite (VHS_LoadVideo, VHS_VideoCombine)
clone_and_install "ComfyUI-VideoHelperSuite" "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git"

# 2. ComfyUI-KJNodes (fp8 scaled model loader, INTConstant, etc.)
clone_and_install "ComfyUI-KJNodes" "https://github.com/kijai/ComfyUI-KJNodes.git"

# 3. ComfyUI-WanVideoWrapper (WanVideoSampler, WanVideoModelLoader)
clone_and_install "ComfyUI-WanVideoWrapper" "https://github.com/kijai/ComfyUI-WanVideoWrapper.git"

# 4. ComfyUI-WanAnimatePreprocess (PoseAndFaceDetection, OnnxDetectionModelLoader)
clone_and_install "ComfyUI-WanAnimatePreprocess" "https://github.com/kijai/ComfyUI-WanAnimatePreprocess.git"

# 5. comfyui_controlnet_aux (DWPreprocessor)
clone_and_install "comfyui_controlnet_aux" "https://github.com/Fannovel16/comfyui_controlnet_aux.git"

# 6. ComfyUI-segment-anything-2 (DownloadAndLoadSAM2Model, Sam2Segmentation)
clone_and_install "ComfyUI-segment-anything-2" "https://github.com/kijai/ComfyUI-segment-anything-2.git"

# 7. ComfyUI-Florence2 (optional, for face detection fallback)
clone_and_install "ComfyUI-Florence2" "https://github.com/kijai/ComfyUI-Florence2.git"

# Install ONNX Runtime and other dependencies
pip install onnxruntime-gpu || true
pip install opencv-python || true

echo "=== Custom Nodes installation complete ==="
