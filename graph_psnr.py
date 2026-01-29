import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import sys
import os
from scipy import stats

# ==============================================================================
# SCRIPT DE GENERACIÓN DE GRÁFICAS (PSNR H.264 vs VP8)
# Uso: python graficar_resultados.py archivo.csv
# ==============================================================================

def generar_graficas(csv_path):
    # 1. CARGAR DATOS
    if not os.path.exists(csv_path):
        print(f"Error: No se encuentra el archivo {csv_path}")
        return

    print(f"Leyendo datos de: {csv_path} ...")
    df = pd.read_csv(csv_path)

    # LIMPIEZA DE DATOS: Remover filas con inf o nan en PSNR
    df_original_len = len(df)
    df = df[~df['psnr_y'].isin([float('inf'), float('-inf')])]
    df = df[~df['psnr_avg'].isin([float('inf'), float('-inf')])]
    df = df.dropna(subset=['psnr_y', 'psnr_avg'])
    
    if len(df) < df_original_len:
        print(f"⚠️  Se removieron {df_original_len - len(df)} filas con valores inf o nan")
    
    if len(df) == 0:
        print("❌ Error: No hay datos válidos después de la limpieza")
        return

    # 2. DETECTAR MODO (BITRATE O QP)
    # Analizamos las columnas para saber qué estamos graficando
    if 'bitrate' in df.columns:
        modo = 'Bitrate'
        param_col = 'bitrate'
        # Tomamos el valor del primer registro (ej: "50k") para el título
        valor_actual = str(df['bitrate'].iloc[0]) 
    elif 'config_qp' in df.columns:
        modo = 'QP Fijo'
        param_col = 'config_qp'
        # Tomamos el valor (ej: "QP49")
        valor_actual = str(df['config_qp'].iloc[0])
    else:
        print("Error: El CSV no tiene columnas reconocibles ('bitrate' o 'config_qp').")
        return

    # 3. EXTRAER QP DINÁMICAMENTE (para modo QP)
    qp_mapping = {}
    if modo == 'QP Fijo':
        # Extraemos los QP únicos para cada codec
        for codec_name in df['codec'].unique():
            qp_values = df[df['codec'] == codec_name][param_col].unique()
            if len(qp_values) > 0:
                # Extraemos el número del QP (ej: "QP49" -> 49)
                qp_num = ''.join(filter(str.isdigit, str(qp_values[0])))
                qp_mapping[codec_name] = qp_num

    # 3. PREPARAR DATOS PARA SEABORN (Melt)
    # Transformamos la tabla para tener una columna "Métrica" (Y o AVG) y otra "dB"
    # Esto permite que Seaborn agrupe las barras automáticamente.
    df_melted = df.melt(
        id_vars=['video', 'codec', param_col], 
        value_vars=['psnr_y', 'psnr_avg'], 
        var_name='Metrica', 
        value_name='dB'
    )

    # Renombramos las métricas para que se vean bonitas en la leyenda
    df_melted['Metrica'] = df_melted['Metrica'].replace({
        'psnr_y': 'PSNR Y (Luma)', 
        'psnr_avg': 'PSNR Promedio'
    })

    # 4. GENERAR 3 GRÁFICAS (UNA POR VIDEO)
    videos_unicos = df['video'].unique()

    # Configuración de estilo
    sns.set_theme(style="whitegrid")
    
    for vid in videos_unicos:
        plt.figure(figsize=(12, 7))
        
        # Filtramos datos solo para este video
        data_video = df_melted[df_melted['video'] == vid]

        # CREACIÓN DEL GRÁFICO DE BARRAS
        # x = Codec (H264 vs VP8)
        # y = dB
        # hue = Metrica (La barra azul es Y, la naranja es AVG)
        # errorbar='ci' -> Calcula y dibuja el Intervalo de Confianza del 95% automáticamente
        ax = sns.barplot(
            data=data_video,
            x='codec', 
            y='dB', 
            hue='Metrica',
            palette="viridis",
            errorbar=('ci', 95), # Intervalo de confianza del 95%
            capsize=0.1          # Los "taponcitos" de las barras de error
        )

        # Preparar etiquetas del eje X con QP si aplica
        if modo == 'QP Fijo':
            codecs_unicos = sorted(data_video['codec'].unique())
            nuevas_labels = [f"{codec.upper()}\n(QP {qp_mapping.get(codec, '?')})" for codec in codecs_unicos]
            ax.set_xticks(range(len(codecs_unicos)))
            ax.set_xticklabels(nuevas_labels)
            titulo_modo = f"Modo QP Fijo"
        else:
            titulo_modo = f"Modo {modo} {valor_actual}"

        # Etiquetas y Títulos
        plt.title(f"Video: {vid}\nEscenario: {titulo_modo}", fontsize=15, fontweight='bold')
        plt.ylabel("PSNR (dB)", fontsize=12)
        plt.xlabel("Codificador", fontsize=12)
        plt.ylim(0, 60) # Fijamos límite Y para que sean comparables (ajusta si es necesario)
        plt.legend(title="Métrica", loc='upper right')

        # Añadir etiquetas de valor encima de las barras (opcional pero útil)
        for container in ax.containers:
            ax.bar_label(container, fmt='%.2f', padding=3)

        # AGREGAR CUADROS FLOTANTES CON ESTADÍSTICAS (UNO POR CODEC)
        # Preparar datos para mostrar en cuadros separados
        codecs_unicos = sorted(data_video['codec'].unique())
        positions = [(0.02, 0.02), (0.98, 0.02)]  # Esquinas inferiores (izq, der)
        
        for idx, codec_name in enumerate(codecs_unicos):
            stats_text = ""
            
            for metrica_name in ['PSNR Y (Luma)', 'PSNR Promedio']:
                datos_codec_metrica = data_video[
                    (data_video['codec'] == codec_name) & 
                    (data_video['Metrica'] == metrica_name)
                ]['dB'].values
                
                if len(datos_codec_metrica) > 0:
                    promedio = datos_codec_metrica.mean()
                    # Calcular intervalo de confianza del 95%
                    ic = stats.t.interval(0.95, len(datos_codec_metrica)-1, 
                                         loc=promedio, 
                                         scale=stats.sem(datos_codec_metrica))
                    
                    if modo == 'QP Fijo':
                        codec_label = f"{codec_name.upper()} (QP {qp_mapping.get(codec_name, '?')})"
                    else:
                        codec_label = f"{codec_name.upper()}"
                    
                    stats_text += f"{codec_label}\n"
                    stats_text += f"{metrica_name.split('(')[0].strip()}:\n"
                    stats_text += f"  Prom: {promedio:.2f} dB\n"
                    stats_text += f"  IC 95%: [{ic[0]:.2f}, {ic[1]:.2f}]\n\n"
            
            # Mostrar el cuadro en su posición correspondiente
            if idx < len(positions):
                ha = 'left' if idx == 0 else 'right'
                va = 'bottom'
                props = dict(boxstyle='round', facecolor='wheat', alpha=0.85)
                ax.text(positions[idx][0], positions[idx][1], stats_text, 
                        transform=ax.transAxes, fontsize=8.5,
                        verticalalignment=va, horizontalalignment=ha, 
                        bbox=props, family='monospace')

        # Guardar gráfica
        # Nombre archivo: grafico_akiyo_cif_Bitrate_50k.png
        if modo == 'QP Fijo':
            nombre_salida = f"grafico_{vid}_QP.png"
        else:
            nombre_salida = f"grafico_{vid}_{modo}_{valor_actual}.png"
        plt.tight_layout()
        plt.savefig(nombre_salida, dpi=300)
        print(f"Gráfica guardada: {nombre_salida}")
        
        plt.close() # Cerrar figura para liberar memoria

    print("\nProceso finalizado. Revisa las imágenes PNG generadas.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python graficar_resultados.py <archivo.csv>")
    else:
        generar_graficas(sys.argv[1])