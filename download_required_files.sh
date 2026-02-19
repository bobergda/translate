#!/usr/bin/env bash
set -euo pipefail

MODEL_ID="${1:-translategemma:4b}"

if ! command -v ollama >/dev/null 2>&1; then
  echo "ollama nie jest dostępna w PATH" >&2
  exit 1
fi

if [[ "${2:-}" != "" ]]; then
  echo "Uwaga: drugi argument OUTPUT_DIR jest ignorowany przy Ollama." >&2
fi

echo "Pobieram model Ollama: ${MODEL_ID}"
ollama pull "${MODEL_ID}"
echo "OK: model '${MODEL_ID}' gotowy."
