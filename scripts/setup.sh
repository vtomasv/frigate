#!/bin/bash
# =============================================================================
# Frigate NVR - Script de preparación para Apple Silicon
# =============================================================================
# Ejecutar antes de levantar Docker Compose por primera vez.
# Este script:
#   1. Descarga el modelo YOLOv9-t si no existe
#   2. Crea los directorios necesarios
#   3. Verifica que Ollama esté corriendo
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
echo "[1/3] Creando directorios..."
mkdir -p config/model_cache
mkdir -p storage
mkdir -p mqtt/config mqtt/data mqtt/log
echo "  OK"

# 2. Descargar modelo YOLO
MODEL_FILE="config/model_cache/yolo.onnx"
MODEL_URL="https://github.com/thomas-gall/frigate-yolov9-models/raw/main/yolov9-t-320.onnx"

if [ -f "$MODEL_FILE" ]; then
    echo "[2/3] Modelo YOLOv9-t ya existe en $MODEL_FILE"
else
    echo "[2/3] Descargando modelo YOLOv9-t (320x320)..."
    wget -q --show-progress "$MODEL_URL" -O "$MODEL_FILE"
    echo "  OK - Modelo descargado"
fi

# 3. Verificar Ollama
echo "[3/3] Verificando Ollama..."
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
    echo "  Luego ejecuta: ollama pull llava:13b"
fi

echo ""
echo "============================================="
echo " Setup completado. Para iniciar Frigate:"
echo ""
echo "   docker compose -f docker-compose.apple-silicon.yml up -d"
echo ""
echo "============================================="
