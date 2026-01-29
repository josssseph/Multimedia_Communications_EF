#!/bin/bash

# SCRIPT DE COMPARACIÓN DE RENDIMIENTO: H.264 vs VP8 (Bitrate Fijo)
# Autor: Joseph Jaramillo
# Uso: Bitrate objetivo (./encode_BR.sh 100k)

VIDEOS=("akiyo_cif.yuv" "coastguard_cif.yuv" "ED_CIF_24fps_cut.yuv")


BITRATE="${1:-50k}" 

# Parámetros de resolución CIF
WIDTH=352
HEIGHT=288
FPS=24
PIXEL_FORMAT="yuv420p"

# Nombre del archivo donde guardaremos los resultados detallados
LOG_FILE="reporte_bitrate_${BITRATE}.txt"

# Limpiamos el archivo de reporte previo si existe para empezar de cero
echo "========================================================" > "$LOG_FILE"
echo " REPORTE DE COMPLETO (Bitrate: $BITRATE)" >> "$LOG_FILE"
echo " Fecha de ejecución: $(date)" >> "$LOG_FILE"
echo " Métricas de CPU/RAM y Tamaños de archivo" >> "$LOG_FILE"
echo "========================================================" >> "$LOG_FILE"

echo "Iniciando pruebas... Los resultados se guardarán en: $LOG_FILE"


for video in "${VIDEOS[@]}"; do
    if [ ! -f "$video" ]; then
        echo "El archivo '$video' no existe. Saltando..."
        continue
    fi
    
    # Extracción del nombre sin extensión para nombrar los archivos de salida
    BASENAME="${video%.yuv}"
    
    echo "--------------------------------------------------"
    echo "Procesando video: $BASENAME"

    echo "Codificación H.264 y medición de consumo..."
    
    FILE_OUT="${BASENAME}_h264_${BITRATE}.mp4"
    FILE_DEC="${BASENAME}_h264_${BITRATE}.yuv"
    
    # Encabezado en el log
    echo "" >> "$LOG_FILE"
    echo ">>> VIDEO: $BASENAME | CODEC: H.264 | BITRATE: $BITRATE" >> "$LOG_FILE"
    
    /usr/bin/time -v -a -o "$LOG_FILE" \
    ffmpeg -f rawvideo -pixel_format "$PIXEL_FORMAT" \
           -video_size "${WIDTH}x${HEIGHT}" -framerate "$FPS" \
           -i "$video" \
           -c:v libx264 -b:v "$BITRATE" \
           -y "$FILE_OUT" 2> /dev/null

    # Registrar el tamaño del archivo
    SIZE=$(du -h "$FILE_OUT" | awk '{print $1}')
    echo "   TAMAÑO_ARCHIVO_FINAL: $SIZE" >> "$LOG_FILE"
 
    echo "Decodificando a YUV..."
    ffmpeg -i "$FILE_OUT" \
           -f rawvideo -pixel_format "$PIXEL_FORMAT" \
           -y "$FILE_DEC" 2>/dev/null

    FILE_OUT="${BASENAME}_vp8_${BITRATE}.webm"
    FILE_DEC="${BASENAME}_vp8_${BITRATE}.yuv"
    
    echo "Codificando con VP8 y midiendo consumo..."

    echo "" >> "$LOG_FILE"
    echo ">>> VIDEO: $BASENAME | CODEC: VP8   | BITRATE: $BITRATE" >> "$LOG_FILE"

    /usr/bin/time -v -a -o "$LOG_FILE" \
    ffmpeg -f rawvideo -pixel_format "$PIXEL_FORMAT" \
           -video_size "${WIDTH}x${HEIGHT}" -framerate "$FPS" \
           -i "$video" \
           -c:v libvpx -b:v "$BITRATE" \
           -y "$FILE_OUT" 2> /dev/null


    SIZE=$(du -h "$FILE_OUT" | awk '{print $1}')
    echo "   TAMAÑO_ARCHIVO_FINAL: $SIZE" >> "$LOG_FILE"

    ffmpeg -i "$FILE_OUT" \
           -f rawvideo -pixel_format "$PIXEL_FORMAT" \
           -y "$FILE_DEC" 2>/dev/null

done

echo "========================================="
echo "Proceso finalizado."
echo "========================================="
