#!/bin/bash

# ==============================================================================
# SCRIPT DE ANÁLISIS DE CALIDAD (PSNR) - MODO QP
# Genera CSV frame a frame comparando los archivos generados por QP fijo.
# Uso: ./psnr_qp.sh [1|2|3]
# ==============================================================================

OPCION="${1}"

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
        echo "ERROR: Debes ingresar el nivel de calidad."
        echo "   Uso: ./psnr_qp.sh [1|2|3]"
        echo "   1 = Alta, 2 = Media, 3 = Baja"
        exit 1
        ;;
esac


VIDEOS=("akiyo_cif.yuv" "coastguard_cif.yuv" "ED_CIF_24fps_cut.yuv")
WIDTH=352
HEIGHT=288
PIXEL_FORMAT="yuv420p"

CSV_FILE="psnr_frames_QP_${LABEL}.csv"

# Crear cabecera del CSV
echo "video,codec,config_qp,frame,psnr_y,psnr_avg" > "$CSV_FILE"

echo "========================================================"
echo " INICIANDO ANÁLISIS PSNR (MODO QP: $LABEL)"
echo " Archivo de salida: $CSV_FILE"
echo " H.264 QP esperado: $QP_H264 | VP8 QP esperado: $QP_VP8"
echo "========================================================"


for video_orig in "${VIDEOS[@]}"; do

    if [ ! -f "$video_orig" ]; then
        echo "Original no encontrado: $video_orig"
        continue
    fi

    BASENAME="${video_orig%.yuv}"
    echo "--------------------------------------------------"
    echo "Analizando video: $BASENAME"

    # Definimos los códecs a analizar
    CODECS=("h264" "vp8")

    for codec in "${CODECS[@]}"; do
        
        # Aquí determinamos qué número de QP buscar según el códec actual
        if [ "$codec" == "h264" ]; then
            CURRENT_QP=$QP_H264
        else
            CURRENT_QP=$QP_VP8
        fi
        
        # Construir el nombre del archivo YUV decodificado
        # Ejemplo: akiyo_cif_h264_qp49.yuv  O  akiyo_cif_vp8_qp60.yuv
        FILE_PROCESSED="${BASENAME}_${codec}_qp${CURRENT_QP}.yuv"

        if [ ! -f "$FILE_PROCESSED" ]; then
            echo "Archivo procesado no encontrado: $FILE_PROCESSED"
            continue
        fi

        echo "-> Comparando $codec (QP $CURRENT_QP)..."

        # Archivo temporal para guardar los datos frame a frame
        TEMP_STATS="temp_psnr_qp.log"

        # La salida va a TEMP_STATS
        OUTPUT_LOG=$(ffmpeg -s "${WIDTH}x${HEIGHT}" -pix_fmt "$PIXEL_FORMAT" -i "$FILE_PROCESSED" \
               -s "${WIDTH}x${HEIGHT}" -pix_fmt "$PIXEL_FORMAT" -i "$video_orig" \
               -lavfi psnr="stats_file=$TEMP_STATS" -f null - 2>&1)
	
        echo "$FILE_PROCESSED"
	echo "----------------------------"
	echo "$video_orig"
	echo "----------------------------"
	echo "$OUTPUT_LOG" | grep "PSNR y:"
        
        # Pasamos las variables 'codec' y 'CURRENT_QP' al awk para que queden registradas
        awk -v vid="$BASENAME" -v cod="$codec" -v qp="$CURRENT_QP" '
        BEGIN { OFS="," }
        {
            frame=0; py=0; pavg=0;
            
            for(i=1; i<=NF; i++) {
                split($i, arr, ":")
                if (arr[1] == "n") frame = arr[2]
                if (arr[1] == "psnr_y") py = arr[2]
                if (arr[1] == "psnr_avg") pavg = arr[2]
            }
            if (frame > 0) {
                print vid, cod, "QP"qp, frame, py, pavg
            }
        }' "$TEMP_STATS" >> "$CSV_FILE"

        # Limpiar temporal
        rm "$TEMP_STATS"

    done
done

echo "========================================="
echo "Análisis QP terminado."
echo "CSV generado: $CSV_FILE"
echo "========================================="
