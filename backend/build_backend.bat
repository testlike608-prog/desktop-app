@echo off
setlocal
title Build api_server.exe

echo ============================================================
echo   Test Station Controller — Build Backend (PyInstaller)
echo ============================================================
echo.

:: ── نروح لفولدر code/ ──────────────────────────────────────────────────────
cd /d "%~dp0"
cd ..\..\..\code
if not exist ClientsClass.py (
    echo [ERROR] مش لاقي ClientsClass.py في فولدر code/
    echo تأكد إن الباتش صح: %CD%
    pause & exit /b 1
)

echo [1/3] Installing PyInstaller...
pip install pyinstaller --quiet --break-system-packages 2>nul
pip install pyinstaller --quiet 2>nul

echo [2/3] Building api_server.exe ...
echo.

pyinstaller ^
  --onefile ^
  --noconsole ^
  --name api_server ^
  --paths . ^
  --hidden-import=uvicorn.logging ^
  --hidden-import=uvicorn.loops ^
  --hidden-import=uvicorn.loops.auto ^
  --hidden-import=uvicorn.protocols ^
  --hidden-import=uvicorn.protocols.http ^
  --hidden-import=uvicorn.protocols.http.auto ^
  --hidden-import=uvicorn.protocols.websockets ^
  --hidden-import=uvicorn.protocols.websockets.auto ^
  --hidden-import=uvicorn.lifespan ^
  --hidden-import=uvicorn.lifespan.on ^
  --hidden-import=uvicorn.lifespan.off ^
  --hidden-import=anyio ^
  --hidden-import=anyio._backends._asyncio ^
  --hidden-import=websockets ^
  --hidden-import=fastapi ^
  --hidden-import=cv2 ^
  --add-data "config.json;." ^
  ..\flutter\Water_Drop_detec_app\backend\api_server.py

if errorlevel 1 (
    echo.
    echo [ERROR] فشل الـ build — اقرأ الـ errors فوق
    pause & exit /b 1
)

echo.
echo [3/3] Copying api_server.exe to Flutter release folder...

:: ── نحدد فولدر Flutter الـ release ──────────────────────────────────────────
set FLUTTER_RELEASE=..\flutter\Water_Drop_detec_app\build\windows\x64\runner\Release

if exist "%FLUTTER_RELEASE%" (
    copy /y dist\api_server.exe "%FLUTTER_RELEASE%\api_server.exe"
    echo     Copied to: %FLUTTER_RELEASE%\api_server.exe
) else (
    echo     Flutter Release folder not found yet — copy manually after flutter build:
    echo     FROM: %CD%\dist\api_server.exe
    echo     TO:   Water_Drop_detec_app\build\windows\x64\runner\Release\
)

echo.
echo ============================================================
echo   Done!
echo   api_server.exe is in: %CD%\dist\
echo.
echo   خطوات التسليم للعميل:
echo   1. flutter build windows --release
echo   2. شغّل هذا الـ script عشان تعمل api_server.exe
echo   3. ارفق api_server.exe جنب test_station_controller.exe
echo      في فولدر: build\windows\x64\runner\Release\
echo ============================================================
pause
