-- ============================================================================
-- CALIBRACIÓN AUTOMÁTICA DE PARÁMETROS
-- ============================================================================
--
-- ESTRATEGIAS para configurar parámetros sin ajustarlos a mano:
--
-- 1. ESTADÍSTICAS DESCRIPTIVAS (básico, rápido)
--    - Calcular percentiles de tiempo/frecuencia
--    - Derivar parámetros automáticamente
--
-- 2. ANÁLISIS DE DISTRIBUCIONES (intermedio)
--    - Ajustar distribuciones conocidas (normal, log-normal, gamma)
--    - Usar parámetros de la distribución
--
-- 3. CLUSTERING AUTOMÁTICO (avanzado)
--    - Descubrir "tipos" de POC sin clasificarlos a mano
--    - K-means, DBSCAN sobre features temporales
--
-- 4. OPTIMIZACIÓN BAYESIANA (muy avanzado)
--    - Optimizar parámetros para maximizar métrica objetivo
--    - Requiere ground truth o proxy metric
--
-- ============================================================================


-- ============================================================================
-- ESTRATEGIA 1: CALIBRACIÓN POR PERCENTILES (BÁSICA)
-- ============================================================================
-- Idea: Los parámetros "óptimos" son los percentiles típicos
-- Ventaja: Simple, interpretable, funciona sin labels
-- Desventaja: No detecta trabajadores automáticamente

-- ============================================================================
-- 1.1 Calcular Estadísticas Base por POC
-- ============================================================================

CREATE OR REPLACE TABLE `mo-advertising-sta.ADVERTISING_TEST.ESTADISTICAS_BASE_POC` AS
WITH visitas_agregadas AS (
  SELECT
    poc,
    msisdn,
    id_ubicacion,

    -- Estadísticas temporales (promedios por usuario)
    AVG(tiempo_total_ok_dia) as tiempo_promedio,
    STDDEV(tiempo_total_ok_dia) as tiempo_stddev,
    MIN(tiempo_total_ok_dia) as tiempo_min,
    MAX(tiempo_total_ok_dia) as tiempo_max,

    -- Frecuencia
    COUNT(DISTINCT fecha) as dias_visita,

    -- Patrón horario
    STDDEV(hora_minima) as stddev_hora_minima,
    STDDEV(hora_maxima) as stddev_hora_maxima,
    AVG(dif_horas) as dif_horas_promedio

  FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_UBICACION_GEO_TILES_CELIA_ISA_V2`
  WHERE PERIODO = 'CAMPAIGN'
    AND tiempo_total_ok_dia > 0
  GROUP BY poc, msisdn, id_ubicacion
)

SELECT
  poc,
  COUNT(DISTINCT msisdn) as n_usuarios,

  -- ========================================================================
  -- PERCENTILES DE TIEMPO (en segundos)
  -- ========================================================================
  APPROX_QUANTILES(tiempo_promedio, 100)[OFFSET(5)] as tiempo_p05,    -- 5%
  APPROX_QUANTILES(tiempo_promedio, 100)[OFFSET(25)] as tiempo_p25,   -- 25%
  APPROX_QUANTILES(tiempo_promedio, 100)[OFFSET(50)] as tiempo_p50,   -- Mediana
  APPROX_QUANTILES(tiempo_promedio, 100)[OFFSET(75)] as tiempo_p75,   -- 75%
  APPROX_QUANTILES(tiempo_promedio, 100)[OFFSET(95)] as tiempo_p95,   -- 95%

  -- Estadísticas de tiempo
  AVG(tiempo_promedio) as tiempo_media,
  STDDEV(tiempo_promedio) as tiempo_stddev_poblacion,

  -- ========================================================================
  -- PERCENTILES DE FRECUENCIA (días)
  -- ========================================================================
  APPROX_QUANTILES(dias_visita, 100)[OFFSET(5)] as dias_p05,
  APPROX_QUANTILES(dias_visita, 100)[OFFSET(25)] as dias_p25,
  APPROX_QUANTILES(dias_visita, 100)[OFFSET(50)] as dias_p50,
  APPROX_QUANTILES(dias_visita, 100)[OFFSET(75)] as dias_p75,
  APPROX_QUANTILES(dias_visita, 100)[OFFSET(95)] as dias_p95,

  AVG(dias_visita) as dias_media,
  STDDEV(dias_visita) as dias_stddev_poblacion,

  -- ========================================================================
  -- PATRÓN HORARIO (para detectar trabajadores)
  -- ========================================================================
  APPROX_QUANTILES(stddev_hora_minima, 100)[OFFSET(25)] as stddev_hora_p25,
  APPROX_QUANTILES(stddev_hora_minima, 100)[OFFSET(50)] as stddev_hora_p50,
  APPROX_QUANTILES(stddev_hora_minima, 100)[OFFSET(75)] as stddev_hora_p75,

  AVG(stddev_hora_minima) as stddev_hora_media,

  -- Dif horas promedio
  AVG(dif_horas_promedio) as dif_horas_media_poblacion

FROM visitas_agregadas
GROUP BY poc;


-- ============================================================================
-- 1.2 Derivar Parámetros Automáticamente
-- ============================================================================
-- REGLAS HEURÍSTICAS basadas en percentiles:
--
-- tiempo_min_valido = p05 (5% más bajo)
-- tiempo_optimo_min = p25 (cuartil inferior)
-- tiempo_optimo_max = p75 (cuartil superior)
-- tiempo_max_valido = p95 (5% más alto)
--
-- dias_optimo_min = 1 (siempre)
-- dias_optimo_max = p75 (cuartil superior)
-- dias_max_valido = p95 (detección trabajadores)
--
-- stddev_trabajador_max = p25 (25% más consistente = trabajador)
-- stddev_visitante_min = p75 (75% más variable = visitante)

CREATE OR REPLACE TABLE `mo-advertising-sta.ADVERTISING_TEST.PARAMETROS_AUTOMATICOS` AS
SELECT
  poc,
  n_usuarios,

  -- ========================================================================
  -- PARÁMETROS DE TIEMPO (derivados de percentiles)
  -- ========================================================================
  CAST(tiempo_p05 AS INT64) as tiempo_min_valido,
  CAST(tiempo_p25 AS INT64) as tiempo_optimo_min,
  CAST(tiempo_p75 AS INT64) as tiempo_optimo_max,
  CAST(tiempo_p95 AS INT64) as tiempo_max_valido,

  -- ========================================================================
  -- PARÁMETROS DE FRECUENCIA
  -- ========================================================================
  0 as dias_min_valido,                           -- Siempre 0
  1 as dias_optimo_min,                           -- Siempre 1
  CAST(dias_p75 AS INT64) as dias_optimo_max,    -- Cuartil superior
  CAST(dias_p95 AS INT64) as dias_max_valido,    -- p95 = trabajadores

  -- ========================================================================
  -- PARÁMETROS DE PATRÓN (detección trabajadores)
  -- ========================================================================
  stddev_hora_p25 as stddev_trabajador_max,      -- p25 = patrón fijo
  stddev_hora_p75 as stddev_visitante_min,       -- p75 = patrón variable

  -- dif_horas: usar 6.0 como default (jornada laboral típica)
  -- Podría ser dif_horas_media + 1*stddev
  6.0 as dif_horas_trabajador_min,

  -- pct_fuera_horario_max: default conservador
  50.0 as pct_fuera_horario_max,

  -- ========================================================================
  -- RATIOS (heurísticos basados en strictness)
  -- ========================================================================
  -- Si dias_p95 es alto → muchos trabajadores → ratio más permisivo
  CASE
    WHEN dias_p95 > 15 THEN 0.50  -- Alto riesgo trabajadores
    WHEN dias_p95 > 10 THEN 0.60  -- Riesgo medio
    ELSE 0.75                      -- Bajo riesgo
  END as ratio_minimo,

  CASE
    WHEN dias_p95 > 15 THEN 0.75
    WHEN dias_p95 > 10 THEN 0.85
    ELSE 0.90
  END as ratio_optimo,

  -- ========================================================================
  -- UMBRALES (basados en dispersión de los datos)
  -- ========================================================================
  -- Si stddev es baja → datos concentrados → umbrales más altos
  -- Si stddev es alta → datos dispersos → umbrales más bajos

  CASE
    WHEN tiempo_stddev_poblacion / NULLIF(tiempo_media, 0) < 0.5 THEN 0.20  -- CV bajo
    WHEN tiempo_stddev_poblacion / NULLIF(tiempo_media, 0) < 1.0 THEN 0.15
    ELSE 0.12                                                                 -- CV alto
  END as umbral_muy_probable,

  CASE
    WHEN tiempo_stddev_poblacion / NULLIF(tiempo_media, 0) < 0.5 THEN 0.15
    WHEN tiempo_stddev_poblacion / NULLIF(tiempo_media, 0) < 1.0 THEN 0.12
    ELSE 0.08
  END as umbral_probable,

  -- ========================================================================
  -- PESOS (basados en riesgo de trabajadores)
  -- ========================================================================
  -- Si muchos trabajadores (dias_p95 alto) → más peso en patrón

  CASE
    WHEN dias_p95 > 15 THEN 0.20  -- Alto riesgo → poco peso espacial
    WHEN dias_p95 > 10 THEN 0.25
    ELSE 0.30
  END as peso_espacial,

  CASE
    WHEN dias_p95 > 15 THEN 0.30  -- Alto riesgo → menos peso temporal
    WHEN dias_p95 > 10 THEN 0.35
    ELSE 0.40
  END as peso_temporal,

  CASE
    WHEN dias_p95 > 15 THEN 0.50  -- Alto riesgo → MUCHO peso patrón
    WHEN dias_p95 > 10 THEN 0.40
    ELSE 0.30
  END as peso_patron,

  -- Metadata
  'AUTO_PERCENTILES' as metodo_calibracion,
  CURRENT_TIMESTAMP() as fecha_calibracion

FROM `mo-advertising-sta.ADVERTISING_TEST.ESTADISTICAS_BASE_POC`;


-- ============================================================================
-- 1.3 Validar Parámetros Automáticos
-- ============================================================================

SELECT
  poc,
  n_usuarios,

  -- Tiempos (en minutos para legibilidad)
  ROUND(tiempo_min_valido / 60, 1) as tiempo_min_min,
  ROUND(tiempo_optimo_min / 60, 1) as tiempo_opt_min_min,
  ROUND(tiempo_optimo_max / 60, 1) as tiempo_opt_max_min,
  ROUND(tiempo_max_valido / 60, 1) as tiempo_max_min,

  -- Frecuencia
  dias_optimo_max,
  dias_max_valido,

  -- Patrón
  ROUND(stddev_trabajador_max, 2) as stddev_trab_max,
  ROUND(stddev_visitante_min, 2) as stddev_visit_min,

  -- Ratios
  ROUND(ratio_minimo, 2) as ratio_min,
  ROUND(ratio_optimo, 2) as ratio_opt,

  -- Pesos
  ROUND(peso_espacial, 2) as peso_esp,
  ROUND(peso_temporal, 2) as peso_temp,
  ROUND(peso_patron, 2) as peso_pat,

  -- Validación: pesos suman 1.0
  ROUND(peso_espacial + peso_temporal + peso_patron, 3) as suma_pesos

FROM `mo-advertising-sta.ADVERTISING_TEST.PARAMETROS_AUTOMATICOS`
ORDER BY n_usuarios DESC;


-- ============================================================================
-- ESTRATEGIA 2: ANÁLISIS DE DISTRIBUCIONES
-- ============================================================================
-- Idea: Ajustar distribuciones probabilísticas a los datos
-- Ventaja: Principled, captura toda la distribución
-- Desventaja: BigQuery no tiene fitting nativo, hay que estimar

-- ============================================================================
-- 2.1 Test de Normalidad (Skewness y Kurtosis)
-- ============================================================================

CREATE OR REPLACE TABLE `mo-advertising-sta.ADVERTISING_TEST.ANALISIS_DISTRIBUCIONES` AS
WITH visitas_agregadas AS (
  SELECT
    poc,
    msisdn,
    AVG(tiempo_total_ok_dia) as tiempo_promedio,
    COUNT(DISTINCT fecha) as dias_visita
  FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_UBICACION_GEO_TILES_CELIA_ISA_V2`
  WHERE PERIODO = 'CAMPAIGN' AND tiempo_total_ok_dia > 0
  GROUP BY poc, msisdn
),

momentos AS (
  SELECT
    poc,

    -- Momentos de tiempo
    AVG(tiempo_promedio) as tiempo_mean,
    STDDEV(tiempo_promedio) as tiempo_std,

    -- Skewness (asimetría)
    -- skew = E[(X-μ)³] / σ³
    AVG(POW((tiempo_promedio - AVG(tiempo_promedio) OVER(PARTITION BY poc)) /
            STDDEV(tiempo_promedio) OVER(PARTITION BY poc), 3)) as tiempo_skewness,

    -- Kurtosis (cola pesada)
    -- kurt = E[(X-μ)⁴] / σ⁴
    AVG(POW((tiempo_promedio - AVG(tiempo_promedio) OVER(PARTITION BY poc)) /
            STDDEV(tiempo_promedio) OVER(PARTITION BY poc), 4)) as tiempo_kurtosis,

    -- Momentos de frecuencia
    AVG(dias_visita) as dias_mean,
    STDDEV(dias_visita) as dias_std,

    AVG(POW((dias_visita - AVG(dias_visita) OVER(PARTITION BY poc)) /
            STDDEV(dias_visita) OVER(PARTITION BY poc), 3)) as dias_skewness,

    AVG(POW((dias_visita - AVG(dias_visita) OVER(PARTITION BY poc)) /
            STDDEV(dias_visita) OVER(PARTITION BY poc), 4)) as dias_kurtosis

  FROM visitas_agregadas
  GROUP BY poc
)

SELECT
  poc,

  -- Tiempo
  ROUND(tiempo_mean, 0) as tiempo_media,
  ROUND(tiempo_std, 0) as tiempo_stddev,
  ROUND(tiempo_skewness, 2) as tiempo_skewness,
  ROUND(tiempo_kurtosis, 2) as tiempo_kurtosis,

  -- Interpretación de skewness
  CASE
    WHEN ABS(tiempo_skewness) < 0.5 THEN 'Simétrica (Normal-like)'
    WHEN tiempo_skewness > 0.5 THEN 'Asimétrica derecha (Log-Normal-like)'
    WHEN tiempo_skewness < -0.5 THEN 'Asimétrica izquierda'
  END as tiempo_distribucion_sugerida,

  -- Días
  ROUND(dias_mean, 1) as dias_media,
  ROUND(dias_std, 1) as dias_stddev,
  ROUND(dias_skewness, 2) as dias_skewness,
  ROUND(dias_kurtosis, 2) as dias_kurtosis,

  CASE
    WHEN dias_skewness > 1.0 THEN 'Poisson o Gamma (eventos raros)'
    WHEN ABS(dias_skewness) < 0.5 THEN 'Normal'
    ELSE 'Log-Normal'
  END as dias_distribucion_sugerida

FROM momentos;

-- Interpretación:
-- - skewness ≈ 0, kurtosis ≈ 3 → Normal
-- - skewness > 0 (cola derecha) → Log-Normal, Gamma
-- - skewness < 0 (cola izquierda) → Beta
-- - kurtosis > 3 → Colas pesadas


-- ============================================================================
-- 2.2 Parámetros basados en Log-Normal (común en tiempos de visita)
-- ============================================================================
-- Si tiempo sigue Log-Normal(μ, σ²):
-- - log(tiempo) ~ Normal(μ, σ²)
-- - E[tiempo] = exp(μ + σ²/2)
-- - Var[tiempo] = exp(2μ + σ²) * (exp(σ²) - 1)

CREATE OR REPLACE TABLE `mo-advertising-sta.ADVERTISING_TEST.PARAMETROS_LOGNORMAL` AS
WITH datos_log AS (
  SELECT
    poc,
    msisdn,
    AVG(tiempo_total_ok_dia) as tiempo_promedio,
    LN(AVG(tiempo_total_ok_dia)) as log_tiempo  -- Log natural
  FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_UBICACION_GEO_TILES_CELIA_ISA_V2`
  WHERE PERIODO = 'CAMPAIGN' AND tiempo_total_ok_dia > 0
  GROUP BY poc, msisdn
)

SELECT
  poc,

  -- Parámetros de log-normal
  AVG(log_tiempo) as mu,                    -- μ (media del log)
  STDDEV(log_tiempo) as sigma,              -- σ (stddev del log)

  -- Reconstruir momentos de la distribución original
  EXP(AVG(log_tiempo) + POW(STDDEV(log_tiempo), 2) / 2) as tiempo_esperado,

  -- Percentiles de log-normal
  -- p_α = exp(μ + σ * z_α)  donde z_α es el percentil de N(0,1)

  EXP(AVG(log_tiempo) + STDDEV(log_tiempo) * (-1.645)) as tiempo_p05,  -- z_0.05 ≈ -1.645
  EXP(AVG(log_tiempo) + STDDEV(log_tiempo) * (-0.674)) as tiempo_p25,  -- z_0.25 ≈ -0.674
  EXP(AVG(log_tiempo) + STDDEV(log_tiempo) * 0.0) as tiempo_p50,       -- z_0.50 = 0
  EXP(AVG(log_tiempo) + STDDEV(log_tiempo) * 0.674) as tiempo_p75,     -- z_0.75 ≈ 0.674
  EXP(AVG(log_tiempo) + STDDEV(log_tiempo) * 1.645) as tiempo_p95,     -- z_0.95 ≈ 1.645

  'LOGNORMAL_FIT' as metodo

FROM datos_log
GROUP BY poc;

-- Uso: Estos percentiles son más "suaves" que los empíricos
-- Útil cuando tienes pocos datos o outliers


-- ============================================================================
-- ESTRATEGIA 3: CLUSTERING AUTOMÁTICO (Descubrir tipos de POC)
-- ============================================================================
-- Idea: No clasificar POCs a mano, dejar que el algoritmo los agrupe
-- Ventaja: Descubre patrones no obvios
-- Desventaja: Requiere interpretar clusters

-- ============================================================================
-- 3.1 Preparar Features para Clustering
-- ============================================================================

CREATE OR REPLACE TABLE `mo-advertising-sta.ADVERTISING_TEST.FEATURES_CLUSTERING` AS
WITH visitas_agg AS (
  SELECT
    poc,
    msisdn,
    AVG(tiempo_total_ok_dia) as tiempo_promedio,
    STDDEV(tiempo_total_ok_dia) as tiempo_stddev,
    COUNT(DISTINCT fecha) as dias_visita,
    STDDEV(hora_minima) as stddev_hora_minima,
    AVG(dif_horas) as dif_horas_promedio
  FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_UBICACION_GEO_TILES_CELIA_ISA_V2`
  WHERE PERIODO = 'CAMPAIGN' AND tiempo_total_ok_dia > 0
  GROUP BY poc, msisdn
)

SELECT
  poc,

  -- Features normalizadas (z-score para clustering)
  -- Feature 1: Tiempo promedio (normalizado)
  (AVG(tiempo_promedio) - AVG(AVG(tiempo_promedio)) OVER()) /
    STDDEV(AVG(tiempo_promedio)) OVER() as tiempo_promedio_z,

  -- Feature 2: Frecuencia (normalizado)
  (AVG(dias_visita) - AVG(AVG(dias_visita)) OVER()) /
    STDDEV(AVG(dias_visita)) OVER() as dias_visita_z,

  -- Feature 3: Variabilidad horaria (normalizado)
  (AVG(stddev_hora_minima) - AVG(AVG(stddev_hora_minima)) OVER()) /
    STDDEV(AVG(stddev_hora_minima)) OVER() as stddev_hora_z,

  -- Feature 4: Duración jornadas (normalizado)
  (AVG(dif_horas_promedio) - AVG(AVG(dif_horas_promedio)) OVER()) /
    STDDEV(AVG(dif_horas_promedio)) OVER() as dif_horas_z,

  -- Features originales (para interpretación)
  ROUND(AVG(tiempo_promedio) / 60, 1) as tiempo_promedio_min,
  ROUND(AVG(dias_visita), 1) as dias_visita_promedio,
  ROUND(AVG(stddev_hora_minima), 2) as stddev_hora_promedio,
  ROUND(AVG(dif_horas_promedio), 1) as dif_horas_promedio_real

FROM visitas_agg
GROUP BY poc;

-- ============================================================================
-- 3.2 K-Means Clustering (BigQuery ML)
-- ============================================================================
-- Necesitarías BigQuery ML para esto. Pseudocódigo:

/*
CREATE OR REPLACE MODEL `mo-advertising-sta.ADVERTISING_TEST.modelo_kmeans`
OPTIONS(
  model_type='kmeans',
  num_clusters=3,  -- Probar 3-5 clusters
  standardize_features=TRUE
) AS
SELECT
  tiempo_promedio_z,
  dias_visita_z,
  stddev_hora_z,
  dif_horas_z
FROM `mo-advertising-sta.ADVERTISING_TEST.FEATURES_CLUSTERING`;

-- Predecir cluster para cada POC
CREATE OR REPLACE TABLE `mo-advertising-sta.ADVERTISING_TEST.POC_CLUSTERS` AS
SELECT
  f.poc,
  p.CENTROID_ID as cluster,
  f.tiempo_promedio_min,
  f.dias_visita_promedio,
  f.stddev_hora_promedio
FROM ML.PREDICT(
  MODEL `mo-advertising-sta.ADVERTISING_TEST.modelo_kmeans`,
  TABLE `mo-advertising-sta.ADVERTISING_TEST.FEATURES_CLUSTERING`
) p
JOIN `mo-advertising-sta.ADVERTISING_TEST.FEATURES_CLUSTERING` f
  ON p.poc = f.poc;

-- Interpretar clusters
SELECT
  cluster,
  COUNT(*) as n_pocs,
  ROUND(AVG(tiempo_promedio_min), 1) as tiempo_promedio,
  ROUND(AVG(dias_visita_promedio), 1) as dias_promedio,
  ROUND(AVG(stddev_hora_promedio), 2) as stddev_hora,

  -- Interpretación automática
  CASE
    WHEN AVG(dias_visita_promedio) > 10 AND AVG(stddev_hora_promedio) < 2
      THEN 'ALTO_RIESGO_TRABAJADORES'
    WHEN AVG(tiempo_promedio_min) > 60 AND AVG(dias_visita_promedio) < 5
      THEN 'VISITAS_LARGAS_INFRECUENTES'
    WHEN AVG(tiempo_promedio_min) < 30 AND AVG(dias_visita_promedio) > 5
      THEN 'VISITAS_CORTAS_FRECUENTES'
    ELSE 'MIXTO'
  END as interpretacion
FROM `mo-advertising-sta.ADVERTISING_TEST.POC_CLUSTERS`
GROUP BY cluster;
*/


-- ============================================================================
-- ESTRATEGIA 4: OPTIMIZACIÓN BAYESIANA
-- ============================================================================
-- Idea: Optimizar parámetros para maximizar métrica objetivo
-- Requiere: Ground truth o proxy metric (ej: concordancia con validación manual)

-- ============================================================================
-- 4.1 Grid Search Simple (sin Bayesian Optimization)
-- ============================================================================
-- Probar diferentes combinaciones de pesos y medir resultado

-- Pseudocódigo (BigQuery no soporta loops, usar script/Python):

/*
DECLARE pesos_a_probar ARRAY<STRUCT<esp FLOAT64, temp FLOAT64, pat FLOAT64>>;
SET pesos_a_probar = [
  STRUCT(0.2 as esp, 0.3 as temp, 0.5 as pat),
  STRUCT(0.25 as esp, 0.35 as temp, 0.4 as pat),
  STRUCT(0.3 as esp, 0.4 as temp, 0.3 as pat),
  -- ... más combinaciones
];

-- Para cada combinación:
FOR peso IN pesos_a_probar DO
  -- Ejecutar modelo con estos pesos
  -- Calcular métrica (ej: # visitas muy probables, coherencia con validación)
  -- Guardar resultado
END FOR;

-- Elegir combinación con mejor métrica
*/


-- ============================================================================
-- ESTRATEGIA 5: SEMI-SUPERVISADO (Híbrido datos + reglas)
-- ============================================================================
-- Idea: Empezar con parámetros automáticos + ajustar con feedback humano

CREATE OR REPLACE TABLE `mo-advertising-sta.ADVERTISING_TEST.PARAMETROS_HIBRIDOS` AS
SELECT
  a.poc,

  -- Parámetros base (automáticos)
  a.tiempo_min_valido,
  a.tiempo_optimo_min,
  a.tiempo_optimo_max,
  a.tiempo_max_valido,
  a.dias_optimo_max,
  a.dias_max_valido,

  -- AJUSTES MANUALES (override cuando necesario)
  -- Ej: Si sabes que este POC tiene horario especial
  CASE
    WHEN a.poc LIKE '%BANCO%' THEN 14.0  -- Bancos cierran a las 2pm
    WHEN a.poc LIKE '%24H%' THEN 24.0    -- 24 horas
    ELSE NULL  -- Usa lo que haya en datos
  END as hora_cierre_override,

  -- Ajustes basados en conocimiento del negocio
  CASE
    WHEN a.poc LIKE '%CONCESIONARIO%' THEN 0.25  -- Más peso patrón (detectar vendedores)
    WHEN a.poc LIKE '%SUPERMERCADO%' THEN 0.50   -- Mucho peso patrón (cajeros)
    ELSE a.peso_patron                            -- Usa automático
  END as peso_patron_ajustado,

  'HIBRIDO_AUTO_MANUAL' as metodo

FROM `mo-advertising-sta.ADVERTISING_TEST.PARAMETROS_AUTOMATICOS` a;


-- ============================================================================
-- COMPARACIÓN DE MÉTODOS
-- ============================================================================

SELECT
  'PERCENTILES' as metodo,
  COUNT(DISTINCT poc) as n_pocs_calibrados,
  AVG(peso_espacial + peso_temporal + peso_patron) as validacion_pesos_suma,
  'Rápido, interpretable, sin labels' as ventajas,
  'No detecta trabajadores automáticamente' as desventajas
FROM `mo-advertising-sta.ADVERTISING_TEST.PARAMETROS_AUTOMATICOS`

UNION ALL

SELECT
  'LOGNORMAL',
  COUNT(DISTINCT poc),
  NULL,
  'Suaviza outliers, principled',
  'Asume distribución, puede no ajustar bien'
FROM `mo-advertising-sta.ADVERTISING_TEST.PARAMETROS_LOGNORMAL`

UNION ALL

SELECT
  'CLUSTERING',
  NULL,
  NULL,
  'Descubre tipos no obvios, no requiere clasificación manual',
  'Requiere interpretar clusters, necesita BigQuery ML'

UNION ALL

SELECT
  'OPTIMIZACION',
  NULL,
  NULL,
  'Maximiza métrica objetivo, óptimo matemáticamente',
  'Requiere ground truth o proxy metric, lento'

UNION ALL

SELECT
  'HIBRIDO',
  COUNT(DISTINCT poc),
  NULL,
  'Combina datos + conocimiento negocio, flexible',
  'Requiere input manual selectivo'
FROM `mo-advertising-sta.ADVERTISING_TEST.PARAMETROS_HIBRIDOS`;


-- ============================================================================
-- RECOMENDACIÓN DE USO
-- ============================================================================
/*

PARA EMPEZAR (esta semana):
  → Usa ESTRATEGIA 1 (Percentiles)
  → Rápido, funciona sin labels
  → Genera parámetros base razonables

SIGUIENTE PASO (1-2 semanas):
  → Añade ESTRATEGIA 2 (Análisis Distribuciones)
  → Entiende mejor tus datos
  → Ajusta parámetros basándote en distribución real

SI TIENES GROUND TRUTH (1 mes):
  → Usa ESTRATEGIA 4 (Optimización)
  → Grid search sobre pesos
  → Maximiza accuracy/precision/recall

SI TIENES MUCHOS POCS (2-3 meses):
  → Usa ESTRATEGIA 3 (Clustering)
  → Descubre tipos automáticamente
  → Reduce a 3-5 perfiles base

SIEMPRE:
  → Combina con ESTRATEGIA 5 (Híbrido)
  → Override manual cuando sabes algo del negocio
  → Mejora iterativa

*/


-- ============================================================================
-- PRÓXIMOS PASOS
-- ============================================================================

-- TODO: Implementar en Python/R para más flexibilidad
-- TODO: Añadir test de bondad de ajuste (Kolmogorov-Smirnov, Chi-cuadrado)
-- TODO: Optimización Bayesiana con librería (Optuna, Hyperopt)
-- TODO: Dashboard de monitoreo de parámetros
-- TODO: A/B testing automático de configuraciones
