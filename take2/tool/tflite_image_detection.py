#!/usr/bin/env python3
"""Run TensorFlow Lite object detection on one image.

This script is intentionally similar to common TFLite image classification snippets,
but adapted for object detection outputs (boxes/classes/scores/count).

Example:
  python tool/tflite_image_detection.py \
    --model /path/to/detect.tflite \
    --labels /path/to/labels.txt \
    --image /path/to/test.jpg \
    --threshold 0.35
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Sequence, Tuple

import numpy as np
from PIL import Image
import tensorflow as tf


@dataclass
class Detection:
    label: str
    score: float
    bbox_yxminmax: Tuple[float, float, float, float]


def load_labels(label_path: Path) -> List[str]:
    with label_path.open("r", encoding="utf-8") as f:
        return [line.strip() for line in f if line.strip()]


def preprocess_image(
    image_path: Path,
    input_shape: Sequence[int],
    input_dtype: np.dtype,
    quantization: Tuple[float, int],
) -> np.ndarray:
    _, height, width, _ = input_shape

    img = Image.open(image_path).convert("RGB").resize((width, height))
    input_data = np.expand_dims(img, axis=0)

    if input_dtype == np.uint8:
        return np.array(input_data, dtype=np.uint8)

    if input_dtype == np.int8:
        scale, zero_point = quantization
        if scale == 0:
            raise ValueError("Invalid quantization scale=0 for int8 input tensor.")
        return (input_data / 255.0 / scale + zero_point).astype(np.int8)

    return np.array(input_data, dtype=np.float32) / 255.0


def dequantize_if_needed(array: np.ndarray, dtype: np.dtype, quant: Tuple[float, int]) -> np.ndarray:
    if dtype not in (np.uint8, np.int8):
        return array

    scale, zero_point = quant
    if scale == 0:
        return array.astype(np.float32)
    return scale * (array.astype(np.float32) - zero_point)


def detect_output_tensors(
    interpreter: tf.lite.Interpreter, output_details: Sequence[Dict],
) -> Tuple[np.ndarray, np.ndarray, np.ndarray, int]:
    """Return boxes, classes, scores, count from model outputs.

    Supports common TFLite detection models where outputs are either named tensors
    or unnamed tensors with canonical shapes.
    """

    tensors: Dict[str, np.ndarray] = {}
    for detail in output_details:
        raw = interpreter.get_tensor(detail["index"])
        arr = np.squeeze(raw)
        arr = dequantize_if_needed(arr, detail["dtype"], detail.get("quantization", (0.0, 0)))
        tensors[detail["name"].lower()] = arr

    boxes = classes = scores = None
    count = None

    for name, arr in tensors.items():
        if "box" in name and arr.ndim == 2 and arr.shape[-1] == 4:
            boxes = arr
        elif "class" in name and arr.ndim == 1:
            classes = arr
        elif "score" in name and arr.ndim == 1:
            scores = arr
        elif ("count" in name or "num" in name) and np.ndim(arr) == 0:
            count = int(arr)

    # Fallback by shape if names are generic.
    if boxes is None or classes is None or scores is None:
        candidates_2d = [a for a in tensors.values() if a.ndim == 2]
        candidates_1d = [a for a in tensors.values() if a.ndim == 1]

        if boxes is None:
            for arr in candidates_2d:
                if arr.shape[-1] == 4:
                    boxes = arr
                    break

        if classes is None and candidates_1d:
            classes = candidates_1d[0]
        if scores is None and len(candidates_1d) > 1:
            scores = candidates_1d[1]

    if boxes is None or classes is None or scores is None:
        shape_map = {name: list(arr.shape) for name, arr in tensors.items()}
        raise RuntimeError(f"Could not infer detection outputs. Tensor shapes: {shape_map}")

    max_dets = min(len(boxes), len(classes), len(scores))
    if count is None:
        count = max_dets
    count = max(0, min(count, max_dets))

    return boxes, classes, scores, count


def run_detection(model_path: Path, labels: List[str], image_path: Path, threshold: float) -> List[Detection]:
    interpreter = tf.lite.Interpreter(model_path=str(model_path))
    interpreter.allocate_tensors()

    input_detail = interpreter.get_input_details()[0]
    output_details = interpreter.get_output_details()

    input_data = preprocess_image(
        image_path=image_path,
        input_shape=input_detail["shape"],
        input_dtype=input_detail["dtype"],
        quantization=input_detail.get("quantization", (0.0, 0)),
    )

    interpreter.set_tensor(input_detail["index"], input_data)
    interpreter.invoke()

    boxes, classes, scores, count = detect_output_tensors(interpreter, output_details)

    detections: List[Detection] = []
    for i in range(count):
        score = float(scores[i])
        if score < threshold:
            continue

        class_idx = int(classes[i])
        label = labels[class_idx] if 0 <= class_idx < len(labels) else f"class_{class_idx}"
        ymin, xmin, ymax, xmax = map(float, boxes[i])

        detections.append(
            Detection(
                label=label,
                score=score,
                bbox_yxminmax=(ymin, xmin, ymax, xmax),
            )
        )

    return sorted(detections, key=lambda d: d.score, reverse=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run TFLite image detection.")
    parser.add_argument("--model", required=True, type=Path, help="Path to .tflite detection model")
    parser.add_argument("--labels", required=True, type=Path, help="Path to labels.txt")
    parser.add_argument("--image", required=True, type=Path, help="Path to test image")
    parser.add_argument("--threshold", type=float, default=0.30, help="Score threshold (0-1)")
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    labels = load_labels(args.labels)
    detections = run_detection(args.model, labels, args.image, args.threshold)

    if not detections:
        print(f"No detections >= {args.threshold:.2f}")
        return

    print(f"Detections (threshold={args.threshold:.2f}):")
    for det in detections:
        ymin, xmin, ymax, xmax = det.bbox_yxminmax
        print(
            f"- {det.label:20s} score={det.score:.4f} "
            f"bbox=[ymin={ymin:.3f}, xmin={xmin:.3f}, ymax={ymax:.3f}, xmax={xmax:.3f}]"
        )


if __name__ == "__main__":
    main()
