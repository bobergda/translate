#!/usr/bin/env bash
set -euo pipefail

DEFAULT_MLX_REPO_URL="https://huggingface.co/mlx-community/translategemma-4b-it-4bit"
DEFAULT_MLX_RESOLVE_BASE="https://huggingface.co/mlx-community/translategemma-4b-it-4bit/resolve/main"

MODEL_URL="${MODEL_URL:-$DEFAULT_MLX_REPO_URL}"
TOKEN="${HF_TOKEN:-${HUGGINGFACE_TOKEN:-}}"
USER_OUTPUT="${1:-}"

hf_curl_download() {
  local source_url="$1"
  local destination_path="$2"

  local -a curl_args=(--location --fail --progress-bar "$source_url" --output "$destination_path")
  if [[ -n "${TOKEN}" ]]; then
    curl_args=(--header "Authorization: Bearer ${TOKEN}" "${curl_args[@]}")
  fi

  curl "${curl_args[@]}"
}

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

is_mlx_source_url() {
  case "${MODEL_URL}" in
    "${DEFAULT_MLX_REPO_URL}"|"${DEFAULT_MLX_REPO_URL}/"|"${DEFAULT_MLX_RESOLVE_BASE}"|"${DEFAULT_MLX_RESOLVE_BASE}/"*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

download_mlx_snapshot() {
  local output_dir="$1"

  mkdir -p "${output_dir}"

  local files=(
    README.md
    added_tokens.json
    chat_template.jinja
    config.json
    generation_config.json
    model.safetensors
    model.safetensors.index.json
    special_tokens_map.json
    tokenizer.json
    tokenizer.model
    tokenizer_config.json
  )

  echo "Pobieram gotowy model TranslateGemma 4B (MLX):"
  echo "  ${DEFAULT_MLX_REPO_URL}"
  echo "Katalog docelowy: ${output_dir}"

  for file in "${files[@]}"; do
    local source_url="${DEFAULT_MLX_RESOLVE_BASE}/${file}?download=true"
    local target_path="${output_dir}/${file}"
    echo "- ${file}"
    hf_curl_download "${source_url}" "${target_path}"
  done

  echo "OK: pobrano pliki MLX do ${output_dir}"
  echo "UWAGA: to jest model MLX (safetensors), nie Core ML (.mlpackage)."
  echo "Ta appka Core ML go bezposrednio nie zaladuje."
}

if is_mlx_source_url; then
  OUTPUT_DIR="${USER_OUTPUT:-$HOME/Downloads/translategemma-4b-it-4bit-mlx}"
  download_mlx_snapshot "${OUTPUT_DIR}"
  exit 0
fi

OUTPUT_PATH="${USER_OUTPUT:-$HOME/Downloads/TranslateGemma-4B-IT.mlpackage}"

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

archive_path="${tmp_dir}/model.download"

echo "Pobieram artefakt Core ML z URL:"
echo "  ${MODEL_URL}"

hf_curl_download "${MODEL_URL}" "${archive_path}"

mkdir -p "$(dirname "${OUTPUT_PATH}")"

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
