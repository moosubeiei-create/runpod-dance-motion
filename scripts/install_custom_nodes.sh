#!/bin/bash
# ─── Install Custom Nodes required by Dance Motion workflow ──────────────────

CUSTOM_DIR="${COMFY_DIR}/custom_nodes"
cd "${CUSTOM_DIR}"

echo "=== Installing Custom Nodes ==="

clone_and_install() {
    local name=$1
    local url=$2
    echo "→ ${name} from ${url}"
    if [ -d "${name}" ]; then
        echo "  Removing old install for fresh clone..."
        rm -rf "${name}"
    fi
    git clone --depth 1 "${url}" "${name}" || { echo "  FAILED to clone ${name}"; return 1; }
    if [ -f "${name}/requirements.txt" ]; then
        echo "  Installing requirements..."
        pip install -r "${name}/requirements.txt" || true
    fi
    if [ -f "${name}/install.py" ]; then
        echo "  Running install.py..."
        (cd "${name}" && python install.py) || true
    fi
    echo "  ✓ ${name} installed"
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

# ─── Install critical dependencies explicitly ─────────────────────────────────
echo ""
echo "=== Installing critical Python dependencies ==="

pip install onnxruntime-gpu || pip install onnxruntime || true
pip install opencv-python || true
pip install sageattention || true
pip install diffusers accelerate || true
pip install segment-anything-2 || true
pip install einops || true
pip install kornia || true

echo ""
echo "=== Verifying custom node directories ==="
for d in ComfyUI-VideoHelperSuite ComfyUI-KJNodes ComfyUI-WanVideoWrapper \
         ComfyUI-WanAnimatePreprocess comfyui_controlnet_aux \
         ComfyUI-segment-anything-2 ComfyUI-Florence2; do
    if [ -d "${CUSTOM_DIR}/${d}" ]; then
        echo "  ✓ ${d}"
    else
        echo "  ✗ MISSING: ${d}"
    fi
done

echo "=== Custom Nodes installation complete ==="
