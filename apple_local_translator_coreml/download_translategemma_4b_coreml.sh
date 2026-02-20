#!/usr/bin/env bash
set -euo pipefail

MODEL_URL="${MODEL_URL:-}"
OUTPUT_PATH="${1:-$HOME/Downloads/TranslateGemma-4B-IT.mlpackage}"
TOKEN="${HF_TOKEN:-${HUGGINGFACE_TOKEN:-}}"

if [[ -z "${MODEL_URL}" ]]; then
  cat <<'MSG'
Brak MODEL_URL.

Ten skrypt pobiera gotowy artifact Core ML dla TranslateGemma 4B.
Model musi byc juz wyeksportowany do Core ML (.mlpackage/.mlmodel/.mlmodelc).

Przyklad:
  MODEL_URL="https://example.com/TranslateGemma-4B-IT.mlpackage.zip" \
  ./download_translategemma_4b_coreml.sh

Opcjonalnie:
  HF_TOKEN="hf_..." MODEL_URL="https://..." ./download_translategemma_4b_coreml.sh
MSG
  exit 1
fi

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

archive_path="${tmp_dir}/model.download"

echo "Pobieram TranslateGemma 4B Core ML:"
echo "  ${MODEL_URL}"

curl_args=(--location --fail --progress-bar "${MODEL_URL}" --output "${archive_path}")
if [[ -n "${TOKEN}" ]]; then
  curl_args=(--header "Authorization: Bearer ${TOKEN}" "${curl_args[@]}")
fi
curl "${curl_args[@]}"

mkdir -p "$(dirname "${OUTPUT_PATH}")"

resolve_destination() {
  local requested="$1"
  local ext="$2"

  case "${requested}" in
    *."${ext}")
      printf '%s\n' "${requested}"
      ;;
    *)
      printf '%s\n' "$(dirname "${requested}")/TranslateGemma-4B-IT.${ext}"
      ;;
  esac
}

if unzip -tqq "${archive_path}" >/dev/null 2>&1; then
  unpack_dir="${tmp_dir}/unpacked"
  unzip -qq "${archive_path}" -d "${unpack_dir}"

  artifact_path="$(
    find "${unpack_dir}" \
      \( -name '*.mlpackage' -o -name '*.mlmodelc' -o -name '*.mlmodel' \) \
      | sort | head -n 1
  )"

  if [[ -z "${artifact_path}" ]]; then
    echo "Blad: archiwum nie zawiera .mlpackage/.mlmodel/.mlmodelc" >&2
    exit 1
  fi

  artifact_name="$(basename "${artifact_path}")"
  ext="${artifact_name##*.}"
  destination="$(resolve_destination "${OUTPUT_PATH}" "${ext}")"

  if [[ -e "${destination}" ]]; then
    rm -rf "${destination}"
  fi

  if [[ -d "${artifact_path}" ]]; then
    cp -R "${artifact_path}" "${destination}"
  else
    cp "${artifact_path}" "${destination}"
  fi

  echo "OK: zapisano model Core ML w: ${destination}"
  echo "Nastepnie zaimportuj go w appce przez 'Importuj model Core ML'."
  exit 0
fi

url_no_query="${MODEL_URL%%\?*}"
url_basename="$(basename "${url_no_query}")"

if [[ "${url_basename}" == *.mlmodel ]]; then
  destination="$(resolve_destination "${OUTPUT_PATH}" "mlmodel")"
  cp "${archive_path}" "${destination}"
  echo "OK: zapisano model Core ML w: ${destination}"
  echo "Nastepnie zaimportuj go w appce przez 'Importuj model Core ML'."
  exit 0
fi

echo "Blad: oczekiwano zipa z .mlpackage/.mlmodelc lub bezposredniego pliku .mlmodel." >&2
exit 1
