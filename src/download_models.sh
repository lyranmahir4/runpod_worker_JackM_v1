#!/usr/bin/env bash
set -euo pipefail

echo "worker-comfyui: Model bootstrap starting"

# Prefer the Network Volume mount if available; otherwise fall back to image models dir.
DEST_MODELS_ROOT="/runpod-volume/models"
if [[ ! -d "/runpod-volume" ]] || [[ ! -w "/runpod-volume" ]]; then
  DEST_MODELS_ROOT="/comfyui/models"
fi

mkdir -p "${DEST_MODELS_ROOT}/checkpoints" "${DEST_MODELS_ROOT}/loras"

# Inputs: use env vars when provided, otherwise defaults to your Pony + LoRA
CIVITAI_TOKEN="${CIVITAI_TOKEN:-}"

PONY_URL="${PONY_URL:-https://civitai.com/api/download/models/2255476?type=Model&format=SafeTensor&size=pruned&fp=fp16}"
PONY_FILENAME="${PONY_FILENAME:-cyberrealisticPony_v140.safetensors}"

LORA_URL="${LORA_URL:-https://civitai.com/api/download/models/993999?type=Model&format=SafeTensor}"
LORA_FILENAME="${LORA_FILENAME:-amateurphoto-v6-forcu.safetensors}"

download_if_missing() {
  local url="$1" dest_path="$2" token="$3"

  if [[ -s "$dest_path" ]]; then
    echo "worker-comfyui: Found $(basename "$dest_path"), skipping download."
    return 0
  fi

  echo "worker-comfyui: Downloading $(basename "$dest_path") to $(dirname "$dest_path")"
  mkdir -p "$(dirname "$dest_path")"

  # Build curl command (with or without auth header)
  if [[ -n "$token" ]]; then
    curl -L --fail --show-error --retry 3 --retry-delay 2 \
      -H "Authorization: Bearer ${token}" \
      -o "$dest_path" "$url" || {
        echo "worker-comfyui: ERROR downloading $(basename "$dest_path") (auth)." >&2
        return 1
      }
  else
    curl -L --fail --show-error --retry 3 --retry-delay 2 \
      -o "$dest_path" "$url" || {
        echo "worker-comfyui: ERROR downloading $(basename "$dest_path") (no auth)." >&2
        return 1
      }
  fi

  if [[ ! -s "$dest_path" ]]; then
    echo "worker-comfyui: ERROR: Downloaded file is empty: $dest_path" >&2
    return 1
  fi

  echo "worker-comfyui: Downloaded $(basename "$dest_path") ($(du -h "$dest_path" | awk '{print $1}'))"
}

# Attempt downloads; do not fail the container if they error
download_if_missing "$PONY_URL" "${DEST_MODELS_ROOT}/checkpoints/${PONY_FILENAME}" "$CIVITAI_TOKEN" || true
download_if_missing "$LORA_URL" "${DEST_MODELS_ROOT}/loras/${LORA_FILENAME}" "$CIVITAI_TOKEN" || true

echo "worker-comfyui: Model bootstrap finished"

