#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="${PROJECT_DIR}/test_translategemma_4b.py"
DOWNLOAD_SCRIPT="${PROJECT_DIR}/download_required_files.sh"
REQUIREMENTS_PATH="${PROJECT_DIR}/requirements.txt"

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
  install  - instaluje zależności z requirements.txt
  download - pobiera pliki modelu przez download_required_files.sh
  run      - uruchamia test_translategemma_4b.py
  bez komendy - też uruchamia test_translategemma_4b.py
EOF
}

command="${1:-run}"

case "${command}" in
  install)
    python3 -m pip install -r "${REQUIREMENTS_PATH}"
    ;;
  download)
    shift || true
    "${DOWNLOAD_SCRIPT}" "${@}"
    ;;
  run)
    shift || true
    python3 "${SCRIPT_PATH}" "${@}"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    python3 "${SCRIPT_PATH}" "${@}"
    ;;
esac
