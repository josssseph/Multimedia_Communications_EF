#!/bin/bash

# SCRIPT SIMPLE PARA REPRODUCIR DOS VIDEOS LADO A LADO
# Autor: Joseph Jaramillo
# Uso: ./watch_comp.sh videoH264.mp4 videoVP8.webm

if [ $# -ne 2 ]; then
    echo "Uso: $0 <video1> <video2>"
    exit 1
fi

VIDEO1="$1"
VIDEO2="$2"

# Obtener dimensiones del primer video
DIM1=$(ffprobe -v error -select_streams v:0 \
        -show_entries stream=width,height \
        -of csv=p=0 "$VIDEO1")
W1=$(echo "$DIM1" | cut -d',' -f1)
H1=$(echo "$DIM1" | cut -d',' -f2)

# Obtener dimensiones del segundo video
DIM2=$(ffprobe -v error -select_streams v:0 \
        -show_entries stream=width,height \
        -of csv=p=0 "$VIDEO2")
W2=$(echo "$DIM2" | cut -d',' -f1)
H2=$(echo "$DIM2" | cut -d',' -f2)

# Calcular posición del segundo video (al lado del primero)
SECOND_X=$((W1 + 100))

echo "Reproduciendo:"
echo "  $(basename "$VIDEO1") (${W1}x${H1}) en posición: 100,100"
echo "  $(basename "$VIDEO2") (${W2}x${H2}) en posición: ${SECOND_X},100"

# Reproducir primer video
ffplay -loglevel error -window_title "$VIDEO1" \
       -x "$W1" -y "$H1" \
       -left 100 -top 100 \
       "$VIDEO1" &
PID1=$!

sleep 0.1

# Reproducir segundo video al lado
ffplay -loglevel error -window_title "$VIDEO2" \
       -x "$W2" -y "$H2" \
       -left "$SECOND_X" -top 100 \
       "$VIDEO2" &
PID2=$!

read -p "Presiona Enter para detener la reproducción..."

kill $PID1 $PID2 2>/dev/null
echo "Reproducción detenida."
