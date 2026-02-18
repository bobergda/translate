#!/usr/bin/env bash
set -euo pipefail

MODEL_ID="${1:-google/translategemma-4b-it}"
OUTPUT_DIR="${2:-./models/translategemma-4b-it}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 nie jest dostępny w PATH" >&2
  exit 1
fi

echo "Pobieram model: ${MODEL_ID}"
echo "Katalog docelowy: ${OUTPUT_DIR}"

python3 - "$MODEL_ID" "$OUTPUT_DIR" <<'PY'
import os
import sys

from huggingface_hub import snapshot_download

model_id = sys.argv[1]
output_dir = sys.argv[2]
token = os.getenv("HF_TOKEN")

snapshot_download(
    repo_id=model_id,
    local_dir=output_dir,
    local_dir_use_symlinks=False,
    token=token,
)

print(f"OK: model zapisany w {output_dir}")
PY
