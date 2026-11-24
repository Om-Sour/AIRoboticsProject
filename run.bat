@echo off
REM One-command start for Windows.
cd /d "%~dp0"

if not exist ".venv" (
  echo Creating virtual environment...
  python -m venv .venv
)
call .venv\Scripts\activate.bat

REM A global PIP_USER=1 makes pip refuse to install inside a virtualenv.
set PIP_USER=0

echo Installing requirements...
python -m pip install -q --upgrade pip
python -m pip install -q -r requirements.txt
if errorlevel 1 (
  echo.
  echo Could not install the requirements. Run this by hand to see the error:
  echo    python -m pip install -r requirements.txt
  pause
  exit /b 1
)

if not exist ".env" (
  copy .env.example .env >nul
  echo Created .env from .env.example - edit it if needed.
)

echo.
echo Starting StudyMate on http://127.0.0.1:8000
echo First run: make sure Ollama is running and the model is pulled:
echo    ollama serve
echo    ollama pull qwen2.5:3b
echo.
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
pause
