#!/bin/bash

# ==============================================================================
# SCRIPT DE ANÁLISIS DE BITRATE REAL vs NOMINAL
# ==============================================================================

# Función para obtener el bitrate real en kbps usando ffprobe
get_real_bitrate() {
    local file="$1"
    # -show_entries format=bit_rate: pide el bitrate total del contenedor
    # -v quiet: silencio absoluto salvo el dato
    # -of csv=p=0: formato limpio solo el número
    local bps=$(ffprobe -v quiet -select_streams v:0 -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1 "$file")
    
    # Convertir de bits/s a kbits/s (entero)
    if [ -z "$bps" ] || [ "$bps" == "N/A" ]; then
        echo "0"
    else
        echo $((bps / 1000))
    fi
}

echo "================================================================================"
printf "%-30s | %-8s | %-12s | %-12s | %-10s\n" "VIDEO" "CODEC" "NOMINAL" "REAL (kbps)" "ERROR %"
echo "================================================================================"

# ------------------------------------------------------------------------------
# PARTE 1: VIDEOS CON BITRATE FIJO (Busca patrones como _50k, _100k, etc.)
# ------------------------------------------------------------------------------
echo ">>> ESCENARIO 1: CONTROL POR BITRATE"
echo "--------------------------------------------------------------------------------"

# Buscamos archivos que tengan números seguidos de 'k' (ej: _50k)
find . -maxdepth 1 -type f \( -name "*_h264_*k.mp4" -o -name "*_vp8_*k.webm" \) | sort | while read filepath; do
    
    filename=$(basename "$filepath")
    
    # 1. Extraer nombre base (ej: akiyo_cif)
    # Quitamos todo desde el primer _h264 o _vp8
    base="${filename%%_h264*}"
    base="${base%%_vp8*}"
    
    # 2. Extraer Codec
    if [[ "$filename" == *"h264"* ]]; then codec="H.264"; else codec="VP8  "; fi
    
    # 3. Extraer Nominal (ej: 50k) usando Regex
    if [[ "$filename" =~ _([0-9]+k)\. ]]; then
        nominal_str="${BASH_REMATCH[1]}"       # "50k"
        nominal_val=${nominal_str%k}           # "50"
    else
        nominal_str="???"
        nominal_val=1
    fi

    # 4. Obtener Real
    real_val=$(get_real_bitrate "$filepath")
    
    # 5. Calcular Error (%)
    # Formula: ((Real - Nominal) / Nominal) * 100
    # Usamos awk para decimales porque bash no maneja flotantes bien
    error_pct=$(awk "BEGIN {printf \"%.1f\", (($real_val - $nominal_val) / $nominal_val) * 100}")

    # Imprimir fila
    printf "%-30s | %-8s | %-12s | %-12s | %-10s\n" "$base" "$codec" "$nominal_str" "${real_val}k" "${error_pct}%"

done

echo ""
echo "================================================================================"
printf "%-30s | %-8s | %-12s | %-12s\n" "VIDEO" "CODEC" "CONFIG (QP)" "REAL (kbps)"
echo "================================================================================"

# ------------------------------------------------------------------------------
# PARTE 2: VIDEOS CON QP FIJO (Busca patrones como _qp20, _qp49, etc.)
# ------------------------------------------------------------------------------
echo ">>> ESCENARIO 2: CALIDAD FIJA (QP)"
echo "--------------------------------------------------------------------------------"

# Buscamos archivos que tengan '_qp' en el nombre
find . -maxdepth 1 -type f \( -name "*_h264_*qp*.mp4" -o -name "*_vp8_*qp*.webm" \) | sort | while read filepath; do
    
    filename=$(basename "$filepath")
    
    # 1. Extraer base
    base="${filename%%_h264*}"
    base="${base%%_vp8*}"
    
    # 2. Extraer Codec
    if [[ "$filename" == *"h264"* ]]; then codec="H.264"; else codec="VP8  "; fi
    
    # 3. Extraer QP (ej: qp49)
    if [[ "$filename" =~ _(qp[0-9]+)\. ]]; then
        qp_str="${BASH_REMATCH[1]}" # "qp49"
    else
        qp_str="???"
    fi

    # 4. Obtener Real (Aquí no hay error porque no había nominal)
    real_val=$(get_real_bitrate "$filepath")

    # Imprimir fila
    printf "%-30s | %-8s | %-12s | %-12s\n" "$base" "$codec" "$qp_str" "${real_val}k"

done

echo "================================================================================"
