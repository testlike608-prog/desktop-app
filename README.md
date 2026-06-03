# Test Station Controller — Flutter + Python

نفس مشروع **Industrial Test Station Controller** بس بـ:
- **Backend**: Python FastAPI (بدل الـ PySide6 GUI)
- **Frontend**: Flutter Desktop (Windows)

---

## الهيكل

```
Water_Drop_detec_app/
├── backend/
│   ├── api_server.py       ← FastAPI server
│   └── requirements.txt
├── lib/
│   ├── main.dart
│   ├── models/
│   ├── services/
│   ├── screens/
│   └── widgets/
└── pubspec.yaml
```

---

## خطوات التشغيل

### 1. Backend (Python)

```bash
# ركّب الـ dependencies الجديدة
pip install fastapi uvicorn[standard] websockets

# شغّل السيرفر من داخل فولدر code/
cd C:\...\FRESH\code
python ..\flutter\Water_Drop_detec_app\backend\api_server.py
```

السيرفر بيشتغل على: `http://localhost:8000`

### 2. Frontend (Flutter)

```bash
cd C:\...\FRESH\flutter\Water_Drop_detec_app

# لو المشروع جديد — ابدأ بـ:
flutter create . --project-name test_station_controller --platforms windows

# ركّب الـ packages
flutter pub get

# شغّل على Windows
flutter run -d windows
```

---

## الـ API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/state` | الحالة الكاملة |
| POST | `/api/start` | تشغيل البرنامج |
| POST | `/api/stop` | إيقاف البرنامج |
| GET | `/api/config` | جلب الإعدادات |
| PATCH | `/api/config` | تعديل الإعدادات |
| POST | `/api/config/reset` | استعادة الافتراضيات |
| POST | `/api/config/verify-password` | التحقق من الباسوورد |
| POST | `/api/config/change-password` | تغيير الباسوورد |
| GET | `/api/logs/history` | تاريخ الـ logs |
| GET | `/api/camera/frame` | صورة الكاميرا (base64) |
| WS | `/ws/state` | Real-time state |
| WS | `/ws/logs` | Real-time logs |

---

## ملاحظات

- الـ `api_server.py` بيضيف مسار `code/` تلقائياً لـ `sys.path`
- لازم تشغّل من داخل `code/` عشان الـ relative paths تشتغل صح
- الـ Flutter app بيتصل بـ `localhost:8000` — ممكن تغيره في `lib/services/api_service.dart`
