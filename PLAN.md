# Plan de Extensión para Frigate: Soporte Apple Silicon y Pipelines de Video con LLM

## 1. Visión General

Este documento describe el plan para extender Frigate NVR, añadiendo soporte optimizado para hardware Apple Silicon (M3 Max) y nuevas capacidades de procesamiento de video mediante modelos de lenguaje grandes (LLM) con soporte multimodal. El objetivo es crear un sistema que no solo detecte objetos en tiempo real, sino que también comprenda y genere resúmenes de la actividad en los videos, aprovechando la potencia del hardware local.

## 2. Arquitectura Propuesta

La solución se basará en una arquitectura híbrida que combina el contenedor de Frigate con un detector nativo de macOS y un pipeline de procesamiento de video con LLM.

```mermaid
graph TD
    subgraph macOS Nativo
        A[Detector Apple Silicon] -->|CoreML/ANE| B(Neural Engine)
        C[LLM Multimodal (Ollama/MLX)] -->|Metal| D(GPU)
    end

    subgraph Contenedor Frigate (Linux)
        E[Frigate Core] -->|ZMQ| A
        E --> F{Pipeline de Video}
        F -->|API| C
        G[Cámaras IP] -->|RTSP| E
    end

    F --> H[Base de Datos]
    C --> H
```

| Componente | Descripción |
| :--- | :--- |
| **Frigate Core** | Contenedor principal de Frigate, gestiona cámaras, grabaciones y eventos. |
| **Detector Apple Silicon** | Proceso nativo en macOS que recibe imágenes de Frigate vía ZMQ y realiza la detección de objetos usando el Neural Engine para máxima eficiencia. |
| **LLM Multimodal** | Un modelo de lenguaje local (ej. LLaVA, Qwen2-VL) corriendo en macOS a través de Ollama o directamente con MLX para analizar secuencias de video. |
| **Pipeline de Video** | Nuevo módulo en Frigate que orquesta la extracción de fotogramas clave de un evento y los envía al LLM para su análisis. |

## 3. Fases del Proyecto

### Fase 1: Configuración del Entorno y Soporte de Hardware

El objetivo de esta fase es establecer un entorno de desarrollo funcional en el Mac M3 Max y validar la integración del detector de Apple Silicon.

1.  **Crear una rama de desarrollo:** Se creará la rama `feature/apple-silicon-llm-integration` para aislar los cambios.
2.  **Documentar el entorno de desarrollo:** Se creará un `README.md` específico para el desarrollo en macOS, detallando la instalación de dependencias (Python, Docker/Apple Container, etc.) y la configuración del proyecto.
3.  **Integrar `apple-silicon-detector`:** Se clonará y configurará el repositorio `frigate-nvr/apple-silicon-detector` para que funcione en conjunto con el fork de Frigate.
4.  **Validar la detección de objetos:** Se realizarán pruebas para confirmar que la detección de objetos se está acelerando correctamente a través del Neural Engine.

### Fase 2: Diseño del Pipeline de Procesamiento de Video con LLM

Esta fase se centra en el diseño de la nueva funcionalidad de análisis de video.

1.  **Definir el nuevo pipeline en `data_processing`:** Se creará un nuevo subdirectorio en `frigate/data_processing/` para el análisis de video con LLM. Este pipeline se activará después de que un evento de grabación haya finalizado.
2.  **Diseñar la lógica de extracción de fotogramas:** Se definirá una estrategia para seleccionar los fotogramas más representativos de un clip de video (ej. uno cada N segundos, o basado en la detección de movimiento).
3.  **Definir la API de comunicación con el LLM:** Se diseñará la interfaz para enviar los fotogramas al LLM y recibir el análisis. Se considerará el uso de la API de Ollama o una integración más directa con MLX.
4.  **Diseñar el esquema de la base de datos:** Se extenderá el modelo de datos de Frigate para almacenar los resultados del análisis del LLM, como resúmenes de texto, etiquetas de actividad, etc.

### Fase 3: Implementación y Pruebas

En esta fase se escribirá el código para el nuevo pipeline de video.

1.  **Implementar el extractor de fotogramas:** Se desarrollará un script en Python que utilice OpenCV o FFmpeg para extraer los fotogramas de los clips de video guardados por Frigate.
2.  **Implementar el cliente del LLM:** Se creará un cliente para interactuar con el LLM multimodal, enviando los fotogramas y procesando las respuestas.
3.  **Integrar el pipeline en Frigate:** Se modificará el código de Frigate para invocar el nuevo pipeline de análisis de video cuando corresponda.
4.  **Desarrollar pruebas unitarias y de integración:** Se crearán pruebas para validar cada componente del nuevo pipeline y su correcta integración con el resto del sistema.

### Fase 4: Documentación y Entrega

La última fase consiste en documentar la nueva funcionalidad y preparar el código para su posible contribución al proyecto principal.

1.  **Actualizar la documentación de Frigate:** Se añadirá una nueva sección a la documentación oficial explicando cómo configurar y utilizar el pipeline de análisis de video con LLM.
2.  **Crear un Pull Request:** Se creará un Pull Request al repositorio fork con todos los cambios, incluyendo el código, las pruebas y la documentación.
3.  **Generar un informe final:** Se entregará un informe resumiendo el trabajo realizado, los resultados obtenidos y las posibles futuras mejoras.
