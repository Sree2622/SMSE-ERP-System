#!/usr/bin/env bash
set -euo pipefail

# Downloads a public Roboflow-exported TFLite model that includes Sprite/Lays-like classes.
# You must set ROBOFLOW_API_KEY (free account key) before running this script.

: "${ROBOFLOW_API_KEY:?Set ROBOFLOW_API_KEY first}"

WORKSPACE="rows-and-cols-of-vending-machines"
PROJECT="vendingitems"
VERSION="1"
OUT_DIR="assets/ml"
OUT_FILE="${OUT_DIR}/kirana_brands.tflite"
TMP_ZIP="${OUT_DIR}/roboflow_model.zip"

mkdir -p "${OUT_DIR}"

URL="https://api.roboflow.com/${WORKSPACE}/${PROJECT}/${VERSION}?api_key=${ROBOFLOW_API_KEY}&format=tflite"

echo "Downloading model from: ${URL}" >&2
curl -fL "${URL}" -o "${TMP_ZIP}"

# Roboflow usually returns a zip that contains model.tflite and metadata files.
unzip -o "${TMP_ZIP}" -d "${OUT_DIR}" >/dev/null

if [[ -f "${OUT_DIR}/model.tflite" ]]; then
  mv -f "${OUT_DIR}/model.tflite" "${OUT_FILE}"
fi

if [[ ! -f "${OUT_FILE}" ]]; then
  echo "Expected ${OUT_FILE} was not found after extraction." >&2
  exit 1
fi

rm -f "${TMP_ZIP}"
echo "Saved model to ${OUT_FILE}" >&2
