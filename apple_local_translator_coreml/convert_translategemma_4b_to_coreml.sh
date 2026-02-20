#!/usr/bin/env bash
set -euo pipefail

PYTHON_BIN="${PYTHON_BIN:-python3}"
INPUT_MODEL_DIR="${1:-$HOME/Downloads/translategemma-4b-it-hf}"
OUTPUT_PATH="${2:-$HOME/Downloads/translategemma-4b-it-coreml/Model.mlpackage}"
FEATURE="${FEATURE:-causal-lm-with-past}"
QUANTIZE="${QUANTIZE:-float16}"
COMPUTE_UNITS="${COMPUTE_UNITS:-cpu_and_ne}"

if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
  echo "Blad: nie znaleziono ${PYTHON_BIN}." >&2
  exit 1
fi

if [[ ! -d "${INPUT_MODEL_DIR}" ]]; then
  cat >&2 <<MSG
Blad: katalog modelu nie istnieje:
  ${INPUT_MODEL_DIR}

Najpierw pobierz checkpoint:
  ./download_translategemma_4b_hf_checkpoint.sh
MSG
  exit 1
fi

if ! "${PYTHON_BIN}" - <<'PY' >/dev/null 2>&1
import importlib
for module_name in ["exporters.coreml", "coremltools", "transformers"]:
    importlib.import_module(module_name)
PY
then
  cat >&2 <<'MSG'
Blad: brak wymaganych pakietow Pythona do exportu Core ML.

Zainstaluj np.:
  python3 -m pip install --upgrade pip
  python3 -m pip install coremltools transformers safetensors sentencepiece
  python3 -m pip install git+https://github.com/huggingface/exporters.git
MSG
  exit 1
fi

mkdir -p "$(dirname "${OUTPUT_PATH}")"

echo "Konwertuje TranslateGemma 4B do Core ML..."
echo "  input:         ${INPUT_MODEL_DIR}"
echo "  output:        ${OUTPUT_PATH}"
echo "  feature:       ${FEATURE}"
echo "  quantize:      ${QUANTIZE}"
echo "  compute_units: ${COMPUTE_UNITS}"

"${PYTHON_BIN}" -m exporters.coreml \
  --model="${INPUT_MODEL_DIR}" \
  --feature="${FEATURE}" \
  --quantize="${QUANTIZE}" \
  --compute_units="${COMPUTE_UNITS}" \
  "${OUTPUT_PATH}"

echo "OK: export zakonczony."
echo "Jesli plik powstal, zaimportuj go w appce przez 'Importuj model Core ML'."
echo "Uwaga: dla architektury Gemma export moze byc ograniczony w zaleznosci od wersji exporters/coremltools."
