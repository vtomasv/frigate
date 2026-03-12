# Guía de Instalación: Frigate NVR en macOS con Apple Silicon (M3 Max)

Esta guía detalla los pasos para levantar Frigate NVR en un Mac con Apple Silicon, construyendo todos los servicios desde sus fuentes con Docker Compose.

## Arquitectura

El sistema consta de tres servicios orquestados por Docker Compose:

| Servicio | Contenedor | Descripción |
|:---|:---|:---|
| **Frigate NVR** | `frigate` | NVR principal con UI, grabación y detección de objetos. Se construye desde el Dockerfile oficial. |
| **Apple Silicon Detector** | `frigate-detector` | Servidor ZMQ que ejecuta inferencia ONNX Runtime. Se construye desde un Dockerfile personalizado. |
| **Mosquitto MQTT** | `mqtt` | Broker MQTT para comunicación de eventos. Imagen oficial. |

Adicionalmente, **Ollama** corre de forma nativa en macOS (fuera de Docker) para las funciones de GenAI (descripciones de objetos, resúmenes de eventos).

```
┌─────────────────────────────────────────────────────────┐
│  macOS (Apple M3 Max)                                   │
│                                                         │
│  ┌─────────────────┐                                    │
│  │  Ollama (nativo) │ ◄── GenAI: vision + tools         │
│  │  :11434          │                                    │
│  └────────▲─────────┘                                    │
│           │ host.docker.internal                         │
│  ┌────────┼──────────────────────────────────────────┐  │
│  │ Docker │                                          │  │
│  │        │                                          │  │
│  │  ┌─────┴──────┐   ZMQ    ┌──────────────────┐    │  │
│  │  │  Frigate   │ ◄──────► │  Detector (ONNX) │    │  │
│  │  │  :8971     │          │  :5555            │    │  │
│  │  └─────┬──────┘          └──────────────────┘    │  │
│  │        │                                          │  │
│  │  ┌─────▼──────┐                                   │  │
│  │  │  Mosquitto │                                   │  │
│  │  │  :1883     │                                   │  │
│  │  └────────────┘                                   │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## 1. Requisitos Previos

- **Hardware:** Mac con Apple Silicon (M1/M2/M3/M4).
- **Software:**
    - macOS 14 (Sonoma) o superior.
    - [Docker Desktop para Mac](https://www.docker.com/products/docker-desktop/) (con al menos 8 GB de RAM asignados).
    - [Ollama para macOS](https://ollama.com/download) instalado y corriendo.
    - Git.

## 2. Clonar el Repositorio

```bash
git clone https://github.com/vtomasv/frigate.git
cd frigate
git checkout feature/apple-silicon-llm-integration
```

## 3. Preparar el Modelo de Detección

Descarga el modelo YOLOv9-t optimizado para inferencia rápida:

```bash
./scripts/download-model.sh
```

Esto descarga el modelo ONNX en `config/model_cache/yolo.onnx`.

## 4. Preparar Ollama

Asegúrate de que Ollama está corriendo y descarga el modelo de visión:

```bash
# Verificar que Ollama está corriendo
ollama list

# Descargar el modelo de visión (elige uno)
ollama pull llava:13b          # Recomendado: buen balance calidad/velocidad
# ollama pull qwen3-vl:4b      # Alternativa más ligera
# ollama pull llava:34b         # Alternativa más potente (requiere ~24GB RAM)
```

## 5. Levantar Todo con Docker Compose

### Modo 1: Todo en Docker (más simple)

Este modo construye y levanta los tres servicios. El detector usa `CPUExecutionProvider` (ARM64 NEON), que es más lento que el Neural Engine pero no requiere nada fuera de Docker.

```bash
docker compose -f docker-compose.apple-silicon.yml up -d --build
```

El primer build tardará varios minutos (Frigate compila muchas dependencias). Los builds posteriores serán más rápidos gracias al caché de Docker.

### Modo 2: Detector nativo + Frigate en Docker (máximo rendimiento)

Para aprovechar el Neural Engine del M3 Max (~8ms por inferencia vs ~25-40ms en CPU), ejecuta el detector de forma nativa en macOS:

```bash
# Terminal 1: Iniciar el detector nativo
./scripts/start-detector-native.sh

# Terminal 2: Levantar solo Frigate y MQTT
docker compose -f docker-compose.apple-silicon.yml up -d --build frigate mqtt
```

En este modo, edita `config/config.yml` y cambia el endpoint del detector:

```yaml
detectors:
  apple_silicon:
    type: zmq
    endpoint: tcp://host.docker.internal:5555  # Apunta al detector nativo
```

## 6. Verificación

1. **Verificar los contenedores:**

    ```bash
    docker compose -f docker-compose.apple-silicon.yml ps
    ```

    Deberías ver los servicios `frigate`, `frigate-detector` y `mqtt` corriendo.

2. **Acceder a la interfaz de Frigate:**

    Abre tu navegador y ve a **http://localhost:8971**.

3. **Verificar logs:**

    ```bash
    # Logs de Frigate
    docker compose -f docker-compose.apple-silicon.yml logs -f frigate

    # Logs del detector
    docker compose -f docker-compose.apple-silicon.yml logs -f detector
    ```

## 7. Configurar Cámaras IP Reales

Edita `config/config.yml` para añadir tus cámaras. Ejemplo para una cámara RTSP:

```yaml
go2rtc:
  streams:
    camara_entrada:
      - rtsp://usuario:password@192.168.1.100:554/stream1
    camara_entrada_sub:
      - rtsp://usuario:password@192.168.1.100:554/stream2

cameras:
  camara_entrada:
    enabled: true
    ffmpeg:
      inputs:
        - path: rtsp://127.0.0.1:8554/camara_entrada
          input_args: preset-rtsp-restream
          roles:
            - record
        - path: rtsp://127.0.0.1:8554/camara_entrada_sub
          input_args: preset-rtsp-restream
          roles:
            - detect
    detect:
      enabled: true
      width: 640
      height: 480
      fps: 5
    objects:
      track:
        - person
        - car
      genai:
        enabled: true
    review:
      genai:
        enabled: true
    record:
      enabled: true
```

Después de editar, reinicia Frigate:

```bash
docker compose -f docker-compose.apple-silicon.yml restart frigate
```

## 8. Comandos Útiles

| Comando | Descripción |
|:---|:---|
| `docker compose -f docker-compose.apple-silicon.yml up -d --build` | Construir e iniciar todos los servicios |
| `docker compose -f docker-compose.apple-silicon.yml down` | Detener todos los servicios |
| `docker compose -f docker-compose.apple-silicon.yml logs -f` | Ver logs en tiempo real |
| `docker compose -f docker-compose.apple-silicon.yml restart frigate` | Reiniciar solo Frigate |
| `docker compose -f docker-compose.apple-silicon.yml ps` | Ver estado de los servicios |

## 9. Solución de Problemas

**El detector no responde:** Verifica que el contenedor `frigate-detector` está corriendo y revisa sus logs. Si usas el modo nativo, asegúrate de que el script está ejecutándose.

**Ollama no conecta:** Verifica que Ollama está corriendo (`ollama list`) y que el modelo está descargado. Frigate se conecta via `host.docker.internal:11434`.

**Build de Frigate falla:** Asegúrate de tener suficiente espacio en disco (~10 GB) y que Docker Desktop tiene al menos 8 GB de RAM asignados.

**Rendimiento lento en detección:** Considera usar el Modo 2 (detector nativo) para aprovechar el Neural Engine del M3 Max.
