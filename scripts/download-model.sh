#!/bin/bash
# =============================================================================
# Descarga el modelo YOLOv9-t optimizado para Frigate
# =============================================================================
set -e

MODEL_DIR="config/model_cache"
MODEL_FILE="$MODEL_DIR/yolo.onnx"
MODEL_URL="https://github.com/thomas-gall/frigate-yolov9-models/raw/main/yolov9-t-320.onnx"

mkdir -p "$MODEL_DIR"

if [ -f "$MODEL_FILE" ]; then
    echo "[OK] El modelo ya existe en $MODEL_FILE"
else
    echo "[...] Descargando YOLOv9-t (320x320) desde GitHub..."
    wget -q --show-progress "$MODEL_URL" -O "$MODEL_FILE"
    echo "[OK] Modelo descargado en $MODEL_FILE"
fi

echo ""
echo "Modelo listo. Puedes iniciar Frigate con:"
echo "  docker compose -f docker-compose.apple-silicon.yml up -d"
