#!/bin/bash
# =============================================================================
# Frigate NVR - Script de preparación para Apple Silicon
# =============================================================================
# Ejecutar antes de levantar Docker Compose por primera vez.
# Este script:
#   1. Crea los directorios necesarios
#   2. Descarga el modelo YOLOv9-t si no existe
#   3. Descarga los videos de prueba para las cámaras simuladas
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

# 3. Descargar videos de prueba
INTEL_BASE="https://github.com/intel-iot-devkit/sample-videos/raw/master"

declare -A VIDEOS=(
    ["config/test_video.mp4"]="$INTEL_BASE/person-bicycle-car-detection.mp4|Calle: personas, bicicletas, autos (768x432)"
    ["config/people-detection.mp4"]="$INTEL_BASE/people-detection.mp4|Multitud de personas caminando (768x432)"
    ["config/car-detection.mp4"]="$INTEL_BASE/car-detection.mp4|Autopista: tráfico de vehículos (768x432)"
    ["config/one-by-one-person-detection.mp4"]="$INTEL_BASE/one-by-one-person-detection.mp4|Entrada: personas pasando una por una (768x432)"
    ["config/store-aisle-detection.mp4"]="$INTEL_BASE/store-aisle-detection.mp4|Tienda: pasillo interior retail (720x404)"
    ["config/worker-zone-detection.mp4"]="$INTEL_BASE/worker-zone-detection.mp4|Obra: zona de trabajo exterior (1920x1080)"
)

TOTAL_VIDEOS=${#VIDEOS[@]}
CURRENT=0
DOWNLOADED=0

echo "[3/4] Verificando $TOTAL_VIDEOS videos de prueba..."
for FILE in "${!VIDEOS[@]}"; do
    CURRENT=$((CURRENT + 1))
    IFS='|' read -r URL DESC <<< "${VIDEOS[$FILE]}"
    if [ -f "$FILE" ]; then
        echo "  [$CURRENT/$TOTAL_VIDEOS] Ya existe: $DESC"
    else
        echo "  [$CURRENT/$TOTAL_VIDEOS] Descargando: $DESC"
        wget -q --show-progress "$URL" -O "$FILE"
        DOWNLOADED=$((DOWNLOADED + 1))
    fi
done
echo "  OK - $DOWNLOADED videos nuevos descargados ($TOTAL_VIDEOS total)"

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
echo " Cámaras de prueba configuradas (7 total):"
echo "   1. video_calle      - Calle con personas, bicicletas, autos"
echo "   2. video_personas   - Multitud de personas caminando"
echo "   3. video_autopista  - Tráfico de vehículos en autopista"
echo "   4. video_entrada    - Personas pasando una por una"
echo "   5. video_tienda     - Interior de tienda/retail"
echo "   6. video_obra       - Zona de trabajo exterior (1080p)"
echo "   7. webcam_publica   - Webcam MJPEG en vivo (Japón)"
echo ""
echo " Todas las cámaras tienen GenAI habilitado (Ollama)."
echo " Acceso: http://localhost:8971"
echo "============================================="
