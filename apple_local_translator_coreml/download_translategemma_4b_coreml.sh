#!/usr/bin/env bash
set -euo pipefail

DEFAULT_MODEL_ID="google/translategemma-4b-it"
MODEL_ID="${MODEL_ID:-$DEFAULT_MODEL_ID}"
HF_API_URL="https://huggingface.co/api/models/${MODEL_ID}"
HF_RESOLVE_BASE="https://huggingface.co/${MODEL_ID}/resolve/main"
OUTPUT_DIR="${1:-$HOME/Downloads/translategemma-4b-it-hf}"
TOKEN="${HF_TOKEN:-${HUGGINGFACE_TOKEN:-}}"

if ! command -v jq >/dev/null 2>&1; then
  echo "Blad: wymagany jest jq." >&2
  exit 1
fi

hf_curl_download() {
  local source_url="$1"
  local destination_path="$2"

  mkdir -p "$(dirname "${destination_path}")"

  local -a curl_args=(--location --fail --progress-bar "$source_url" --output "$destination_path")
  if [[ -n "${TOKEN}" ]]; then
    curl_args=(--header "Authorization: Bearer ${TOKEN}" "${curl_args[@]}")
  fi

  curl "${curl_args[@]}"
}

echo "Pobieram TranslateGemma 4B w formacie Transformers/safetensors (pod konwersje do Core ML):"
echo "  model: ${MODEL_ID}"
echo "  folder: ${OUTPUT_DIR}"

tmp_json="$(mktemp)"
cleanup() {
  rm -f "${tmp_json}"
}
trap cleanup EXIT

if [[ -n "${TOKEN}" ]]; then
  curl --location --fail --silent --show-error \
    --header "Authorization: Bearer ${TOKEN}" \
    "${HF_API_URL}" > "${tmp_json}"
else
  curl --location --fail --silent --show-error \
    "${HF_API_URL}" > "${tmp_json}"
fi

mapfile -t files < <(
  jq -r '
    [
      .siblings[]?.rfilename
      | select(
          test("(^|/)config\\.json$") or
          test("(^|/)generation_config\\.json$") or
          test("(^|/)tokenizer\\.json$") or
          test("(^|/)tokenizer\\.model$") or
          test("(^|/)tokenizer_config\\.json$") or
          test("(^|/)special_tokens_map\\.json$") or
          test("(^|/)added_tokens\\.json$") or
          test("(^|/)chat_template\\.jinja$") or
          test("\\.safetensors$") or
          test("\\.safetensors\\.index\\.json$")
        )
    ]
    | unique
    | .[]
  ' "${tmp_json}"
)

if [[ "${#files[@]}" -eq 0 ]]; then
  echo "Blad: nie znaleziono plikow safetensors/tokenizera w repo modelu ${MODEL_ID}." >&2
  exit 1
fi

for file in "${files[@]}"; do
  src_url="${HF_RESOLVE_BASE}/${file}?download=true"
  dst_path="${OUTPUT_DIR}/${file}"
  echo "- ${file}"
  hf_curl_download "${src_url}" "${dst_path}"
done

echo "OK: pobrano checkpoint Transformers/safetensors do ${OUTPUT_DIR}"
echo "Ten format nadaje sie do konwersji do Core ML."
echo "Uwaga: appka z tego katalogu nie wczytuje safetensors bezposrednio; potrzebny jest artefakt Core ML (.mlpackage/.mlmodel/.mlmodelc)."
