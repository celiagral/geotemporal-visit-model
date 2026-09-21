-- ============================================================================
-- COMPARACIÓN DE MODELOS: PIECEWISE vs DISTRIBUCIONES
-- ============================================================================
-- Este script compara los resultados de ambos enfoques lado a lado

-- PREREQUISITOS:
-- 1. Ejecutar 03_MODELO.sql (modelo piecewise)
-- 2. Ejecutar 05_FUNCIONES_DISTRIBUCION_CORREGIDAS.sql (modelo con distribuciones)

-- ============================================================================
-- PASO 1: CREAR TABLA DE USUARIOS AGREGADOS (si no existe)
-- ============================================================================

CREATE OR REPLACE TEMP TABLE USUARIOS_AGREGADOS AS
SELECT
  msisdn,
  id_ubicacion,
  poc,

  -- Promedios de tiempos
  AVG(tiempo_total_ok_dia) as tiempo_ok_promedio,
  AVG(tiempo_total_no_ok_dia) as tiempo_no_ok_promedio,
  AVG(dif_horas) as dif_horas_promedio,

  -- Frecuencia
  COUNT(DISTINCT fecha) as dias_visita,

  -- Prob espacial promedio
  AVG(PROBABILIDAD_VISITA_OK) as prob_espacial_promedio,

  -- Variabilidad horaria
  STDDEV(hora_minima) as stddev_hora_minima,
  STDDEV(hora_maxima) as stddev_hora_maxima,
  AVG(hora_minima) as hora_minima_promedio,
  AVG(hora_maxima) as hora_maxima_promedio,

  -- Flags
  MAX(CASE WHEN hora_minima < 10 THEN TRUE ELSE FALSE END) as llega_antes_abrir,
  MAX(CASE WHEN hora_maxima > 20 THEN TRUE ELSE FALSE END) as sale_despues_cerrar,

  -- Tipo POC
  'CONCESIONARIO' as tipo_poc

FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_UBICACION_GEO_TILES_CELIA_ISA_V2`
WHERE poc = 'VOLVO_XC40-AON_ABR2026_4'
  AND PERIODO = 'CAMPAIGN'
  AND tiempo_total_ok_dia > 0
GROUP BY msisdn, id_ubicacion, poc;


-- ============================================================================
-- PASO 2: APLICAR AMBOS MODELOS
-- ============================================================================

CREATE OR REPLACE TEMP TABLE COMPARACION_MODELOS AS
SELECT
  msisdn,
  id_ubicacion,

  -- Variables base
  tiempo_ok_promedio,
  tiempo_no_ok_promedio,
  dias_visita,
  SAFE_DIVIDE(tiempo_ok_promedio, tiempo_ok_promedio + tiempo_no_ok_promedio) as ratio_horario,
  stddev_hora_minima,
  prob_espacial_promedio,

  -- =========================================================================
  -- MODELO 1: PIECEWISE (03_MODELO.sql)
  -- =========================================================================
  `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_visita`(
    prob_espacial_promedio,
    CAST(tiempo_ok_promedio AS INT64),
    CAST(tiempo_no_ok_promedio AS INT64),
    dias_visita,
    stddev_hora_minima,
    stddev_hora_maxima,
    dif_horas_promedio,
    llega_antes_abrir,
    sale_despues_cerrar,
    tipo_poc
  ) as prob_piecewise,

  -- =========================================================================
  -- MODELO 2: DISTRIBUCIONES (05_FUNCIONES_DISTRIBUCION_CORREGIDAS.sql)
  -- =========================================================================
  `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_visita_con_dist`(
    prob_espacial_promedio,
    tiempo_ok_promedio / 60.0,  -- convertir a minutos
    dias_visita,
    SAFE_DIVIDE(tiempo_ok_promedio, tiempo_ok_promedio + tiempo_no_ok_promedio),
    stddev_hora_minima,
    tipo_poc
  ) as prob_distribucion,

  -- Clasificaciones
  CASE
    WHEN `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_visita`(
      prob_espacial_promedio, CAST(tiempo_ok_promedio AS INT64),
      CAST(tiempo_no_ok_promedio AS INT64), dias_visita,
      stddev_hora_minima, stddev_hora_maxima, dif_horas_promedio,
      llega_antes_abrir, sale_despues_cerrar, tipo_poc
    ) >= 0.20 THEN 'VISITA_MUY_PROBABLE'
    WHEN `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_visita`(
      prob_espacial_promedio, CAST(tiempo_ok_promedio AS INT64),
      CAST(tiempo_no_ok_promedio AS INT64), dias_visita,
      stddev_hora_minima, stddev_hora_maxima, dif_horas_promedio,
      llega_antes_abrir, sale_despues_cerrar, tipo_poc
    ) >= 0.15 THEN 'VISITA_PROBABLE'
    WHEN `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_visita`(
      prob_espacial_promedio, CAST(tiempo_ok_promedio AS INT64),
      CAST(tiempo_no_ok_promedio AS INT64), dias_visita,
      stddev_hora_minima, stddev_hora_maxima, dif_horas_promedio,
      llega_antes_abrir, sale_despues_cerrar, tipo_poc
    ) >= 0.10 THEN 'VISITA_POSIBLE'
    WHEN `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_visita`(
      prob_espacial_promedio, CAST(tiempo_ok_promedio AS INT64),
      CAST(tiempo_no_ok_promedio AS INT64), dias_visita,
      stddev_hora_minima, stddev_hora_maxima, dif_horas_promedio,
      llega_antes_abrir, sale_despues_cerrar, tipo_poc
    ) >= 0.05 THEN 'DUDOSO'
    ELSE 'DESCARTADO'
  END as clasificacion_piecewise,

  CASE
    WHEN `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_visita_con_dist`(
      prob_espacial_promedio, tiempo_ok_promedio / 60.0, dias_visita,
      SAFE_DIVIDE(tiempo_ok_promedio, tiempo_ok_promedio + tiempo_no_ok_promedio),
      stddev_hora_minima, tipo_poc
    ) >= 0.20 THEN 'VISITA_MUY_PROBABLE'
    WHEN `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_visita_con_dist`(
      prob_espacial_promedio, tiempo_ok_promedio / 60.0, dias_visita,
      SAFE_DIVIDE(tiempo_ok_promedio, tiempo_ok_promedio + tiempo_no_ok_promedio),
      stddev_hora_minima, tipo_poc
    ) >= 0.15 THEN 'VISITA_PROBABLE'
    WHEN `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_visita_con_dist`(
      prob_espacial_promedio, tiempo_ok_promedio / 60.0, dias_visita,
      SAFE_DIVIDE(tiempo_ok_promedio, tiempo_ok_promedio + tiempo_no_ok_promedio),
      stddev_hora_minima, tipo_poc
    ) >= 0.10 THEN 'VISITA_POSIBLE'
    WHEN `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_visita_con_dist`(
      prob_espacial_promedio, tiempo_ok_promedio / 60.0, dias_visita,
      SAFE_DIVIDE(tiempo_ok_promedio, tiempo_ok_promedio + tiempo_no_ok_promedio),
      stddev_hora_minima, tipo_poc
    ) >= 0.05 THEN 'DUDOSO'
    ELSE 'DESCARTADO'
  END as clasificacion_distribucion

FROM USUARIOS_AGREGADOS;


-- ============================================================================
-- PASO 3: ANÁLISIS COMPARATIVO
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 3.1. RESUMEN GENERAL
-- ---------------------------------------------------------------------------

SELECT '=== RESUMEN GENERAL ===' as seccion;

SELECT
  'Total usuarios evaluados' as metrica,
  COUNT(*) as valor
FROM COMPARACION_MODELOS

UNION ALL

SELECT
  'Usuarios válidos (prob >= 0.15) - PIECEWISE' as metrica,
  COUNT(*) as valor
FROM COMPARACION_MODELOS
WHERE prob_piecewise >= 0.15

UNION ALL

SELECT
  'Usuarios válidos (prob >= 0.15) - DISTRIBUCIONES' as metrica,
  COUNT(*) as valor
FROM COMPARACION_MODELOS
WHERE prob_distribucion >= 0.15

UNION ALL

SELECT
  'Diferencia absoluta' as metrica,
  ABS(
    (SELECT COUNT(*) FROM COMPARACION_MODELOS WHERE prob_piecewise >= 0.15) -
    (SELECT COUNT(*) FROM COMPARACION_MODELOS WHERE prob_distribucion >= 0.15)
  ) as valor

UNION ALL

SELECT
  'Diferencia relativa (%)' as metrica,
  CAST(100.0 * ABS(
    (SELECT COUNT(*) FROM COMPARACION_MODELOS WHERE prob_piecewise >= 0.15) -
    (SELECT COUNT(*) FROM COMPARACION_MODELOS WHERE prob_distribucion >= 0.15)
  ) / NULLIF((SELECT COUNT(*) FROM COMPARACION_MODELOS WHERE prob_piecewise >= 0.15), 0) AS INT64) as valor;


-- ---------------------------------------------------------------------------
-- 3.2. DISTRIBUCIÓN POR CLASIFICACIÓN
-- ---------------------------------------------------------------------------

SELECT '=== DISTRIBUCIÓN POR CLASIFICACIÓN ===' as seccion;

SELECT
  clasificacion_piecewise,
  COUNT(*) as n_usuarios_piecewise,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) as pct_piecewise,
  ROUND(AVG(prob_piecewise), 4) as prob_promedio_piecewise
FROM COMPARACION_MODELOS
GROUP BY clasificacion_piecewise
ORDER BY
  CASE clasificacion_piecewise
    WHEN 'VISITA_MUY_PROBABLE' THEN 1
    WHEN 'VISITA_PROBABLE' THEN 2
    WHEN 'VISITA_POSIBLE' THEN 3
    WHEN 'DUDOSO' THEN 4
    ELSE 5
  END;

SELECT
  clasificacion_distribucion,
  COUNT(*) as n_usuarios_distribucion,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) as pct_distribucion,
  ROUND(AVG(prob_distribucion), 4) as prob_promedio_distribucion
FROM COMPARACION_MODELOS
GROUP BY clasificacion_distribucion
ORDER BY
  CASE clasificacion_distribucion
    WHEN 'VISITA_MUY_PROBABLE' THEN 1
    WHEN 'VISITA_PROBABLE' THEN 2
    WHEN 'VISITA_POSIBLE' THEN 3
    WHEN 'DUDOSO' THEN 4
    ELSE 5
  END;


-- ---------------------------------------------------------------------------
-- 3.3. MATRIZ DE CONFUSIÓN (Concordancia entre modelos)
-- ---------------------------------------------------------------------------

SELECT '=== MATRIZ DE CONFUSIÓN ===' as seccion;

SELECT
  clasificacion_piecewise,
  clasificacion_distribucion,
  COUNT(*) as n_usuarios,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) as porcentaje
FROM COMPARACION_MODELOS
GROUP BY clasificacion_piecewise, clasificacion_distribucion
ORDER BY n_usuarios DESC
LIMIT 20;


-- ---------------------------------------------------------------------------
-- 3.4. CORRELACIÓN DE PROBABILIDADES
-- ---------------------------------------------------------------------------

SELECT '=== CORRELACIÓN Y ESTADÍSTICAS ===' as seccion;

SELECT
  ROUND(CORR(prob_piecewise, prob_distribucion), 4) as correlacion,
  ROUND(AVG(prob_piecewise), 4) as prob_piecewise_promedio,
  ROUND(AVG(prob_distribucion), 4) as prob_distribucion_promedio,
  ROUND(STDDEV(prob_piecewise), 4) as prob_piecewise_stddev,
  ROUND(STDDEV(prob_distribucion), 4) as prob_distribucion_stddev,
  ROUND(AVG(ABS(prob_piecewise - prob_distribucion)), 4) as diferencia_promedio_abs,
  ROUND(MAX(ABS(prob_piecewise - prob_distribucion)), 4) as diferencia_maxima
FROM COMPARACION_MODELOS;


-- ---------------------------------------------------------------------------
-- 3.5. USUARIOS CON MAYOR DISCREPANCIA
-- ---------------------------------------------------------------------------

SELECT '=== TOP 20 USUARIOS CON MAYOR DISCREPANCIA ===' as seccion;

SELECT
  msisdn,
  ROUND(tiempo_ok_promedio / 60, 1) as tiempo_ok_min,
  dias_visita,
  ROUND(ratio_horario, 3) as ratio,
  ROUND(stddev_hora_minima, 2) as stddev_hora,
  ROUND(prob_piecewise, 4) as prob_piecewise,
  ROUND(prob_distribucion, 4) as prob_distribucion,
  ROUND(prob_piecewise - prob_distribucion, 4) as diferencia,
  clasificacion_piecewise,
  clasificacion_distribucion
FROM COMPARACION_MODELOS
ORDER BY ABS(prob_piecewise - prob_distribucion) DESC
LIMIT 20;


-- ---------------------------------------------------------------------------
-- 3.6. ANÁLISIS POR SEGMENTOS
-- ---------------------------------------------------------------------------

SELECT '=== COMPARACIÓN POR SEGMENTOS ===' as seccion;

-- Por frecuencia
SELECT
  CASE
    WHEN dias_visita = 1 THEN 'BAJA_FREC'
    WHEN dias_visita BETWEEN 2 AND 4 THEN 'MEDIA_FREC'
    ELSE 'ALTA_FREC'
  END as tipo_frecuencia,
  COUNT(*) as n_usuarios,
  ROUND(AVG(prob_piecewise), 4) as prob_piecewise_promedio,
  ROUND(AVG(prob_distribucion), 4) as prob_distribucion_promedio,
  ROUND(AVG(prob_piecewise - prob_distribucion), 4) as diferencia_promedio
FROM COMPARACION_MODELOS
GROUP BY 1
ORDER BY 1;

-- Por ratio
SELECT
  CASE
    WHEN ratio_horario >= 0.9 THEN 'Ratio alto (>=0.9)'
    WHEN ratio_horario >= 0.8 THEN 'Ratio bueno (0.8-0.9)'
    WHEN ratio_horario >= 0.6 THEN 'Ratio medio (0.6-0.8)'
    ELSE 'Ratio bajo (<0.6)'
  END as bucket_ratio,
  COUNT(*) as n_usuarios,
  ROUND(AVG(prob_piecewise), 4) as prob_piecewise_promedio,
  ROUND(AVG(prob_distribucion), 4) as prob_distribucion_promedio,
  ROUND(AVG(prob_piecewise - prob_distribucion), 4) as diferencia_promedio
FROM COMPARACION_MODELOS
GROUP BY 1
ORDER BY 1;


-- ---------------------------------------------------------------------------
-- 3.7. CASOS DE PRUEBA ESPECÍFICOS
-- ---------------------------------------------------------------------------

SELECT '=== CASOS DE PRUEBA ESPECÍFICOS ===' as seccion;

-- Caso 1: Visitante típico (debe tener prob alta en ambos)
SELECT
  'Visitante típico (45 min, 2 días, ratio 0.9)' as caso,
  ROUND(AVG(prob_piecewise), 4) as prob_piecewise,
  ROUND(AVG(prob_distribucion), 4) as prob_distribucion
FROM COMPARACION_MODELOS
WHERE tiempo_ok_promedio BETWEEN 2400 AND 3000  -- ~40-50 min
  AND dias_visita = 2
  AND ratio_horario >= 0.85

UNION ALL

-- Caso 2: Trabajador típico (debe tener prob baja en ambos)
SELECT
  'Trabajador típico (480 min, 20 días, ratio 0.45, stddev<1)' as caso,
  ROUND(AVG(prob_piecewise), 4) as prob_piecewise,
  ROUND(AVG(prob_distribucion), 4) as prob_distribucion
FROM COMPARACION_MODELOS
WHERE tiempo_ok_promedio > 400 * 60  -- >400 min
  AND dias_visita >= 15
  AND ratio_horario < 0.5
  AND stddev_hora_minima < 1.5

UNION ALL

-- Caso 3: Visitante con ratio medio (caso ambiguo)
SELECT
  'Visitante ratio medio (60 min, 1 día, ratio 0.7)' as caso,
  ROUND(AVG(prob_piecewise), 4) as prob_piecewise,
  ROUND(AVG(prob_distribucion), 4) as prob_distribucion
FROM COMPARACION_MODELOS
WHERE tiempo_ok_promedio BETWEEN 3300 AND 3900  -- ~55-65 min
  AND dias_visita = 1
  AND ratio_horario BETWEEN 0.65 AND 0.75;


-- ============================================================================
-- PASO 4: RECOMENDACIONES BASADAS EN COMPARACIÓN
-- ============================================================================

SELECT '=== RECOMENDACIONES ===' as seccion;

WITH stats AS (
  SELECT
    CORR(prob_piecewise, prob_distribucion) as correlacion,
    COUNT(CASE WHEN ABS(prob_piecewise - prob_distribucion) > 0.05 THEN 1 END) as n_discrepancias_grandes,
    COUNT(*) as n_total,
    100.0 * COUNT(CASE WHEN ABS(prob_piecewise - prob_distribucion) > 0.05 THEN 1 END) / COUNT(*) as pct_discrepancias
  FROM COMPARACION_MODELOS
)
SELECT
  CASE
    WHEN correlacion >= 0.9 AND pct_discrepancias < 10 THEN
      'Ambos modelos son muy similares. Usar PIECEWISE (más simple de mantener).'
    WHEN correlacion >= 0.8 AND pct_discrepancias < 20 THEN
      'Modelos son similares con algunas diferencias. Considerar HÍBRIDO.'
    WHEN correlacion < 0.8 OR pct_discrepancias >= 20 THEN
      'Modelos difieren significativamente. Validar con datos reales para decidir.'
    ELSE
      'Revisar análisis detallado antes de decidir.'
  END as recomendacion,
  ROUND(correlacion, 3) as correlacion,
  n_discrepancias_grandes,
  ROUND(pct_discrepancias, 1) as pct_discrepancias
FROM stats;


-- ============================================================================
-- FIN DE COMPARACIÓN
-- ============================================================================

-- EXPORTAR RESULTADOS:
-- 1. Guarda COMPARACION_MODELOS como tabla permanente si quieres analizarla después
-- 2. Exporta las queries de análisis a Excel/CSV para presentación
-- 3. Usa los casos de prueba para validar manualmente

/*
-- OPCIONAL: Guardar tabla de comparación
CREATE OR REPLACE TABLE `mo-advertising-sta.ADVERTISING_TEST.COMPARACION_PIECEWISE_VS_DIST` AS
SELECT * FROM COMPARACION_MODELOS;
*/
