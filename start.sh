#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="${PROJECT_DIR}/test_translategemma_4b.py"
DOWNLOAD_SCRIPT="${PROJECT_DIR}/download_required_files.sh"
REQUIREMENTS_PATH="${PROJECT_DIR}/requirements.txt"
VENV_DIR="${PROJECT_DIR}/.venv"
VENV_PYTHON="${VENV_DIR}/bin/python3"

ensure_venv() {
  if [[ ! -d "${VENV_DIR}" ]]; then
    python3 -m venv "${VENV_DIR}"
  fi
}

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 nie jest dostępny w PATH" >&2
  exit 1
fi

usage() {
  cat <<'EOF'
Użycie:
  ./start.sh install
  ./start.sh download [MODEL_ID] [OUTPUT_DIR]
  ./start.sh run [ARGUMENTY_DLA_PYTHONA...]
  ./start.sh [ARGUMENTY_DLA_PYTHONA...]

Opis:
  install  - tworzy .venv i instaluje zależności z requirements.txt
  download - pobiera model przez ollama pull (przez download_required_files.sh)
  run      - uruchamia test_translategemma_4b.py przez .venv
  bez komendy - też uruchamia test_translategemma_4b.py przez .venv
EOF
}

command="${1:-run}"

case "${command}" in
  install)
    ensure_venv
    "${VENV_PYTHON}" -m pip install --upgrade pip
    "${VENV_PYTHON}" -m pip install -r "${REQUIREMENTS_PATH}"
    ;;
  download)
    shift || true
    "${DOWNLOAD_SCRIPT}" "${@}"
    ;;
  run)
    shift || true
    ensure_venv
    "${VENV_PYTHON}" "${SCRIPT_PATH}" "${@}"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    ensure_venv
    "${VENV_PYTHON}" "${SCRIPT_PATH}" "${@}"
    ;;
esac
