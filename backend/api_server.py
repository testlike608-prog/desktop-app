"""
api_server.py
-------------
FastAPI backend للـ Flutter frontend.
بيشغّل نفس منطق المشروع الأصلي بس بدل الـ PySide6 GUI
بيعرض REST API + WebSocket عشان Flutter يتصل بيه.

التشغيل:
    cd C:\\...\\code
    python ..\flutter\Water_Drop_detec_app\backend\api_server.py

أو من نفس فولدر api_server.py (لازم code_path يكون صح):
    python api_server.py
"""

import sys
import os
import time
import asyncio
import threading
import logging
import json
from typing import List, Optional, Any
from contextlib import asynccontextmanager

# ─── نضيف مسار الكود الأصلي لـ sys.path ────────────────────────────────────
if getattr(sys, 'frozen', False):
    # ── وضع PyInstaller (api_server.exe) ──────────────────────────────────
    # sys._MEIPASS = فولدر مؤقت فيه كل الـ modules المضغوطة
    # sys.executable = المسار الكامل لـ api_server.exe
    _BUNDLE_DIR = getattr(sys, '_MEIPASS', os.path.dirname(sys.executable))
    _EXE_DIR    = os.path.dirname(sys.executable)

    if _BUNDLE_DIR not in sys.path:
        sys.path.insert(0, _BUNDLE_DIR)

    # الـ data files (config.json, mapping, etc.) بيتحطوا جنب الـ exe
    _CODE_DIR = _EXE_DIR

    # نعيد توجيه stdout/stderr عشان --noconsole ميكسرش uvicorn
    import io
    sys.stdout = io.TextIOWrapper(open(os.path.join(_EXE_DIR, 'backend_stdout.log'), 'wb'), encoding='utf-8')
    sys.stderr = io.TextIOWrapper(open(os.path.join(_EXE_DIR, 'backend_stderr.log'), 'wb'), encoding='utf-8')

else:
    # ── وضع Development ───────────────────────────────────────────────────
    _THIS_DIR = os.path.dirname(os.path.abspath(__file__))
    _CODE_DIR = os.path.abspath(os.path.join(_THIS_DIR, "..", "..", "..", "code"))
    if not os.path.isdir(_CODE_DIR):
        _CODE_DIR = os.getcwd()
    if _CODE_DIR not in sys.path:
        sys.path.insert(0, _CODE_DIR)

os.chdir(_CODE_DIR)  # عشان الـ relative paths في config تشتغل صح

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn

# ─── Logging setup ────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
log = logging.getLogger("api_server")

# ─── Log bridge: نالتقط كل الـ logs ونبعتها للـ WebSocket clients ──────────
class LogCollector(logging.Handler):
    """Handler بيجمع الـ log records عشان نبعتها لـ WebSocket."""
    def __init__(self):
        super().__init__()
        self._entries: list = []
        self._lock = threading.Lock()
        self._max = 2000

    def emit(self, record: logging.LogRecord):
        entry = {
            "ts":      record.created,
            "level":   record.levelname,
            "name":    record.name,
            "message": self.format(record),
        }
        with self._lock:
            self._entries.append(entry)
            if len(self._entries) > self._max:
                self._entries = self._entries[-self._max:]
        # notify websocket connections (non-blocking)
        _log_event.set()

    def get_all(self):
        with self._lock:
            return list(self._entries)

_log_collector = LogCollector()
_log_collector.setFormatter(logging.Formatter("%(asctime)s [%(levelname)s] %(name)s: %(message)s"))
logging.getLogger().addHandler(_log_collector)

# event for notifying ws log clients
_log_event = threading.Event()

# ─── نستورد الـ modules الأصلية ──────────────────────────────────────────────
app_ref: Optional[Any] = None
_app_init_error: Optional[str] = None

try:
    import thread_logger
    _tlog = thread_logger.setup(watchdog_interval=2.0)
    import ClientsClass as cc
    import debug_monitor
    app_ref = cc.App()
    debug_monitor.start(app_ref=app_ref, interval=2.0, force=True, verbose_console=False)
    log.info("App created successfully (STOPPED by default)")
except Exception as e:
    _app_init_error = str(e)
    log.exception(f"Could not create App: {e}")


# ─── WebSocket connection managers ───────────────────────────────────────────
class ConnectionManager:
    def __init__(self):
        self.active: List[WebSocket] = []
        self._lock = asyncio.Lock()

    async def connect(self, ws: WebSocket):
        await ws.accept()
        async with self._lock:
            self.active.append(ws)

    async def disconnect(self, ws: WebSocket):
        async with self._lock:
            if ws in self.active:
                self.active.remove(ws)

    async def broadcast(self, data: dict):
        msg = json.dumps(data)
        dead = []
        async with self._lock:
            clients = list(self.active)
        for ws in clients:
            try:
                await ws.send_text(msg)
            except Exception:
                dead.append(ws)
        for ws in dead:
            await self.disconnect(ws)

state_manager = ConnectionManager()
log_manager   = ConnectionManager()


# ─── FastAPI app ──────────────────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    # نشغّل الـ background tasks لما السيرفر يقوم
    task1 = asyncio.create_task(_state_broadcast_loop())
    task2 = asyncio.create_task(_log_broadcast_loop())
    yield
    task1.cancel()
    task2.cancel()

api = FastAPI(title="Test Station Controller API", lifespan=lifespan)

api.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ─── Background broadcast loops ──────────────────────────────────────────────
async def _state_broadcast_loop():
    """بيبعت الـ state لكل الـ WebSocket clients كل 500ms."""
    while True:
        try:
            if state_manager.active:
                state = _get_state()
                await state_manager.broadcast(state)
        except Exception as e:
            log.debug(f"state broadcast error: {e}")
        await asyncio.sleep(0.5)


async def _log_broadcast_loop():
    """بيبعت الـ log entries الجديدة لكل الـ WebSocket clients."""
    last_count = 0
    while True:
        try:
            entries = _log_collector.get_all()
            if len(entries) > last_count and log_manager.active:
                new_entries = entries[last_count:]
                for entry in new_entries:
                    await log_manager.broadcast(entry)
                last_count = len(entries)
        except Exception as e:
            log.debug(f"log broadcast error: {e}")
        await asyncio.sleep(0.1)


# ─── Helpers ─────────────────────────────────────────────────────────────────
def _get_state() -> dict:
    if app_ref is None:
        return {
            "is_running": False,
            "stage": "IDLE",
            "barcode": None,
            "program": None,
            "step": 0,
            "vision_test_count": 6,
            "last_event_time": 0,
            "uptime": 0,
            "stats": {"total": 0, "pass": 0, "fail": 0, "errors": 0},
            "queue_sizes": {"vision_queue": 0, "scanner_queue": 0},
            "connections": {
                "VisionClient_TRIG": False,
                "VisionClient_ID": False,
                "cobotClient": False,
                "triggerserver": False,
            },
            "error": _app_init_error,
        }
    try:
        snap = app_ref.get_state_snapshot()
        snap["error"] = None
        return snap
    except Exception as e:
        return {"error": str(e), "is_running": False}


# ─── Pydantic models ──────────────────────────────────────────────────────────
class ConfigUpdate(BaseModel):
    updates: dict

class PasswordVerify(BaseModel):
    password: str

class PasswordChange(BaseModel):
    old_password: str
    new_password: str

class OpenFileRequest(BaseModel):
    path: str

class DetectCamerasRequest(BaseModel):
    stop_hub: bool = True


# ─── REST Endpoints ──────────────────────────────────────────────────────────

@api.get("/api/state")
def get_state():
    return _get_state()


@api.post("/api/start")
def start_app():
    if app_ref is None:
        raise HTTPException(503, detail=_app_init_error or "App not initialized")
    if app_ref.is_running:
        return {"ok": True, "message": "already running"}

    # ── نحدّث الـ IPs/Ports من config قبل الـ start ──────────────────────────
    # (بدل إعادة إنشاء App — أأمن لأن مفيش race condition مع stop thread)
    try:
        app_ref.refresh_config()
        log.info("Config refreshed — IPs/Ports updated from config.json")
    except Exception as e:
        log.warning(f"refresh_config failed (non-fatal): {e}")

    # ── نشغّل + نغلّف أي exception عشان FastAPI يرجع JSON مش HTML ──────────
    try:
        ok = app_ref.start()
    except Exception as e:
        log.exception(f"App.start() raised exception: {e}")
        raise HTTPException(500, detail=f"خطأ غير متوقع أثناء التشغيل: {e}")

    if not ok:
        raise HTTPException(500, detail="فشل التشغيل — البورت ممكن يكون محجوزاً أو الـ config فيه خطأ")
    return {"ok": True}


@api.post("/api/stop")
def stop_app():
    if app_ref is None:
        raise HTTPException(503, detail=_app_init_error or "App not initialized")
    if not app_ref.is_running:
        return {"ok": True, "message": "already stopped"}
    app_ref.stop()
    return {"ok": True}


@api.get("/api/config")
def get_config():
    try:
        from config import config
        return config.get_all()
    except Exception as e:
        raise HTTPException(500, detail=str(e))


@api.patch("/api/config")
def update_config(body: ConfigUpdate):
    try:
        from config import config
        changed = config.update_many(body.updates)
        return {"ok": True, "changed": changed}
    except Exception as e:
        raise HTTPException(500, detail=str(e))


@api.post("/api/config/reset")
def reset_config():
    try:
        from config import config
        config.reset_to_defaults(keep_password=True)
        return {"ok": True}
    except Exception as e:
        raise HTTPException(500, detail=str(e))


@api.post("/api/config/verify-password")
def verify_password(body: PasswordVerify):
    try:
        from config import config
        ok = config.verify_password(body.password)
        return {"ok": ok}
    except Exception as e:
        raise HTTPException(500, detail=str(e))


@api.post("/api/config/change-password")
def change_password(body: PasswordChange):
    try:
        from config import config
        if not config.verify_password(body.old_password):
            raise HTTPException(403, detail="Wrong current password")
        if len(body.new_password) < 4:
            raise HTTPException(400, detail="Password must be at least 4 characters")
        ok = config.set_password(body.new_password)
        if not ok:
            raise HTTPException(500, detail="Failed to change password")
        return {"ok": True}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(500, detail=str(e))


@api.get("/api/logs/history")
def get_logs_history():
    return _log_collector.get_all()


@api.post("/api/open-file")
def open_file(body: OpenFileRequest):
    """يفتح ملف بالبرنامج الافتراضي على الجهاز (Windows/Linux/Mac)."""
    import subprocess, sys as _sys
    path = body.path
    if not os.path.exists(path):
        raise HTTPException(404, detail=f"الملف مش موجود: {path}")
    try:
        if _sys.platform == "win32":
            os.startfile(path)          # type: ignore[attr-defined]
        elif _sys.platform == "darwin":
            subprocess.Popen(["open", path])
        else:
            subprocess.Popen(["xdg-open", path])
        return {"ok": True}
    except Exception as e:
        raise HTTPException(500, detail=str(e))


@api.post("/api/open-folder")
def open_folder(body: OpenFileRequest):
    """يفتح فولدر في الـ file manager."""
    import subprocess, sys as _sys
    path = body.path
    os.makedirs(path, exist_ok=True)
    try:
        if _sys.platform == "win32":
            os.startfile(path)          # type: ignore[attr-defined]
        elif _sys.platform == "darwin":
            subprocess.Popen(["open", path])
        else:
            subprocess.Popen(["xdg-open", path])
        return {"ok": True}
    except Exception as e:
        raise HTTPException(500, detail=str(e))


@api.get("/api/paths")
def get_paths():
    """يرجع المسارات المطلقة لملف النتائج وفولدر اللوج."""
    try:
        from config import config as _cfg
        results_file = os.path.abspath(_cfg.get("results_report_file", "results_report.xlsx"))
        logs_dir     = os.path.join(_CODE_DIR, "logs")
        return {"results_file": results_file, "logs_dir": logs_dir}
    except Exception as e:
        raise HTTPException(500, detail=str(e))


@api.post("/api/detect-cameras")
def detect_cameras():
    """يكتشف الكاميرات المتاحة على الجهاز."""
    try:
        import cv2
    except ImportError:
        raise HTTPException(500, detail="OpenCV مش موجود — pip install opencv-python")

    # وقف camera_hub مؤقتاً
    hub_was_running = False
    hub_old_index   = None
    try:
        import camera_hub
        if camera_hub.is_running():
            hub_was_running = True
            hub_old_index   = getattr(camera_hub, "_cam_index", 0)
            camera_hub.stop(timeout=3.0)
            time.sleep(0.5)
    except Exception:
        pass

    found = []
    for i in range(6):
        for _ in range(2):
            cap = cv2.VideoCapture(i, cv2.CAP_DSHOW if os.name == "nt" else 0)
            if not cap.isOpened():
                cap.release()
                cap = cv2.VideoCapture(i)
            if cap.isOpened():
                found.append(i)
                cap.release()
                break
            cap.release()
            time.sleep(0.2)

    # نشغّل camera_hub تاني
    if hub_was_running and hub_old_index is not None:
        try:
            import camera_hub
            camera_hub.start(camera_index=hub_old_index)
        except Exception:
            pass

    return {"ok": True, "cameras": found}


@api.get("/api/camera/frame")
def get_camera_frame():
    """يرجع صورة JPEG من الكاميرا الحالية (base64)."""
    try:
        import camera_hub
        import cv2
        import base64
        frame = camera_hub.get_frame()
        if frame is None:
            return {"ok": False, "frame": None}
        _, buf = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 70])
        b64 = base64.b64encode(buf.tobytes()).decode()
        return {"ok": True, "frame": b64}
    except Exception as e:
        return {"ok": False, "error": str(e), "frame": None}


# ─── WebSocket Endpoints ──────────────────────────────────────────────────────

@api.websocket("/ws/state")
async def ws_state(websocket: WebSocket):
    await state_manager.connect(websocket)
    try:
        while True:
            # نستنى أي رسالة (keep-alive ping)
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        await state_manager.disconnect(websocket)


@api.websocket("/ws/logs")
async def ws_logs(websocket: WebSocket):
    await log_manager.connect(websocket)
    # نبعت الـ history الموجود أول ما يتصل
    history = _log_collector.get_all()
    for entry in history:
        try:
            await websocket.send_text(json.dumps(entry))
        except Exception:
            break
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        await log_manager.disconnect(websocket)


# ─── Entry point ─────────────────────────────────────────────────────────────
if __name__ == "__main__":
    log.info("=" * 60)
    log.info("Test Station Controller — API Server")
    log.info(f"Code dir: {_CODE_DIR}")
    log.info("Starting on http://0.0.0.0:8000")
    log.info("=" * 60)
    uvicorn.run(api, host="0.0.0.0", port=8000, log_level="info")
