# AI Dance Motion Generator — RunPod Serverless Repo

สร้างวิดีโอเต้นด้วย AI โดยใช้ใบหน้าจากรูปภาพ + ท่าเต้นจากวิดีโอต้นแบบ  
ระบบใช้ ComfyUI + WanVideo 2.2 + SAM2 + VitPose บน RunPod Serverless

---

## Architecture

```
┌─────────────────┐     ┌──────────────────────────────┐
│  HTML UI         │────▶│  RunPod Serverless Endpoint   │
│  (browser)       │◀────│  ┌──────────────────────────┐ │
│                  │     │  │ handler.py               │ │
│  - face image    │     │  │  ↓                       │ │
│  - dance video   │     │  │ ComfyUI (localhost:8188) │ │
│  - settings      │     │  │  ↓                       │ │
└─────────────────┘     │  │ WanVideo workflow         │ │
                         │  │  ↓                       │ │
                         │  │ output video (base64)    │ │
                         │  └──────────────────────────┘ │
                         │                                │
                         │  Network Volume (models)       │
                         └──────────────────────────────┘
```

## Project Structure

```
runpod-dance-motion/
├── Dockerfile                  # Docker image for Serverless worker
├── handler.py                  # RunPod serverless handler
├── dance_workflow.json         # ComfyUI workflow (you provide this)
├── dance-motion-ui.html        # Frontend UI (open in browser)
├── README.md
└── scripts/
    ├── install_custom_nodes.sh # Install ComfyUI custom nodes
    ├── link_models.sh          # Symlink models from Network Volume
    ├── download_models.sh      # Download all models to Network Volume
    └── start.sh                # Container startup script
```

---

## Setup Guide

### Phase 1: Prepare Network Volume

1. สร้าง **Network Volume** บน RunPod (แนะนำ 100GB+)
2. สร้าง **Pod** ชั่วคราว (เช่น RTX 4090) เพื่อ mount Network Volume
3. รันสคริปต์ดาวน์โหลด models:

```bash
bash /workspace/download_models.sh /runpod-volume
```

#### Models ที่ต้องมี:

| Model | Path | Size |
|-------|------|------|
| Wan2.2 Animate 14B (fp8) | `checkpoints/Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors` | ~14GB |
| LoRA: Fun-A14B-InP | `loras/Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors` | ~400MB |
| LoRA: LightX2V 4-steps | `loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors` | ~400MB |
| UMT5-XXL fp8 (text encoder) | `clip/umt5_xxl_fp8_e4m3fn_scaled.safetensors` | ~5GB |
| Wan 2.1 VAE | `vae/wan_2.1_vae.safetensors` | ~300MB |
| CLIP Vision H | `clip_vision/clip_vision_h.safetensors` | ~3.5GB |
| SAM2.1 Hiera Base+ | `sam2/sam2.1_hiera_base_plus.safetensors` | ~300MB |
| VitPose-L Wholebody | `onnx/vitpose-l-wholebody.onnx` | ~400MB |
| YOLOv10m | `onnx/yolov10m.onnx` | ~50MB |
| YOLOX-L | `onnx/yolox_l.onnx` | ~200MB |
| DW-LL UCoCo | `onnx/dw-ll_ucoco_384_bs5.torchscript.pt` | ~150MB |

### Phase 2: Build & Push Docker Image

1. วาง `dance_workflow.json` (export จาก ComfyUI) ไว้ใน project root

2. Build Docker image:
```bash
docker build -t yourusername/dance-motion-serverless:latest .
```

3. Push ไป Docker Hub:
```bash
docker push yourusername/dance-motion-serverless:latest
```

### Phase 3: Create Serverless Endpoint

1. ไปที่ **RunPod Dashboard → Serverless → + New Endpoint**
2. ตั้งค่า:
   - **Docker Image:** `yourusername/dance-motion-serverless:latest`
   - **GPU:** RTX 4090 หรือ A100 (แนะนำ 48GB+ VRAM)
   - **Network Volume:** เลือก volume ที่ดาวน์โหลด models ไว้
   - **Idle Timeout:** 30s (ประหยัดค่าใช้จ่าย)
   - **Execution Timeout:** 900s (15 นาที)
   - **Max Workers:** ตามงบประมาณ

3. **Alternative: Publish เป็น Serverless Repo**
   - ไปที่ RunPod Hub → Add your repo
   - ใส่ Docker image URL
   - กรอกรายละเอียด (ชื่อ, คำอธิบาย, GPU requirements)

### Phase 4: ใช้งาน UI

1. เปิด `dance-motion-ui.html` ใน browser
2. กรอก **API Key** (จาก RunPod Settings → API Keys)
3. กรอก **Endpoint ID** (จาก Serverless → Endpoints → ID)
4. อัปโหลดรูปหน้า + วิดีโอเต้น
5. กด **Generate**

---

## API Input Format

```json
{
  "input": {
    "face_image_base64": "<base64-encoded JPEG/PNG>",
    "dance_video_base64": "<base64-encoded MP4>",

    "positive_prompt": "the woman is dancing to camera",
    "width": 608,
    "height": 1088,
    "steps": 4,
    "cfg": 1.0,
    "seed": -1,
    "frame_rate": 30,
    "frame_load_cap": 0
  }
}
```

### Alternative: URL-based input (ลดขนาด payload)

```json
{
  "input": {
    "face_image_url": "https://example.com/face.jpg",
    "dance_video_url": "https://example.com/dance.mp4",
    "steps": 4,
    "cfg": 1.0
  }
}
```

## API Output Format

```json
{
  "video_base64": "<base64-encoded MP4>",
  "filename": "dance_out_abc12345.mp4",
  "size_mb": 12.5,
  "prompt_id": "comfyui-prompt-id"
}
```

---

## Node Map (Workflow)

| Node | Type | Override |
|------|------|---------|
| 63 | VHS_LoadVideo | video filename + width/height/fps |
| 57 | LoadImage | face image filename |
| 150 | INTConstant (Width) | width value |
| 151 | INTConstant (Height) | height value |
| 186 | CLIPTextEncode | positive prompt |
| 187 | CLIPTextEncode | negative prompt |
| 27 | WanVideoSampler | steps, cfg, seed |
| 190 | VHS_VideoCombine | main output (save_output=True) |
| 174 | VHS_VideoCombine | temp output |
| 181 | VHS_VideoCombine | pose preview |

All other nodes (SAM2, VitPose, WanVideoModelLoader, LoRA, etc.) load values from the workflow JSON automatically.

---

## Custom Nodes Required

| Package | Purpose |
|---------|---------|
| ComfyUI-VideoHelperSuite | VHS_LoadVideo, VHS_VideoCombine |
| ComfyUI-KJNodes | fp8 model loader, INTConstant |
| ComfyUI-WanVideoWrapper | WanVideoSampler, WanVideoModelLoader |
| comfyui-wananimatepreprocess | PoseAndFaceDetection, OnnxDetectionModelLoader |
| comfyui_controlnet_aux | DWPreprocessor |
| ComfyUI-SAM2 | SAM2 segmentation for face lock |

---

## Troubleshooting

- **Job stuck in IN_QUEUE**: Worker กำลัง cold start (ครั้งแรกอาจใช้เวลา 2-3 นาที)
- **FAILED: No output video**: ตรวจสอบว่า models ครบถ้วนบน Network Volume
- **Memory error**: ลดขนาด width/height หรือใช้ GPU ที่มี VRAM มากขึ้น
- **ComfyUI did not start**: ดู log ที่ `/tmp/comfy.log` ในตัว worker
