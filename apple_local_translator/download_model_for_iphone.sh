#!/usr/bin/env bash
set -euo pipefail

MODEL_URL="https://huggingface.co/ggml-org/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q4_K_M.gguf?download=true"
OUTPUT_PATH="${1:-$HOME/Downloads/gemma-3-1b-it-Q4_K_M.gguf}"

mkdir -p "$(dirname "${OUTPUT_PATH}")"

echo "Pobieram model pod iPhone/macOS (Q4_K_M):"
echo "  ${OUTPUT_PATH}"

curl -L --fail --progress-bar "${MODEL_URL}" -o "${OUTPUT_PATH}"

echo "OK: model zapisany w ${OUTPUT_PATH}"
echo "Nastepnie zaimportuj plik GGUF do aplikacji przez 'Importuj GGUF'."
