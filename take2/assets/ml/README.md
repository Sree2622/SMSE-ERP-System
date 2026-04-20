# Kirana Vision model assets

Place your TensorFlow Lite model files in this folder:

- `assets/ml/model_quant.tflite` (recommended for ML Kit / Flutter)
- `assets/ml/model.tflite`
- `assets/ml/model_unquant.tflite`
- `assets/ml/labels.txt`

`KiranaVisionAgent` now attempts to load a local custom model in this order:

1. `model_quant.tflite`
2. `model.tflite`
3. `model_unquant.tflite`

If no model is found or loading fails, the app automatically falls back to the default ML Kit base labeler.

## Floating-point Teachable Machine model note

If you export a floating-point model from Teachable Machine, ML Kit may fail unless normalization metadata is embedded.  
Use either of these options:

- Preferred: Export a **quantized** model (`model_quant.tflite`).
- Alternative: Add metadata to float model with mean/std normalization:
  - mean: `127.5`
  - std: `127.5`
  - normalized value: `(pixel - 127.5) / 127.5`

## labels.txt format

One class label per line, for example:

```txt
sprite bottle
lays classic
```

These labels are used as hints when mapping model predictions to item names from your inventory.

## Fallback order in app

1. Custom local TFLite model (`model_quant.tflite` → `model.tflite` → `model_unquant.tflite`)
2. ML Kit base image labeling
3. Cloud endpoint (`KIRANA_LLM_ENDPOINT`)
4. OCR matching
