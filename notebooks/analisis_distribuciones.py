"""
ANÁLISIS DE DISTRIBUCIONES Y CALIBRACIÓN AUTOMÁTICA
====================================================

Este script complementa el SQL con análisis estadísticos avanzados:
1. Ajuste de distribuciones conocidas (normal, log-normal, gamma, etc.)
2. Tests de bondad de ajuste
3. Visualizaciones
4. Optimización bayesiana de parámetros
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from scipy import stats
from scipy.optimize import minimize
from google.cloud import bigquery
import warnings
warnings.filterwarnings('ignore')

# ============================================================================
# CONFIGURACIÓN
# ============================================================================

PROJECT_ID = 'mo-advertising-sta'
DATASET_ID = 'ADVERTISING_TEST'

client = bigquery.Client(project=PROJECT_ID)

# ============================================================================
# 1. EXTRACCIÓN DE DATOS
# ============================================================================

def extraer_datos_poc(poc_name):
    """
    Extrae datos de visitas para un POC específico
    """
    query = f"""
    SELECT
        msisdn,
        AVG(tiempo_total_ok_dia) as tiempo_promedio,
        STDDEV(tiempo_total_ok_dia) as tiempo_stddev,
        COUNT(DISTINCT fecha) as dias_visita,
        STDDEV(hora_minima) as stddev_hora_minima,
        AVG(dif_horas) as dif_horas_promedio
    FROM `{PROJECT_ID}.{DATASET_ID}.VISITAS_UBICACION_GEO_TILES_CELIA_ISA_V2`
    WHERE poc = '{poc_name}'
        AND PERIODO = 'CAMPAIGN'
        AND tiempo_total_ok_dia > 0
    GROUP BY msisdn
    """

    df = client.query(query).to_dataframe()
    return df


# ============================================================================
# 2. ANÁLISIS DE DISTRIBUCIONES
# ============================================================================

class AnalizadorDistribuciones:
    """
    Analiza y ajusta diferentes distribuciones probabilísticas a los datos
    """

    def __init__(self, data, variable_name='tiempo_promedio'):
        self.data = data[variable_name].dropna()
        self.variable_name = variable_name
        self.resultados = {}

    def test_normalidad(self):
        """
        Tests de normalidad: Shapiro-Wilk, Kolmogorov-Smirnov
        """
        # Shapiro-Wilk (mejor para n < 5000)
        if len(self.data) < 5000:
            stat_sw, p_sw = stats.shapiro(self.data)
            print(f"Shapiro-Wilk test: statistic={stat_sw:.4f}, p-value={p_sw:.4f}")
            if p_sw > 0.05:
                print("  → No se rechaza normalidad (p > 0.05)")
            else:
                print("  → Se rechaza normalidad (p < 0.05)")

        # Kolmogorov-Smirnov
        stat_ks, p_ks = stats.kstest(self.data, 'norm',
                                       args=(self.data.mean(), self.data.std()))
        print(f"\nKolmogorov-Smirnov test: statistic={stat_ks:.4f}, p-value={p_ks:.4f}")

        return {'shapiro_p': p_sw if len(self.data) < 5000 else None,
                'ks_p': p_ks}

    def calcular_momentos(self):
        """
        Calcula momentos estadísticos: media, varianza, skewness, kurtosis
        """
        media = self.data.mean()
        std = self.data.std()
        skewness = stats.skew(self.data)
        kurtosis = stats.kurtosis(self.data)

        print(f"\n=== Momentos de {self.variable_name} ===")
        print(f"Media: {media:.2f}")
        print(f"Desviación estándar: {std:.2f}")
        print(f"Coeficiente de variación: {std/media:.2f}")
        print(f"Skewness: {skewness:.2f}")
        print(f"Kurtosis (excess): {kurtosis:.2f}")

        # Interpretación
        if abs(skewness) < 0.5:
            print("  → Distribución aproximadamente simétrica")
        elif skewness > 0:
            print("  → Distribución asimétrica a la derecha (cola larga derecha)")
        else:
            print("  → Distribución asimétrica a la izquierda (cola larga izquierda)")

        if kurtosis < 0:
            print("  → Colas ligeras (platykurtic)")
        elif kurtosis > 0:
            print("  → Colas pesadas (leptokurtic)")

        return {
            'media': media,
            'std': std,
            'cv': std/media,
            'skewness': skewness,
            'kurtosis': kurtosis
        }

    def ajustar_distribuciones(self):
        """
        Ajusta múltiples distribuciones y compara bondad de ajuste
        """
        distribuciones = {
            'Normal': stats.norm,
            'Log-Normal': stats.lognorm,
            'Gamma': stats.gamma,
            'Exponencial': stats.expon,
            'Weibull': stats.weibull_min
        }

        resultados = {}

        print(f"\n=== Ajustando distribuciones a {self.variable_name} ===")

        for nombre, dist in distribuciones.items():
            try:
                # Ajustar parámetros (MLE)
                params = dist.fit(self.data)

                # Test de Kolmogorov-Smirnov
                stat_ks, p_ks = stats.kstest(self.data, nombre.lower().replace('-', ''),
                                               args=params)

                # AIC/BIC
                log_likelihood = np.sum(dist.logpdf(self.data, *params))
                k = len(params)  # Número de parámetros
                n = len(self.data)
                aic = 2*k - 2*log_likelihood
                bic = k*np.log(n) - 2*log_likelihood

                resultados[nombre] = {
                    'params': params,
                    'ks_stat': stat_ks,
                    'ks_p': p_ks,
                    'aic': aic,
                    'bic': bic,
                    'log_likelihood': log_likelihood
                }

                print(f"\n{nombre}:")
                print(f"  Parámetros: {params}")
                print(f"  KS p-value: {p_ks:.4f}")
                print(f"  AIC: {aic:.2f}")
                print(f"  BIC: {bic:.2f}")

            except Exception as e:
                print(f"\n{nombre}: Error al ajustar - {e}")

        # Mejor ajuste (menor BIC)
        mejor = min(resultados.items(), key=lambda x: x[1]['bic'])
        print(f"\n✅ Mejor ajuste (BIC): {mejor[0]}")

        self.resultados = resultados
        return resultados

    def calcular_percentiles_teoricos(self, distribucion='lognorm'):
        """
        Calcula percentiles teóricos de la distribución ajustada
        """
        if distribucion not in self.resultados:
            raise ValueError(f"Distribución {distribucion} no ajustada")

        params = self.resultados[distribucion]['params']
        dist = getattr(stats, distribucion.lower().replace('-', ''))

        percentiles = [5, 25, 50, 75, 95]
        valores = [dist.ppf(p/100, *params) for p in percentiles]

        print(f"\n=== Percentiles teóricos ({distribucion}) ===")
        for p, v in zip(percentiles, valores):
            print(f"P{p:02d}: {v:.2f}")

        return dict(zip([f'p{p:02d}' for p in percentiles], valores))

    def visualizar(self, distribuciones_a_plotear=['Normal', 'Log-Normal', 'Gamma']):
        """
        Visualiza histograma + distribuciones ajustadas
        """
        fig, axes = plt.subplots(2, 2, figsize=(14, 10))

        # Histograma + Distribuciones
        ax1 = axes[0, 0]
        ax1.hist(self.data, bins=50, density=True, alpha=0.6, color='skyblue',
                 edgecolor='black', label='Datos')

        x = np.linspace(self.data.min(), self.data.max(), 1000)
        for nombre in distribuciones_a_plotear:
            if nombre in self.resultados:
                params = self.resultados[nombre]['params']
                dist = getattr(stats, nombre.lower().replace('-', ''))
                y = dist.pdf(x, *params)
                ax1.plot(x, y, label=nombre, linewidth=2)

        ax1.set_xlabel(self.variable_name)
        ax1.set_ylabel('Densidad')
        ax1.set_title('Histograma + Distribuciones Ajustadas')
        ax1.legend()
        ax1.grid(alpha=0.3)

        # Q-Q Plot (vs Normal)
        ax2 = axes[0, 1]
        stats.probplot(self.data, dist='norm', plot=ax2)
        ax2.set_title('Q-Q Plot (vs Normal)')
        ax2.grid(alpha=0.3)

        # Boxplot
        ax3 = axes[1, 0]
        ax3.boxplot(self.data, vert=True)
        ax3.set_ylabel(self.variable_name)
        ax3.set_title('Boxplot')
        ax3.grid(alpha=0.3)

        # Comparación BIC
        ax4 = axes[1, 1]
        nombres = list(self.resultados.keys())
        bics = [self.resultados[n]['bic'] for n in nombres]
        colores = ['green' if bic == min(bics) else 'gray' for bic in bics]
        ax4.barh(nombres, bics, color=colores)
        ax4.set_xlabel('BIC (menor es mejor)')
        ax4.set_title('Comparación de Ajuste (BIC)')
        ax4.grid(alpha=0.3, axis='x')

        plt.tight_layout()
        return fig

    def recomendar_parametros(self):
        """
        Recomienda parámetros del modelo basándose en la distribución
        """
        mejor_dist = min(self.resultados.items(), key=lambda x: x[1]['bic'])[0]

        if mejor_dist in ['Log-Normal', 'Gamma']:
            # Distribuciones asimétricas → usar percentiles
            params = self.calcular_percentiles_teoricos(mejor_dist.lower().replace('-', ''))

            print(f"\n=== Parámetros Recomendados (basados en {mejor_dist}) ===")
            print(f"tiempo_min_valido:  {params['p05']:.0f} segundos ({params['p05']/60:.1f} min)")
            print(f"tiempo_optimo_min:  {params['p25']:.0f} segundos ({params['p25']/60:.1f} min)")
            print(f"tiempo_optimo_max:  {params['p75']:.0f} segundos ({params['p75']/60:.1f} min)")
            print(f"tiempo_max_valido:  {params['p95']:.0f} segundos ({params['p95']/60:.1f} min)")

            return {
                'tiempo_min_valido': int(params['p05']),
                'tiempo_optimo_min': int(params['p25']),
                'tiempo_optimo_max': int(params['p75']),
                'tiempo_max_valido': int(params['p95']),
                'distribucion': mejor_dist
            }

        elif mejor_dist == 'Normal':
            # Distribución simétrica → usar media ± stddevs
            media = self.data.mean()
            std = self.data.std()

            print(f"\n=== Parámetros Recomendados (basados en Normal) ===")
            print(f"tiempo_min_valido:  {media - 2*std:.0f} segundos (μ - 2σ)")
            print(f"tiempo_optimo_min:  {media - 0.5*std:.0f} segundos (μ - 0.5σ)")
            print(f"tiempo_optimo_max:  {media + 0.5*std:.0f} segundos (μ + 0.5σ)")
            print(f"tiempo_max_valido:  {media + 2*std:.0f} segundos (μ + 2σ)")

            return {
                'tiempo_min_valido': int(media - 2*std),
                'tiempo_optimo_min': int(media - 0.5*std),
                'tiempo_optimo_max': int(media + 0.5*std),
                'tiempo_max_valido': int(media + 2*std),
                'distribucion': mejor_dist
            }


# ============================================================================
# 3. OPTIMIZACIÓN BAYESIANA DE PESOS
# ============================================================================

class OptimizadorPesos:
    """
    Optimiza pesos del modelo usando Optimización Bayesiana
    Requiere: ground truth o métrica proxy
    """

    def __init__(self, data, ground_truth=None):
        self.data = data
        self.ground_truth = ground_truth

    def calcular_probabilidad(self, pesos):
        """
        Calcula probabilidad final con pesos dados
        """
        peso_esp, peso_temp, peso_pat = pesos

        # Normalizar pesos
        suma = peso_esp + peso_temp + peso_pat
        peso_esp /= suma
        peso_temp /= suma
        peso_pat /= suma

        # Calcular probabilidad ponderada
        prob = (peso_esp * self.data['comp_espacial'] +
                peso_temp * self.data['comp_temporal'] +
                peso_pat * self.data['comp_patron'])

        return prob

    def funcion_objetivo(self, pesos):
        """
        Función a minimizar (depende de la métrica objetivo)
        """
        prob = self.calcular_probabilidad(pesos)

        if self.ground_truth is not None:
            # Si tenemos ground truth: maximizar accuracy/F1
            predicciones = (prob >= 0.12).astype(int)
            accuracy = (predicciones == self.ground_truth).mean()
            return -accuracy  # Negativo porque minimize busca mínimo
        else:
            # Sin ground truth: usar proxy (ej: minimizar varianza dentro de clusters)
            # O maximizar separación entre visitantes probables y descartados
            # Proxy simple: maximizar spread de probabilidades
            return -prob.std()  # Queremos alta varianza (separación clara)

    def optimizar(self, metodo='Nelder-Mead'):
        """
        Optimiza pesos usando scipy.optimize
        """
        # Pesos iniciales (equitativo)
        pesos_inicial = [0.33, 0.33, 0.34]

        # Restricción: pesos > 0 y suman ~1
        bounds = [(0.1, 0.6), (0.1, 0.6), (0.1, 0.6)]

        print("Optimizando pesos...")
        resultado = minimize(
            self.funcion_objetivo,
            pesos_inicial,
            method=metodo,
            bounds=bounds
        )

        # Normalizar resultado
        pesos_opt = resultado.x / resultado.x.sum()

        print(f"\n=== Pesos Optimizados ===")
        print(f"Espacial: {pesos_opt[0]:.3f}")
        print(f"Temporal: {pesos_opt[1]:.3f}")
        print(f"Patrón:   {pesos_opt[2]:.3f}")
        print(f"Métrica final: {-resultado.fun:.4f}")

        return pesos_opt

    def grid_search(self, step=0.05):
        """
        Grid search exhaustivo (más lento pero garantiza global optimo)
        """
        mejor_pesos = None
        mejor_metrica = -np.inf

        resultados = []

        # Generar grid
        for peso_esp in np.arange(0.1, 0.6, step):
            for peso_temp in np.arange(0.1, 0.6, step):
                peso_pat = 1.0 - peso_esp - peso_temp

                if peso_pat < 0.1 or peso_pat > 0.6:
                    continue

                pesos = [peso_esp, peso_temp, peso_pat]
                metrica = -self.funcion_objetivo(pesos)

                resultados.append({
                    'peso_espacial': peso_esp,
                    'peso_temporal': peso_temp,
                    'peso_patron': peso_pat,
                    'metrica': metrica
                })

                if metrica > mejor_metrica:
                    mejor_metrica = metrica
                    mejor_pesos = pesos

        df_resultados = pd.DataFrame(resultados)

        print(f"\n=== Grid Search (step={step}) ===")
        print(f"Total combinaciones: {len(df_resultados)}")
        print(f"\nMejores pesos:")
        print(f"Espacial: {mejor_pesos[0]:.3f}")
        print(f"Temporal: {mejor_pesos[1]:.3f}")
        print(f"Patrón:   {mejor_pesos[2]:.3f}")
        print(f"Métrica: {mejor_metrica:.4f}")

        # Visualizar heatmap
        self._plot_grid_search(df_resultados)

        return mejor_pesos, df_resultados

    def _plot_grid_search(self, df_resultados):
        """
        Visualiza resultados del grid search
        """
        fig, axes = plt.subplots(1, 3, figsize=(18, 5))

        # Peso Espacial vs Temporal
        pivot1 = df_resultados.pivot_table(
            values='metrica',
            index='peso_espacial',
            columns='peso_temporal',
            aggfunc='mean'
        )
        sns.heatmap(pivot1, ax=axes[0], cmap='viridis', cbar_kws={'label': 'Métrica'})
        axes[0].set_title('Espacial vs Temporal')

        # Peso Espacial vs Patrón
        pivot2 = df_resultados.pivot_table(
            values='metrica',
            index='peso_espacial',
            columns='peso_patron',
            aggfunc='mean'
        )
        sns.heatmap(pivot2, ax=axes[1], cmap='viridis', cbar_kws={'label': 'Métrica'})
        axes[1].set_title('Espacial vs Patrón')

        # Peso Temporal vs Patrón
        pivot3 = df_resultados.pivot_table(
            values='metrica',
            index='peso_temporal',
            columns='peso_patron',
            aggfunc='mean'
        )
        sns.heatmap(pivot3, ax=axes[2], cmap='viridis', cbar_kws={'label': 'Métrica'})
        axes[2].set_title('Temporal vs Patrón')

        plt.tight_layout()
        return fig


# ============================================================================
# 4. PIPELINE COMPLETO
# ============================================================================

def pipeline_calibracion_automatica(poc_name, visualizar=True):
    """
    Pipeline completo de calibración automática
    """
    print(f"{'='*80}")
    print(f"CALIBRACIÓN AUTOMÁTICA PARA POC: {poc_name}")
    print(f"{'='*80}\n")

    # 1. Extraer datos
    print("1. Extrayendo datos de BigQuery...")
    df = extraer_datos_poc(poc_name)
    print(f"   Usuarios: {len(df)}")

    # 2. Analizar distribución de tiempo
    print("\n2. Analizando distribución de tiempos...")
    analizador_tiempo = AnalizadorDistribuciones(df, 'tiempo_promedio')

    momentos = analizador_tiempo.calcular_momentos()
    normalidad = analizador_tiempo.test_normalidad()
    distribuciones = analizador_tiempo.ajustar_distribuciones()
    parametros_tiempo = analizador_tiempo.recomendar_parametros()

    if visualizar:
        fig1 = analizador_tiempo.visualizar()
        plt.savefig(f'distribucion_tiempo_{poc_name}.png', dpi=150, bbox_inches='tight')
        plt.show()

    # 3. Analizar distribución de frecuencia
    print("\n3. Analizando distribución de frecuencia...")
    analizador_freq = AnalizadorDistribuciones(df, 'dias_visita')

    momentos_freq = analizador_freq.calcular_momentos()
    distribuciones_freq = analizador_freq.ajustar_distribuciones()
    parametros_freq = analizador_freq.recomendar_parametros()

    if visualizar:
        fig2 = analizador_freq.visualizar()
        plt.savefig(f'distribucion_frecuencia_{poc_name}.png', dpi=150, bbox_inches='tight')
        plt.show()

    # 4. Generar configuración final
    print("\n4. Generando configuración final...")

    config = {
        'tipo_poc': poc_name,
        'metodo_calibracion': 'AUTO_DISTRIBUCION',
        'fecha_calibracion': pd.Timestamp.now(),

        # Tiempo (de distribución ajustada)
        'tiempo_min_valido': parametros_tiempo['tiempo_min_valido'],
        'tiempo_optimo_min': parametros_tiempo['tiempo_optimo_min'],
        'tiempo_optimo_max': parametros_tiempo['tiempo_optimo_max'],
        'tiempo_max_valido': parametros_tiempo['tiempo_max_valido'],
        'tiempo_distribucion': parametros_tiempo['distribucion'],

        # Frecuencia (de distribución ajustada)
        'dias_min_valido': 0,
        'dias_optimo_min': 1,
        'dias_optimo_max': parametros_freq['tiempo_optimo_max'] // 60,  # Convertir a días
        'dias_max_valido': parametros_freq['tiempo_max_valido'] // 60,
        'dias_distribucion': parametros_freq['distribucion'],

        # Patrón (basado en quartiles de stddev_hora)
        'stddev_trabajador_max': df['stddev_hora_minima'].quantile(0.25),
        'stddev_visitante_min': df['stddev_hora_minima'].quantile(0.75),

        # Pesos (default balanceado, optimizar después si hay ground truth)
        'peso_espacial': 0.30,
        'peso_temporal': 0.40,
        'peso_patron': 0.30,

        # Metadata
        'n_usuarios': len(df),
        'tiempo_cv': momentos['cv'],
        'tiempo_skewness': momentos['skewness'],
        'dias_cv': momentos_freq['cv'],
        'dias_skewness': momentos_freq['skewness']
    }

    # Mostrar configuración
    print("\n" + "="*80)
    print("CONFIGURACIÓN GENERADA")
    print("="*80)
    for key, value in config.items():
        if isinstance(value, float):
            print(f"{key:30s}: {value:.2f}")
        else:
            print(f"{key:30s}: {value}")

    return config, df


# ============================================================================
# 5. EJEMPLO DE USO
# ============================================================================

if __name__ == '__main__':

    # Ejemplo 1: Calibración básica
    poc_ejemplo = 'NORGES_SEAFOOD-SALMON_AGO26'
    config, df = pipeline_calibracion_automatica(poc_ejemplo, visualizar=True)

    # Ejemplo 2: Optimización de pesos (si tienes componentes calculados)
    """
    # Cargar resultados del modelo
    query = '''
    SELECT
        msisdn,
        comp_espacial,
        comp_temporal,
        comp_patron
    FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_FINALES_V2`
    WHERE tipo_poc = 'SUPERMERCADO'
    '''
    df_resultados = client.query(query).to_dataframe()

    # Optimizar pesos
    optimizador = OptimizadorPesos(df_resultados)
    pesos_optimizados = optimizador.optimizar()

    # O grid search exhaustivo
    pesos_grid, resultados_grid = optimizador.grid_search(step=0.05)
    """

    print("\n✅ Pipeline completado!")
