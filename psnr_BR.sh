#!/bin/bash

# ==============================================================================
# SCRIPT DE ANÁLISIS DE CALIDAD (PSNR)
# Genera CSV frame a frame y resumen TXT
# Uso ./psnr.sh 50k
# ==============================================================================

BITRATE="${1:-50k}" 

VIDEOS=("akiyo_cif.yuv" "coastguard_cif.yuv" "ED_CIF_24fps_cut.yuv")
WIDTH=352
HEIGHT=288
PIXEL_FORMAT="yuv420p"

CSV_FILE="psnr_data_frames_${BITRATE}.csv"


# Crear cabecera del CSV
echo "video,codec,bitrate,frame,psnr_y,psnr_avg" > "$CSV_FILE"

echo "Iniciando análisis de PSNR..."
echo "Datos Raw: $CSV_FILE"


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
        
        # Construir nombre del archivo procesado (Decodificado a YUV)
        # Ejemplo: akiyo_cif_h264_50k.yuv
        FILE_PROCESSED="${BASENAME}_${codec}_${BITRATE}.yuv"

        if [ ! -f "$FILE_PROCESSED" ]; then
            echo "Archivo procesado no encontrado: $FILE_PROCESSED"
            continue
        fi

        echo "-> Comparando $codec..."

        # Archivo temporal para guardar los datos frame a frame de ffmpeg
        TEMP_STATS="temp_psnr.log"
        # ----------------------------------------------------------------------
        # EJECUTAR FFMPGE PSNR
        # ----------------------------------------------------------------------
        # La salida visual (promedio final) se guarda en OUTPUT_LOG
        # Los datos por frame se escriben en TEMP_STATS
        OUTPUT_LOG=$(ffmpeg -s "${WIDTH}x${HEIGHT}" -pix_fmt "$PIXEL_FORMAT" -i "$FILE_PROCESSED" \
                            -s "${WIDTH}x${HEIGHT}" -pix_fmt "$PIXEL_FORMAT" -i "$video_orig" \
                            -lavfi psnr="stats_file=$TEMP_STATS" -f null - 2>&1)
	echo "$FILE_PROCESSED"
	echo "----------------------------"
	echo "$video_orig"
	echo "----------------------------"
	echo "$OUTPUT_LOG" | grep "PSNR y:"

        # El archivo temp_psnr.log tiene formato: n:1 psnr_y:30.50 psnr_avg:31.00 ...
        # Usamos awk para limpiarlo y convertirlo a CSV
        awk -v vid="$BASENAME" -v cod="$codec" -v br="$BITRATE" '
        BEGIN { OFS="," }
        {
            # Variables temporales
            frame=0; py=0; pavg=0;
            
            # Recorrer cada campo de la línea (ej: "n:1", "psnr_y:30.00")
            for(i=1; i<=NF; i++) {
                split($i, arr, ":") # Separar clave:valor
                if (arr[1] == "n") frame = arr[2]
                if (arr[1] == "psnr_y") py = arr[2]
                if (arr[1] == "psnr_avg") pavg = arr[2]
            }
            # Imprimir solo si encontramos número de frame (evita líneas vacías)
            if (frame > 0) {
                print vid, cod, br, frame, py, pavg
            }
        }' "$TEMP_STATS" >> "$CSV_FILE"

        # Borrar temporal
        rm "$TEMP_STATS"

    done
done

echo "========================================="
echo "Análisis terminado."
echo "- CSV generado: $CSV_FILE"
echo "========================================="
