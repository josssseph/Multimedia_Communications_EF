# Comparativa de Rendimiento y Calidad: H.264 vs VP8

Este repositorio contiene el conjunto de herramientas de automatización desarrolladas en **Bash** y **Python** para realizar un análisis comparativo técnico entre los estándares de codificación de video **H.264 (AVC)** y **VP8**.

El proyecto se centra en medir la eficiencia computacional, el consumo de memoria y la calidad objetiva (PSNR) bajo dos escenarios experimentales: **Bitrate Constante** y **Parámetro de Cuantización (QP) Fijo**.

## 📋 Requisitos Previos

Para ejecutar los scripts es necesario contar con un entorno Linux (Ubuntu/Debian recomendado) con las siguientes herramientas instaladas:

### Sistema y Librerías de Video
* **FFmpeg** (con soporte para `libx264` y `libvpx`).
* **GNU Time** (paquete `time`, usualmente instalado en `/usr/bin/time`).
* **Python 3.12.3**.
Además de instlar en un ambiente virtual, las librerías incluidas en requirements.txt

Instalación en Ubuntu:
```bash
sudo apt update
sudo apt install ffmpeg python3-pip time
python -m venv EF_ev
EF_venv/bin/activate
pip install -r requirements.txt

