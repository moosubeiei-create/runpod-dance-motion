#!/bin/bash
# ─── Install Custom Nodes required by Dance Motion workflow ──────────────────
set -e

CUSTOM_DIR="${COMFY_DIR}/custom_nodes"
cd "${CUSTOM_DIR}"

echo "=== Installing Custom Nodes ==="

# 1. ComfyUI-VideoHelperSuite (VHS_LoadVideo, VHS_VideoCombine)
echo "→ ComfyUI-VideoHelperSuite"
git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git
pip install -r ComfyUI-VideoHelperSuite/requirements.txt

# 2. ComfyUI-KJNodes (fp8 scaled model loader, INTConstant, etc.)
echo "→ ComfyUI-KJNodes"
git clone https://github.com/kijai/ComfyUI-KJNodes.git
pip install -r ComfyUI-KJNodes/requirements.txt 2>/dev/null || true

# 3. ComfyUI-WanVideoWrapper (WanVideoSampler, WanVideoModelLoader)
echo "→ ComfyUI-WanVideoWrapper"
git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git
pip install -r ComfyUI-WanVideoWrapper/requirements.txt 2>/dev/null || true

# 4. comfyui-wananimatepreprocess (PoseAndFaceDetection, OnnxDetectionModelLoader)
echo "→ comfyui-wananimatepreprocess"
git clone https://github.com/facok/comfyui-wananimatepreprocess.git
pip install -r comfyui-wananimatepreprocess/requirements.txt 2>/dev/null || true

# 5. comfyui_controlnet_aux (DWPreprocessor)
echo "→ comfyui_controlnet_aux"
git clone https://github.com/Fannovel16/comfyui_controlnet_aux.git
pip install -r comfyui_controlnet_aux/requirements.txt 2>/dev/null || true

# 6. ComfyUI-SAM2 (SAM2 segmentation for face lock)
echo "→ ComfyUI-SAM2"
git clone https://github.com/neverbiasu/ComfyUI-SAM2.git
pip install -r ComfyUI-SAM2/requirements.txt 2>/dev/null || true

# 7. ComfyUI-LoRA-Stack (if workflow uses LoRA stacking nodes)
echo "→ ComfyUI-Florence2 (optional, for face detection fallback)"
git clone https://github.com/kijai/ComfyUI-Florence2.git 2>/dev/null || true
pip install -r ComfyUI-Florence2/requirements.txt 2>/dev/null || true

# Install ONNX Runtime for pose detection
pip install onnxruntime-gpu

echo "=== Custom Nodes installation complete ==="
