import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import re
import sys
import os

# ==============================================================================
# SCRIPT DE ANÁLISIS DE CONSUMO (Parseo de TXT a Gráficas)
# Uso: python graficar_consumo.py reporte.txt
# ==============================================================================

def convertir_tamanio_a_kb(tamanio_str):
    """
    Convierte cadenas como '450K', '1.2M', '500' a Kilobytes (float).
    """
    tamanio_str = tamanio_str.upper().strip()
    multiplicador = 1
    
    if tamanio_str.endswith('K'):
        multiplicador = 1         # KB a KB
        num = tamanio_str[:-1]
    elif tamanio_str.endswith('M'):
        multiplicador = 1024      # MB a KB
        num = tamanio_str[:-1]
    elif tamanio_str.endswith('G'):
        multiplicador = 1024 * 1024  # GB a KB
        num = tamanio_str[:-1]
    else:
        # Asumimos bytes si no tiene unidad, o KB por defecto de du
        num = tamanio_str
        multiplicador = 1 / 1024 

    try:
        return float(num) * multiplicador
    except ValueError:
        return 0.0

def parsear_reporte(filepath):
    data = []
    
    # Variables temporales para mantener el estado mientras leemos línea por línea
    current_video = None
    current_codec = None
    current_time = None
    current_ram = None
    current_size = None
    
    # Expresiones Regulares para cazar los datos
    # Patrón del encabezado: >>> VIDEO: nombre | CODEC: tipo ...
    regex_header = re.compile(r">>> VIDEO: (.*?) \| CODEC: (.*?) \|")
    
    # Patrón de GNU Time
    regex_time = re.compile(r"User time \(seconds\): ([\d\.]+)")
    regex_ram  = re.compile(r"Maximum resident set size \(kbytes\): (\d+)")
    
    # Patrón de Tamaño (acepta con o sin "_FINAL")
    regex_size = re.compile(r"TAMAÑO_ARCHIVO(?:_FINAL)?: ([\w\.]+)")

    print(f"Leyendo archivo: {filepath} ...")
    
    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip()
            
            # 1. Detectar Nuevo Bloque (Header)
            match_header = regex_header.search(line)
            if match_header:
                # Si ya teníamos datos capturados del bloque anterior, los guardamos
                if current_video and current_codec:
                    data.append({
                        'Video': current_video,
                        'Codec': current_codec,
                        'Tiempo CPU (s)': float(current_time) if current_time else 0,
                        'RAM Max (MB)': (float(current_ram) / 1024) if current_ram else 0, # KB a MB
                        'Peso Archivo (KB)': convertir_tamanio_a_kb(current_size) if current_size else 0
                    })
                    # Reiniciamos variables para el nuevo bloque
                    current_time = None
                    current_ram = None
                    current_size = None
                
                current_video = match_header.group(1).strip()
                current_codec = match_header.group(2).strip()
                continue

            # 2. Buscar Métricas dentro del bloque
            match_time = regex_time.search(line)
            if match_time:
                current_time = match_time.group(1)
            
            match_ram = regex_ram.search(line)
            if match_ram:
                current_ram = match_ram.group(1)
                
            match_size = regex_size.search(line)
            if match_size:
                current_size = match_size.group(1)

        # No olvidar guardar el último bloque al terminar el archivo
        if current_video and current_codec:
            data.append({
                'Video': current_video,
                'Codec': current_codec,
                'Tiempo CPU (s)': float(current_time) if current_time else 0,
                'RAM Max (MB)': (float(current_ram) / 1024) if current_ram else 0,
                'Peso Archivo (KB)': convertir_tamanio_a_kb(current_size) if current_size else 0
            })

    return pd.DataFrame(data)

def graficar_metricas(df, nombre_reporte):
    if df.empty:
        print("Error: No se encontraron datos. Revisa el formato del TXT.")
        return

    sns.set_theme(style="whitegrid")
    # Limpiamos el nombre para el archivo de salida
    base_name = os.path.splitext(os.path.basename(nombre_reporte))[0]

    # Definimos las 3 métricas a graficar
    metricas = ['Tiempo CPU (s)', 'RAM Max (MB)', 'Peso Archivo (KB)']
    
    # Creamos una figura con 3 subgráficos (uno debajo del otro)
    fig, axes = plt.subplots(3, 1, figsize=(10, 15))
    
    for i, metrica in enumerate(metricas):
        ax = axes[i]
        
        # Gráfico de Barras Agrupadas
        sns.barplot(
            data=df, 
            x='Video', 
            y=metrica, 
            hue='Codec', 
            palette='viridis',
            ax=ax
        )
        
        ax.set_title(f"Comparativa: {metrica}", fontsize=14, fontweight='bold')
        ax.set_xlabel("")
        ax.legend(title="Códec")
        
        # Etiquetas de valor encima de las barras
        for container in ax.containers:
            ax.bar_label(container, fmt='%.2f', padding=3)

    plt.tight_layout()
    output_img = f"grafica_consumo_{base_name}.png"
    plt.savefig(output_img, dpi=300)
    print(f"Gráfica generada exitosamente: {output_img}")
    plt.close()

    # Opcional: Guardar también el CSV limpio por si lo necesitas luego
    df.to_csv(f"datos_consumo_{base_name}.csv", index=False)
    print(f"Datos extraídos guardados en: datos_consumo_{base_name}.csv")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python graficar_consumo.py <archivo_reporte.txt>")
    else:
        archivo = sys.argv[1]
        if os.path.exists(archivo):
            df_resultados = parsear_reporte(archivo)
            print("\n--- Vista previa de datos extraídos ---")
            print(df_resultados)
            print("---------------------------------------")
            graficar_metricas(df_resultados, archivo)
        else:
            print(f"El archivo {archivo} no existe.")