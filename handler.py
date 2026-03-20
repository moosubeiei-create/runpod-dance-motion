"""
RunPod Handler — AI Dance Motion (Face Lock)
Workflow: Ver_2-AI_Dance_Motion-face_lock_V_2_fixed

Node map (จาก workflow JSON):
  Node 63  : VHS_LoadVideo            ← dance video input
  Node 57  : LoadImage                ← reference face image
  Node 150 : INTConstant (Width)      ← 608 (override ได้)
  Node 151 : INTConstant (Height)     ← 1088 (override ได้)
  Node 186 : CLIPTextEncode (positive prompt)
  Node 187 : CLIPTextEncode (negative prompt)
  Node 27  : WanVideoSampler          ← steps, cfg, seed
  Node 174 : VHS_VideoCombine         ← output MP4 (save_output=false, type=temp)
  Node 190 : VHS_VideoCombine         ← output MP4 main (save_output=true)
"""

import runpod
import subprocess
import requests
import base64
import json
import time
import os
import uuid
import logging
import glob

logging.basicConfig(level=logging.INFO, format="[%(asctime)s] %(levelname)s %(message)s")
log = logging.getLogger(__name__)

# ─── Config ───────────────────────────────────────────────────────────────────
COMFY_HOST     = "127.0.0.1"
COMFY_PORT     = 8188
COMFY_URL      = f"http://{COMFY_HOST}:{COMFY_PORT}"
COMFY_DIR      = os.environ.get("COMFY_DIR", "/workspace/ComfyUI")
NETWORK_VOLUME = os.environ.get("NETWORK_VOLUME", "/runpod-volume")
INPUT_DIR      = f"{COMFY_DIR}/input"
OUTPUT_DIR     = f"{COMFY_DIR}/output"
WORKFLOW_PATH  = f"{COMFY_DIR}/workflows/dance_workflow.json"

# ─── File helpers ─────────────────────────────────────────────────────────────
def save_base64(b64_string: str, filename: str) -> str:
    """Decode base64 and save to ComfyUI input folder. Returns the filename."""
    os.makedirs(INPUT_DIR, exist_ok=True)
    path = os.path.join(INPUT_DIR, filename)
    with open(path, "wb") as f:
        f.write(base64.b64decode(b64_string))
    size_mb = os.path.getsize(path) / 1_048_576
    log.info(f"Saved {filename} ({size_mb:.1f} MB) → {path}")
    return filename


def save_from_url(url: str, filename: str) -> str:
    """Download file from URL and save to ComfyUI input folder."""
    os.makedirs(INPUT_DIR, exist_ok=True)
    path = os.path.join(INPUT_DIR, filename)
    log.info(f"Downloading {url} → {path}")
    resp = requests.get(url, timeout=300, stream=True)
    resp.raise_for_status()
    with open(path, "wb") as f:
        for chunk in resp.iter_content(chunk_size=8192):
            f.write(chunk)
    size_mb = os.path.getsize(path) / 1_048_576
    log.info(f"Downloaded {filename} ({size_mb:.1f} MB)")
    return filename


def read_as_base64(path: str) -> str:
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode()


# ─── Workflow builder ─────────────────────────────────────────────────────────
def build_api_workflow(
    face_filename: str,
    video_filename: str,
    positive_prompt: str = "the woman is dancing to camera",
    negative_prompt: str = "色调艳丽，过曝，静态，细节模糊不清，字幕，风格，作品，画作，画面，静止，整体发灰，最差质量，低质量，JPEG压缩残留，丑陋的，残缺的，多余的手指，画得不好的手部，画得不好的脸部，畸形的，毁容的，形态畸形的肢体，手指融合，静止不动的画面，杂乱的背景，三条腿，背景人很多，倒着走",
    width: int = 608,
    height: int = 1088,
    steps: int = 4,
    cfg: float = 1.0,
    seed: int = -1,
    frame_rate: int = 30,
    frame_load_cap: int = 0,
) -> dict:
    """
    Load the pre-built API-format workflow JSON and override dynamic inputs.
    """
    if seed == -1:
        seed = int(time.time() * 1000) % 2**32

    with open(WORKFLOW_PATH) as f:
        wf = json.load(f)

    # --- Node 63 : VHS_LoadVideo (dance video) -------------------------------
    wf["63"]["inputs"]["video"]            = video_filename
    wf["63"]["inputs"]["force_rate"]       = frame_rate
    wf["63"]["inputs"]["custom_width"]     = width
    wf["63"]["inputs"]["custom_height"]    = height
    wf["63"]["inputs"]["frame_load_cap"]   = frame_load_cap

    # --- Node 57 : LoadImage (reference face) --------------------------------
    wf["57"]["inputs"]["image"] = face_filename

    # --- Node 150 / 151 : Width / Height -------------------------------------
    wf["150"]["inputs"]["value"] = width
    wf["151"]["inputs"]["value"] = height

    # --- Node 186 : CLIPTextEncode (positive prompt) -------------------------
    wf["186"]["inputs"]["text"] = positive_prompt

    # --- Node 187 : CLIPTextEncode (negative prompt) -------------------------
    wf["187"]["inputs"]["text"] = negative_prompt

    # --- Node 27 : WanVideoSampler (steps / cfg / seed) ----------------------
    wf["27"]["inputs"]["steps"] = steps
    wf["27"]["inputs"]["cfg"]   = cfg
    wf["27"]["inputs"]["seed"]  = seed

    # --- Node 190 : VHS_VideoCombine (main output) ---------------------------
    wf["190"]["inputs"]["frame_rate"]      = frame_rate
    wf["190"]["inputs"]["filename_prefix"] = f"dance_out_{uuid.uuid4().hex[:8]}"

    # --- Node 174 : VHS_VideoCombine (vitpose preview) -----------------------
    wf["174"]["inputs"]["frame_rate"]      = frame_rate
    wf["174"]["inputs"]["filename_prefix"] = f"dance_temp_{uuid.uuid4().hex[:8]}"

    # --- Node 181 : VHS_VideoCombine (pose preview) --------------------------
    wf["181"]["inputs"]["frame_rate"]      = frame_rate
    wf["181"]["inputs"]["filename_prefix"] = f"pose_prev_{uuid.uuid4().hex[:8]}"

    # --- Node 75 : VHS_VideoCombine (background preview) ---------------------
    wf["75"]["inputs"]["frame_rate"]       = frame_rate
    wf["75"]["inputs"]["filename_prefix"]  = f"bg_prev_{uuid.uuid4().hex[:8]}"

    return wf


# ─── ComfyUI job execution ────────────────────────────────────────────────────
def queue_prompt(workflow: dict) -> str:
    """Queue a prompt and return the prompt_id."""
    client_id = str(uuid.uuid4())
    payload = {"prompt": workflow, "client_id": client_id}
    r = requests.post(f"{COMFY_URL}/prompt", json=payload, timeout=30)
    r.raise_for_status()
    data = r.json()
    if "error" in data:
        raise RuntimeError(f"ComfyUI prompt error: {data['error']}")
    prompt_id = data["prompt_id"]
    log.info(f"Queued prompt: {prompt_id}")
    return prompt_id


def wait_for_completion(prompt_id: str, timeout: int = 900) -> dict:
    """
    Poll /history/{prompt_id} until completed.
    Returns the outputs dict from history.
    """
    start = time.time()
    last_status = None
    while time.time() - start < timeout:
        try:
            r = requests.get(f"{COMFY_URL}/history/{prompt_id}", timeout=10)
            history = r.json()
        except Exception as e:
            log.warning(f"History poll error: {e}")
            time.sleep(5)
            continue

        if prompt_id in history:
            entry  = history[prompt_id]
            status = entry.get("status", {})
            status_str = status.get("status_str", "unknown")

            if status_str != last_status:
                log.info(f"Job status: {status_str}")
                last_status = status_str

            if status.get("completed", False):
                if status_str == "error":
                    msgs = status.get("messages", [])
                    raise RuntimeError(f"ComfyUI error: {msgs}")
                return entry.get("outputs", {})

        time.sleep(4)

    raise TimeoutError(f"Job {prompt_id} did not complete within {timeout}s")


def find_output_video(outputs: dict) -> str | None:
    """
    หา output video file path จาก outputs dict.
    ลองหาจาก Node 190 ก่อน (main output), แล้ว fallback ไปหา node อื่น.
    """
    priority_nodes = ["190", "174", "181"]

    for nid in priority_nodes:
        node_out = outputs.get(nid, {})
        for key in ("gifs", "videos"):
            files = node_out.get(key, [])
            if files:
                info = files[0]
                folder = info.get("subfolder", "")
                fname  = info["filename"]
                ftype  = info.get("type", "output")
                base   = OUTPUT_DIR if ftype == "output" else f"{COMFY_DIR}/temp"
                path   = os.path.join(base, folder, fname) if folder else os.path.join(base, fname)
                if os.path.exists(path):
                    log.info(f"Found output video (node {nid}): {path}")
                    return path
                log.warning(f"File listed in history but not found on disk: {path}")

    # fallback: scan any node
    for nid, node_out in outputs.items():
        for key in ("gifs", "videos"):
            for info in node_out.get(key, []):
                ftype = info.get("type", "output")
                base  = OUTPUT_DIR if ftype == "output" else f"{COMFY_DIR}/temp"
                folder = info.get("subfolder", "")
                fname  = info["filename"]
                path   = os.path.join(base, folder, fname) if folder else os.path.join(base, fname)
                if os.path.exists(path):
                    log.info(f"Found fallback video (node {nid}): {path}")
                    return path

    # last resort: scan output dir for latest mp4
    mp4_files = glob.glob(f"{OUTPUT_DIR}/**/*.mp4", recursive=True)
    if mp4_files:
        latest = max(mp4_files, key=os.path.getmtime)
        log.info(f"Found latest mp4 in output dir: {latest}")
        return latest

    return None


# ─── RunPod Handler ───────────────────────────────────────────────────────────
def handler(job: dict) -> dict:
    """
    RunPod calls this for every job.

    Expected input (job["input"]):
      face_image_base64   : str  — base64-encoded face image (JPEG/PNG)
      dance_video_base64  : str  — base64-encoded dance video (MP4)

    Alternative URL-based input:
      face_image_url      : str  — URL to download face image
      dance_video_url     : str  — URL to download dance video

    Optional overrides:
      positive_prompt     : str  — default "the woman is dancing to camera"
      negative_prompt     : str  — Chinese negative prompt (default)
      width               : int  — default 608
      height              : int  — default 1088
      steps               : int  — default 4
      cfg                 : float — default 1.0
      seed                : int  — default -1 (random)
      frame_rate          : int  — default 30
      frame_load_cap      : int  — default 0 (all frames)
    """
    job_id  = job.get("id", "unknown")
    inputs  = job.get("input", {})
    log.info(f"=== Job {job_id} started ===")
    log.info(f"Input keys: {list(inputs.keys())}")

    # ── Validate required inputs ──────────────────────────────────────────────
    has_face  = "face_image_base64" in inputs or "face_image_url" in inputs
    has_dance = "dance_video_base64" in inputs or "dance_video_url" in inputs

    if not has_face:
        return {"error": "Missing required field: face_image_base64 or face_image_url"}
    if not has_dance:
        return {"error": "Missing required field: dance_video_base64 or dance_video_url"}

    # ── Save uploaded files ───────────────────────────────────────────────────
    safe_id = job_id.replace("-", "")[:16]
    face_filename  = f"face_{safe_id}.jpg"
    video_filename = f"video_{safe_id}.mp4"

    try:
        # Face image: prefer base64, fallback to URL
        if "face_image_base64" in inputs:
            save_base64(inputs["face_image_base64"], face_filename)
        else:
            save_from_url(inputs["face_image_url"], face_filename)

        # Dance video: prefer base64, fallback to URL
        if "dance_video_base64" in inputs:
            save_base64(inputs["dance_video_base64"], video_filename)
        else:
            save_from_url(inputs["dance_video_url"], video_filename)
    except Exception as e:
        log.error(f"File save failed: {e}")
        return {"error": f"Failed to save input files: {str(e)}"}

    # ── Build workflow ────────────────────────────────────────────────────────
    try:
        workflow = build_api_workflow(
            face_filename    = face_filename,
            video_filename   = video_filename,
            positive_prompt  = inputs.get("positive_prompt",
                                          "the woman is dancing to camera"),
            negative_prompt  = inputs.get("negative_prompt",
                                          "色调艳丽，过曝，静态，细节模糊不清，字幕，风格，作品，画作，画面，静止，整体发灰，最差质量，低质量，JPEG压缩残留，丑陋的，残缺的，多余的手指，画得不好的手部，画得不好的脸部，畸形的，毁容的，形态畸形的肢体，手指融合，静止不动的画面，杂乱的背景，三条腿，背景人很多，倒着走"),
            width            = int(inputs.get("width",          608)),
            height           = int(inputs.get("height",        1088)),
            steps            = int(inputs.get("steps",            4)),
            cfg              = float(inputs.get("cfg",           1.0)),
            seed             = int(inputs.get("seed",             -1)),
            frame_rate       = int(inputs.get("frame_rate",      30)),
            frame_load_cap   = int(inputs.get("frame_load_cap",   0)),
        )
        log.info(f"Workflow built: {len(workflow)} nodes")
    except Exception as e:
        log.error(f"Workflow build failed: {e}")
        return {"error": f"Failed to build workflow: {str(e)}"}
    # ── Strip _meta from all nodes (ComfyUI API rejects unknown keys) ─────
    for nid in list(workflow.keys()):
        workflow[nid].pop("_meta", None)

    # ── Queue and run ─────────────────────────────────────────────────────────
    try:
        prompt_id = queue_prompt(workflow)
    except Exception as e:
        log.error(f"Queue failed: {e}")
        return {"error": f"Failed to queue prompt: {str(e)}"}

    # ── Wait for result ───────────────────────────────────────────────────────
    try:
        outputs = wait_for_completion(prompt_id, timeout=900)
    except TimeoutError as e:
        log.error(str(e))
        return {"error": str(e)}
    except RuntimeError as e:
        log.error(str(e))
        return {"error": str(e)}

    # ── Find and encode output video ──────────────────────────────────────────
    video_path = find_output_video(outputs)
    if not video_path:
        log.error("No output video found in ComfyUI history")
        log.error(f"Outputs: {json.dumps(outputs, indent=2)}")
        return {"error": "No output video found", "raw_outputs": outputs}

    try:
        video_b64 = read_as_base64(video_path)
        file_size_mb = os.path.getsize(video_path) / 1_048_576
        log.info(f"Output video: {video_path} ({file_size_mb:.1f} MB)")
    except Exception as e:
        return {"error": f"Failed to read output video: {str(e)}"}

    # ── Cleanup input files (ประหยัด disk) ───────────────────────────────────
    for fname in (face_filename, video_filename):
        try:
            os.remove(os.path.join(INPUT_DIR, fname))
        except Exception:
            pass

    log.info(f"=== Job {job_id} complete ===")
    return {
        "video_base64": video_b64,
        "filename":     os.path.basename(video_path),
        "size_mb":      round(file_size_mb, 2),
        "prompt_id":    prompt_id,
    }


# ─── Entrypoint ───────────────────────────────────────────────────────────────
if __name__ == "__main__":
    # ComfyUI is started by start.sh before this script runs
    # Just verify it's accessible
    log.info("Verifying ComfyUI connection...")
    for i in range(30):
        try:
            r = requests.get(f"{COMFY_URL}/system_stats", timeout=3)
            if r.status_code == 200:
                log.info("ComfyUI is accessible.")
                break
        except Exception:
            pass
        time.sleep(2)
    else:
        log.warning("Could not verify ComfyUI connection, starting handler anyway...")

    log.info("Starting RunPod serverless handler...")
    runpod.serverless.start({"handler": handler})
