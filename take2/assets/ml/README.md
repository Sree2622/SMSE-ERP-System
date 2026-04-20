# Kirana TFLite model

Expected runtime model path:

- `assets/ml/kirana_brands.tflite`

## Public model source (Sprite + Lays classes)

This project is wired to use a Roboflow public model from:

- Workspace: `rows-and-cols-of-vending-machines`
- Project: `vendingitems`
- Version: `1`

The dataset listing for that model includes `sprite` plus multiple `lays` classes
(`Lays Classic`, `Lays Stax Original`, etc.).

## Download command

From `take2/` run:

```bash
export ROBOFLOW_API_KEY="<your_api_key>"
./tool/download_public_kirana_model.sh
```

This writes the model to:

- `assets/ml/kirana_brands.tflite`

After downloading, rebuild the app so Flutter bundles the model asset.

## Fallback order in app

1. Custom local TFLite model (`kirana_brands.tflite`)
2. ML Kit base image labeling
3. Cloud endpoint (`KIRANA_LLM_ENDPOINT`)
4. OCR matching
