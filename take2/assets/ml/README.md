# Kirana Vision model assets

Place your TensorFlow Lite model files in this folder:

- `assets/ml/model_unquant.tflite`
- `assets/ml/labels.txt`

`KiranaVisionAgent` now attempts to load this local custom model first. If the model file is missing or fails to load, the app automatically falls back to the default ML Kit base labeler.

## labels.txt format

One class label per line, for example:

```txt
sprite bottle
lays classic
```

These labels are used as hints when mapping model predictions to item names from your inventory.

## Fallback order in app

1. Custom local TFLite model (`model_unquant.tflite`)
2. ML Kit base image labeling
3. Cloud endpoint (`KIRANA_LLM_ENDPOINT`)
4. OCR matching
