#!/bin/bash
# =============================================================================
# Inicia el Apple Silicon Detector de forma NATIVA en macOS
# =============================================================================
# Este script clona (si es necesario), instala y ejecuta el detector
# directamente en macOS para aprovechar CoreML y el Neural Engine.
#
# Uso:
#   ./scripts/start-detector-native.sh
#
# Requisitos:
#   - macOS con Apple Silicon (M1/M2/M3/M4)
#   - Python 3.11+
#   - Conexión a internet (solo la primera vez)
# =============================================================================
set -e

DETECTOR_DIR="apple-silicon-detector"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Clonar si no existe
if [ ! -d "$DETECTOR_DIR" ]; then
    echo "[...] Clonando apple-silicon-detector..."
    git clone https://github.com/frigate-nvr/apple-silicon-detector.git "$DETECTOR_DIR"
fi

cd "$DETECTOR_DIR"

# Instalar si no existe el venv
if [ ! -d "venv" ]; then
    echo "[...] Instalando dependencias del detector..."
    make install
fi

echo ""
echo "============================================="
echo " Apple Silicon Detector (CoreML + Neural Engine)"
echo " Endpoint: tcp://*:5555"
echo "============================================="
echo ""

# Ejecutar el detector
make run
