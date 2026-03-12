#!/bin/bash
# =============================================================================
# Frigate NVR - Script de preparación para Apple Silicon
# =============================================================================
# Ejecutar antes de levantar Docker Compose por primera vez.
# Este script:
#   1. Crea los directorios necesarios
#   2. Descarga el modelo YOLOv8n ONNX si no existe
#   3. Descarga los videos de prueba para las cámaras simuladas
#   4. Verifica que Ollama esté corriendo
#
# Compatible con bash 3.x (macOS default) y zsh.
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
MODEL_URL="https://github.com/vtomasv/frigate/releases/download/v0.17.0-apple-silicon/yolov8n.onnx"
MODEL_SIZE_MIN=10000000

download_model() {
    echo "  Descargando modelo YOLOv8n ONNX (320x320, ~12MB)..."
    curl -L -o "$MODEL_FILE" "$MODEL_URL"

    if [ ! -s "$MODEL_FILE" ]; then
        echo "  ERROR: El archivo descargado está vacío."
        rm -f "$MODEL_FILE"
        return 1
    fi

    FILE_SIZE=$(wc -c < "$MODEL_FILE" | tr -d ' ')
    if [ "$FILE_SIZE" -lt "$MODEL_SIZE_MIN" ]; then
        echo "  ERROR: El archivo descargado es demasiado pequeño ($FILE_SIZE bytes)."
        rm -f "$MODEL_FILE"
        return 1
    fi

    echo "  OK - Modelo descargado ($FILE_SIZE bytes)"
    return 0
}

if [ -f "$MODEL_FILE" ]; then
    FILE_SIZE=$(wc -c < "$MODEL_FILE" | tr -d ' ')
    if [ "$FILE_SIZE" -lt "$MODEL_SIZE_MIN" ]; then
        echo "[2/4] Modelo existente parece corrupto ($FILE_SIZE bytes). Re-descargando..."
        rm -f "$MODEL_FILE"
        download_model || echo "  FALLO: No se pudo descargar el modelo."
    else
        echo "[2/4] Modelo YOLOv8n ya existe en $MODEL_FILE ($FILE_SIZE bytes)"
    fi
else
    echo "[2/4] Descargando modelo YOLOv8n ONNX..."
    download_model || echo "  FALLO: No se pudo descargar el modelo."
fi

# 3. Descargar videos de prueba
# Usando arrays simples compatibles con bash 3.x y zsh
INTEL_BASE="https://github.com/intel-iot-devkit/sample-videos/raw/master"

VIDEO_FILES="config/test_video.mp4
config/people-detection.mp4
config/car-detection.mp4
config/one-by-one-person-detection.mp4
config/store-aisle-detection.mp4
config/worker-zone-detection.mp4"

VIDEO_URLS="${INTEL_BASE}/person-bicycle-car-detection.mp4
${INTEL_BASE}/people-detection.mp4
${INTEL_BASE}/car-detection.mp4
${INTEL_BASE}/one-by-one-person-detection.mp4
${INTEL_BASE}/store-aisle-detection.mp4
${INTEL_BASE}/worker-zone-detection.mp4"

VIDEO_DESCS="Calle: personas, bicicletas, autos (768x432)
Multitud de personas caminando (768x432)
Autopista: tráfico de vehículos (768x432)
Entrada: personas pasando una por una (768x432)
Tienda: pasillo interior retail (720x404)
Obra: zona de trabajo exterior (1920x1080)"

TOTAL_VIDEOS=6
CURRENT=0
DOWNLOADED=0

echo "[3/4] Verificando $TOTAL_VIDEOS videos de prueba..."

# Leer línea por línea de cada variable
while IFS= read -r FILE <&3 && IFS= read -r URL <&4 && IFS= read -r DESC <&5; do
    CURRENT=$((CURRENT + 1))
    if [ -f "$FILE" ] && [ -s "$FILE" ]; then
        echo "  [$CURRENT/$TOTAL_VIDEOS] Ya existe: $DESC"
    else
        echo "  [$CURRENT/$TOTAL_VIDEOS] Descargando: $DESC"
        curl -L -o "$FILE" "$URL" 2>/dev/null
        if [ -s "$FILE" ]; then
            DOWNLOADED=$((DOWNLOADED + 1))
            echo "    OK"
        else
            echo "    FALLO: No se pudo descargar $FILE"
            rm -f "$FILE"
        fi
    fi
done 3<<< "$VIDEO_FILES" 4<<< "$VIDEO_URLS" 5<<< "$VIDEO_DESCS"

echo "  OK - $DOWNLOADED videos nuevos descargados ($TOTAL_VIDEOS total)"

# 4. Verificar Ollama
echo "[4/4] Verificando Ollama..."
if command -v ollama > /dev/null 2>&1; then
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
echo "   docker compose -f docker-compose.apple-silicon.yml up -d --build"
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
echo ""
echo " Si el modelo no se descargó correctamente, puedes generarlo manualmente:"
echo "   pip install ultralytics"
echo "   python -c \"from ultralytics import YOLO; YOLO('yolov8n.pt').export(format='onnx', imgsz=320)\""
echo "   cp yolov8n.onnx config/model_cache/yolo.onnx"
echo "============================================="
