#!/usr/bin/env bash
# One-command start for Linux / macOS / Git Bash / WSL.
# Windows users: run.bat is the native way; this script also works in Git Bash.
set -e
cd "$(dirname "$0")"

# Windows (Git Bash / Cygwin) uses a different interpreter name and venv layout.
case "$OSTYPE" in
  msys*|cygwin*|win32*)
    PY=python
    VENV_ACTIVATE=".venv/Scripts/activate"
    ;;
  *)
    PY=python3
    VENV_ACTIVATE=".venv/bin/activate"
    ;;
esac

# Fall back to whatever Python is on PATH.
if ! command -v "$PY" >/dev/null 2>&1; then
  PY=python
fi

if [ ! -d ".venv" ]; then
  echo "Creating virtual environment..."
  "$PY" -m venv .venv
fi

# shellcheck disable=SC1090
source "$VENV_ACTIVATE"

# A global PIP_USER=1 (common on shared college machines) makes pip refuse to
# install inside a virtualenv. Force it off for these two commands.
export PIP_USER=0

echo "Installing requirements..."
python -m pip install -q --upgrade pip || echo "(pip self-upgrade skipped)"
python -m pip install -q -r requirements.txt || {
  echo
  echo "Could not install the requirements. Run this by hand to see the error:"
  echo "  python -m pip install -r requirements.txt"
  exit 1
}
python -c "import fastapi, uvicorn" || { echo "Install did not complete."; exit 1; }

if [ ! -f ".env" ]; then
  if [ -f ".env.example" ]; then
    cp .env.example .env
    echo "Created .env from .env.example - edit it if needed."
  else
    echo "No .env.example found - using built-in defaults."
  fi
fi

echo
echo "Starting StudyMate on http://127.0.0.1:8000"
echo "First run: make sure Ollama is running (ollama serve) and the model is pulled"
echo "           (ollama pull qwen2.5:3b). Otherwise you will see canned demo replies."
echo "Press Ctrl+C to stop."
echo
exec python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
