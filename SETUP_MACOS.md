# Guía de Instalación: Frigate NVR en macOS con Apple Silicon (M3 Max)

Esta guía detalla los pasos para levantar Frigate NVR en un Mac con Apple Silicon, usando la imagen oficial pre-compilada de Frigate junto con un detector ONNX construido desde fuentes.

## Arquitectura

El sistema consta de tres servicios orquestados por Docker Compose:

| Servicio | Contenedor | Descripción |
|:---|:---|:---|
| **Frigate NVR** | `frigate` | NVR principal. Usa la imagen oficial `stable-standard-arm64`. |
| **Apple Silicon Detector** | `frigate-detector` | Servidor ZMQ con ONNX Runtime. Se construye desde Dockerfile. |
| **Mosquitto MQTT** | `mqtt` | Broker MQTT para comunicación de eventos. Imagen oficial. |

Adicionalmente, **Ollama** corre de forma nativa en macOS (fuera de Docker) para las funciones de GenAI.

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

## 3. Ejecutar el Script de Preparación

El script `setup.sh` descarga el modelo, crea los directorios necesarios y verifica Ollama:

```bash
./scripts/setup.sh
```

## 4. Preparar Ollama

Asegúrate de que Ollama está corriendo y descarga el modelo de visión:

```bash
# Verificar que Ollama está corriendo
ollama list

# Descargar el modelo de visión
ollama pull llava:13b
```

## 5. Levantar Todo con Docker Compose

### Modo 1: Todo en Docker (más simple)

Este modo usa la imagen oficial de Frigate (`stable-standard-arm64`) y construye el detector. El detector usa `CPUExecutionProvider` (ARM64 NEON), que es más lento que el Neural Engine pero no requiere nada fuera de Docker.

```bash
docker compose -f docker-compose.apple-silicon.yml up -d
```

El primer inicio descargará la imagen de Frigate (~2 GB) y construirá el detector. Los inicios posteriores serán instantáneos.

### Modo 2: Detector nativo + Frigate en Docker (máximo rendimiento)

Para aprovechar el Neural Engine del M3 Max (~8ms por inferencia vs ~25-40ms en CPU):

1. Edita `config/config.yml` y cambia el endpoint del detector:

    ```yaml
    detectors:
      apple_silicon:
        type: zmq
        endpoint: tcp://host.docker.internal:5555  # Apunta al detector nativo
    ```

2. Inicia el detector nativo y luego Frigate:

    ```bash
    # Terminal 1: Iniciar el detector nativo
    ./scripts/start-detector-native.sh

    # Terminal 2: Levantar solo Frigate y MQTT (sin el detector Docker)
    docker compose -f docker-compose.apple-silicon.yml up -d frigate mqtt
    ```

## 6. Verificación

1. **Verificar los contenedores:**

    ```bash
    docker compose -f docker-compose.apple-silicon.yml ps
    ```

2. **Acceder a la interfaz de Frigate:**

    Abre tu navegador y ve a **http://localhost:8971**.

3. **Verificar logs:**

    ```bash
    # Logs de Frigate
    docker compose -f docker-compose.apple-silicon.yml logs -f frigate

    # Logs del detector
    docker compose -f docker-compose.apple-silicon.yml logs -f detector
    ```

## 7. Configurar Cámaras IP

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
| `docker compose -f docker-compose.apple-silicon.yml up -d` | Iniciar todos los servicios |
| `docker compose -f docker-compose.apple-silicon.yml down` | Detener todos los servicios |
| `docker compose -f docker-compose.apple-silicon.yml logs -f` | Ver logs en tiempo real |
| `docker compose -f docker-compose.apple-silicon.yml restart frigate` | Reiniciar solo Frigate |
| `docker compose -f docker-compose.apple-silicon.yml ps` | Ver estado de los servicios |

## 9. Solución de Problemas

**El detector no responde:** Verifica que el contenedor `frigate-detector` está corriendo y revisa sus logs. Si usas el modo nativo, asegúrate de que el script está ejecutándose.

**Ollama no conecta:** Verifica que Ollama está corriendo (`ollama list`) y que el modelo está descargado. Frigate se conecta via `host.docker.internal:11434`.

**Rendimiento lento en detección:** Considera usar el Modo 2 (detector nativo) para aprovechar el Neural Engine del M3 Max.

**Frigate no encuentra cámaras:** Asegúrate de haber configurado al menos una cámara habilitada en `config/config.yml` y reinicia el contenedor.
