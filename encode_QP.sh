#!/bin/bash

# ==============================================================================
# SCRIPT COMPARACIÓN POR QP FIJO (Modo Seleccionable)
# Autor: Joseph Jaramillo
# Uso: ./encode_QP.sh [1|2|3]
#      1 = Alta Calidad
#      2 = Media Calidad
#      3 = Baja Calidad

OPCION="${1}"

# Definimos los valores según la opción ingresada
case $OPCION in
    1)
        LABEL="ALTA_CALIDAD"
        QP_H264=16
        QP_VP8=19
        ;;
    2)
        LABEL="MEDIA_CALIDAD"
        QP_H264=29
        QP_VP8=35
        ;;
    3)
        LABEL="BAJA_CALIDAD"
        QP_H264=50
        QP_VP8=61
        ;;
    *)
        echo "ERROR DE USO"
        echo "Debes ingresar un número para seleccionar la calidad:"
        echo "   ./encode_QP.sh 1  -> Alta Calidad  (H264 QP=16 / VP8 QP=19)"
        echo "   ./encode_QP.sh 2  -> Media Calidad (H264 QP=29 / VP8 QP=35)"
        echo "   ./encode_QP.sh 3  -> Baja Calidad  (H264 QP=50 / VP8 QP=61)"
        exit 1
        ;;
esac

VIDEOS=("akiyo_cif.yuv" "coastguard_cif.yuv" "ED_CIF_24fps_cut.yuv")
WIDTH=352
HEIGHT=288
FPS=24
PIXEL_FORMAT="yuv420p"

# El nombre del reporte incluye la calidad seleccionada para no mezclar datos
LOG_FILE="reporte_QP_${LABEL}.txt"

echo "========================================================" > "$LOG_FILE"
echo " REPORTE DE CONSUMO - MODO QP FIJO: $LABEL" >> "$LOG_FILE"
echo " Fecha: $(date)" >> "$LOG_FILE"
echo " Configuración: H.264(QP=$QP_H264) vs VP8(QP=$QP_VP8)" >> "$LOG_FILE"
echo "========================================================" >> "$LOG_FILE"

echo "Configuración seleccionada: $LABEL"
echo "H.264 QP: $QP_H264 | VP8 QP: $QP_VP8"
echo "--------------------------------------------------"

for video in "${VIDEOS[@]}"; do

    if [ ! -f "$video" ]; then
        echo " Error: Archivo $video no encontrado."
        continue
    fi
    
    BASENAME="${video%.yuv}"
    echo "Procesando video: $BASENAME"

    FILE_OUT="${BASENAME}_h264_qp${QP_H264}.mp4"
    FILE_DEC="${BASENAME}_h264_qp${QP_H264}.yuv"

    echo "Codificando a QP $QP_H264..."

    # Log Header
    echo "" >> "$LOG_FILE"
    echo ">>> VIDEO: $BASENAME | CODEC: H.264 | CALIDAD: $LABEL (QP $QP_H264)" >> "$LOG_FILE"
    

    /usr/bin/time -v -a -o "$LOG_FILE" \
    ffmpeg -f rawvideo -pixel_format "$PIXEL_FORMAT" \
           -video_size "${WIDTH}x${HEIGHT}" -framerate "$FPS" \
           -i "$video" \
           -c:v libx264 -qp "$QP_H264" \
           -y "$FILE_OUT" 2> /dev/null

    SIZE=$(du -h "$FILE_OUT" | awk '{print $1}')
    echo "   TAMAÑO_ARCHIVO: $SIZE" >> "$LOG_FILE"
    echo "   -> Generando YUV para PSNR..."
    ffmpeg -i "$FILE_OUT" -f rawvideo -pixel_format "$PIXEL_FORMAT" -y "$FILE_DEC" 2>/dev/null

    FILE_OUT="${BASENAME}_vp8_qp${QP_VP8}.webm" 
    FILE_DEC="${BASENAME}_vp8_qp${QP_VP8}.yuv"

    echo "Codificando a QP $QP_VP8..."

    echo "" >> "$LOG_FILE"
    echo ">>> VIDEO: $BASENAME | CODEC: VP8   | CALIDAD: $LABEL (QP $QP_VP8)" >> "$LOG_FILE"


    /usr/bin/time -v -a -o "$LOG_FILE" \
    ffmpeg -f rawvideo -pixel_format "$PIXEL_FORMAT" \
           -video_size "${WIDTH}x${HEIGHT}" -framerate "$FPS" \
           -i "$video" \
           -c:v libvpx -qmin "$QP_VP8" -qmax "$QP_VP8" -b:v 10M \
           -y "$FILE_OUT" 2> /dev/null


    SIZE=$(du -h "$FILE_OUT" | awk '{print $1}')
    echo "   TAMAÑO_ARCHIVO: $SIZE" >> "$LOG_FILE"
    echo "   -> Generando YUV para PSNR..."
    ffmpeg -i "$FILE_OUT" -f rawvideo -pixel_format "$PIXEL_FORMAT" -y "$FILE_DEC" 2>/dev/null
    echo "--------------------------------------------------"
done

echo "Proceso finalizado para calidad: $LABEL"

