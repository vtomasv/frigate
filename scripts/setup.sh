#!/bin/bash
# =============================================================================
# Frigate NVR - Script de preparación para Apple Silicon
# =============================================================================
# Ejecutar antes de levantar Docker Compose por primera vez.
# Este script:
#   1. Crea los directorios necesarios
#   2. Descarga el modelo YOLOv9-t si no existe
#   3. Descarga el video de prueba para la cámara simulada
#   4. Verifica que Ollama esté corriendo
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

echo "============================================="
echo " Frigate NVR - Setup para Apple Silicon"
echo "============================================="
echo ""

# 1. Crear directorios necesarios
echo "[1/4] Creando directorios..."
mkdir -p config/model_cache
mkdir -p storage
mkdir -p mqtt/config mqtt/data mqtt/log
echo "  OK"

# 2. Descargar modelo YOLO
MODEL_FILE="config/model_cache/yolo.onnx"
MODEL_URL="https://github.com/thomas-gall/frigate-yolov9-models/raw/main/yolov9-t-320.onnx"

if [ -f "$MODEL_FILE" ]; then
    echo "[2/4] Modelo YOLOv9-t ya existe en $MODEL_FILE"
else
    echo "[2/4] Descargando modelo YOLOv9-t (320x320)..."
    wget -q --show-progress "$MODEL_URL" -O "$MODEL_FILE"
    echo "  OK - Modelo descargado"
fi

# 3. Descargar video de prueba (personas, bicicletas, autos)
VIDEO_FILE="config/test_video.mp4"
VIDEO_URL="https://github.com/intel-iot-devkit/sample-videos/raw/master/person-bicycle-car-detection.mp4"

if [ -f "$VIDEO_FILE" ]; then
    echo "[3/4] Video de prueba ya existe en $VIDEO_FILE"
else
    echo "[3/4] Descargando video de prueba (personas, bicicletas, autos)..."
    wget -q --show-progress "$VIDEO_URL" -O "$VIDEO_FILE"
    echo "  OK - Video descargado (768x432, H.264, 12fps, ~54s)"
fi

# 4. Verificar Ollama
echo "[4/4] Verificando Ollama..."
if command -v ollama &> /dev/null; then
    if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo "  OK - Ollama está corriendo"
        echo "  Modelos disponibles:"
        ollama list 2>/dev/null | head -10 || true
    else
        echo "  AVISO: Ollama está instalado pero no está corriendo."
        echo "  Inicia Ollama antes de levantar Frigate para usar GenAI."
    fi
else
    echo "  AVISO: Ollama no está instalado."
    echo "  Instálalo desde https://ollama.com/download para usar GenAI."
    echo "  Luego ejecuta: ollama pull qwen3-vl:4b"
fi

echo ""
echo "============================================="
echo " Setup completado. Para iniciar Frigate:"
echo ""
echo "   docker compose -f docker-compose.apple-silicon.yml up -d"
echo ""
echo " Cámaras de prueba configuradas:"
echo "   - video_prueba: Video local en loop (personas/autos/bicicletas)"
echo "   - webcam_publica: Webcam MJPEG pública (Japón)"
echo "   - wowza_test: Stream RTSP de Wowza (video de represa)"
echo ""
echo " Acceso: http://localhost:8971"
echo "============================================="
