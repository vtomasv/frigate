# Guía de Instalación: Frigate NVR en macOS con Apple Silicon (M3 Max)

Esta guía detalla los pasos para levantar Frigate NVR en un Mac con Apple Silicon, aprovechando el Neural Engine para la detección de objetos y preparando el terreno para la integración con LLMs locales.

## 1. Requisitos Previos

- **Hardware:** Mac con Apple Silicon (M1/M2/M3/M4).
- **Software:**
    - macOS 14 (Sonoma) o superior.
    - [Docker Desktop para Mac](https://www.docker.com/products/docker-desktop/).
    - [Homebrew](https://brew.sh/) para instalar dependencias.
    - Git (instalado con Homebrew: `brew install git`).

## 2. Clonar el Repositorio

Clona tu fork del repositorio de Frigate, que ya contiene los archivos de configuración necesarios.

```bash
git clone https://github.com/vtomasv/frigate.git
cd frigate
```

## 3. Configuración del Detector Nativo (Apple Silicon Detector)

Para lograr el máximo rendimiento, el detector de objetos se ejecuta de forma nativa en macOS, fuera de Docker, para acceder directamente al Neural Engine.

### 3.1. Clonar el Repositorio del Detector

```bash
git clone https://github.com/frigate-nvr/apple-silicon-detector.git
cd apple-silicon-detector
```

### 3.2. Instalar Dependencias y Ejecutar

El proyecto incluye un `Makefile` que simplifica la instalación. Este comando creará un entorno virtual de Python, instalará las dependencias (ONNX Runtime, etc.) y ejecutará el detector.

```bash
make install
make run
```

Al ejecutar `make run`, deberías ver una salida similar a esta, indicando que el detector está escuchando en el puerto 5555:

```
INFO:ZmqOnnxClient:ZMQ ONNX client started, listening on tcp://*:5555
```

**Mantén esta terminal abierta.** El detector debe estar corriendo para que Frigate pueda conectarse a él.

## 4. Preparar el Modelo de Detección

Frigate necesita un modelo de detección de objetos en formato ONNX. Usaremos YOLOv9-t, que está optimizado para Apple Silicon.

1.  **Crear el directorio:**

    ```bash
    cd ../  # Volver al directorio principal de frigate
    mkdir -p config/model_cache
    ```

2.  **Descargar el modelo:**

    ```bash
    wget https://github.com/thomas-gall/frigate-yolov9-models/raw/main/yolov9-t-320.onnx -O config/model_cache/yolo.onnx
    ```

## 5. Levantar Frigate con Docker Compose

Ahora que el detector nativo está corriendo y el modelo está en su lugar, puedes levantar Frigate y MQTT usando el archivo `docker-compose.apple-silicon.yml` proporcionado.

```bash
docker compose -f docker-compose.apple-silicon.yml up -d
```

Este comando descargará las imágenes de Frigate y Mosquitto y las iniciará en segundo plano.

## 6. Verificación

1.  **Verificar los contenedores:**

    ```bash
    docker ps
    ```

    Deberías ver dos contenedores corriendo: `frigate` y `mqtt`.

2.  **Acceder a la interfaz de Frigate:**

    Abre tu navegador y ve a **http://localhost:8971**. Deberías ver la interfaz de Frigate.

3.  **Verificar la detección:**

    - En la interfaz de Frigate, ve a la cámara `test`.
    - Deberías ver el video de prueba `car-stopping.mp4` reproduciéndose en bucle.
    - En la terminal donde corre el `apple-silicon-detector`, deberías ver logs de inferencia cada vez que Frigate envía un frame para su análisis.

## 7. (Opcional) Integración con Ollama

Para habilitar las funciones de GenAI (como descripciones de eventos), puedes usar Ollama.

### Opción A: Ollama Nativo (Recomendado)

1.  Instala y ejecuta [Ollama para macOS](https://ollama.com/download).
2.  Descomenta la sección `genai` en tu archivo `config/config.yml`.
3.  Reinicia el contenedor de Frigate: `docker compose -f docker-compose.apple-silicon.yml restart frigate`.

### Opción B: Ollama en Docker

Si prefieres mantener todo en Docker (con menor rendimiento):

```bash
docker compose -f docker-compose.apple-silicon.yml --profile with-ollama up -d
```

## 8. Próximos Pasos

- **Añadir tus propias cámaras:** Edita el archivo `config/config.yml` para añadir las URLs RTSP de tus cámaras IP, siguiendo el ejemplo de `camara_principal`.
- **Explorar la configuración:** Revisa la [documentación oficial de Frigate](https://docs.frigate.video/configuration/) para personalizar aún más tu instalación (zonas, máscaras, notificaciones, etc.).
