-- ============================================================================
-- QUERIES DE ANÁLISIS EXPLORATORIO
-- Proyecto: Modelo de Estimación de Visitas
-- POC: VOLVO_XC40-AON_ABR2026_4
-- ============================================================================

-- IMPORTANTE: Estas queries analizan TODAS las variables disponibles:
-- - Temporales: tiempo_ok, tiempo_no_ok, hora_min, hora_max, dif_horas
-- - Frecuencia: dias_visita
-- - Espaciales: prob_espacial
-- - Derivadas: ratio_horario, stddev_hora, patron_laboral

-- ============================================================================
-- QUERY 0: CONFIGURACIÓN
-- ============================================================================

DECLARE proyecto STRING DEFAULT 'mm-datamart-kd';
DECLARE dataset STRING DEFAULT 'ADVERTISING_TEST';
DECLARE tabla STRING DEFAULT 'VISITAS_UBICACION_GEO_TILES_CELIA_ISA_V2';
DECLARE poc_nombre STRING DEFAULT 'VOLVO_XC40-AON_ABR2026_4';

-- ============================================================================
-- QUERY 1: TABLA BASE CON VARIABLES DERIVADAS
-- ============================================================================
-- Crea tabla temporal con TODAS las variables (base + derivadas)

CREATE OR REPLACE TEMP TABLE BASE AS
SELECT
  -- Identificadores
  msisdn,
  id_ubicacion,
  poc,
  PERIODO,
  fecha,
  DIA_SEMANA,

  -- Temporales base
  tiempo_total_ok_dia,
  tiempo_total_no_ok_dia,
  dif_horas,
  num_horas,
  hora_minima,
  hora_maxima,

  -- Frecuencia
  dias_msisdn_ubicacion_PERIODO as dias_visita,

  -- Espacial
  PROBABILIDAD_VISITA_OK as prob_espacial,

  -- ========== VARIABLES DERIVADAS ==========

  -- 1. Tiempos en minutos (más fáciles de interpretar)
  ROUND(tiempo_total_ok_dia / 60.0, 2) as tiempo_ok_min,
  ROUND(tiempo_total_no_ok_dia / 60.0, 2) as tiempo_no_ok_min,
  ROUND((tiempo_total_ok_dia + tiempo_total_no_ok_dia) / 60.0, 2) as tiempo_total_min,

  -- 2. Ratio de horario (CRÍTICO)
  SAFE_DIVIDE(
    tiempo_total_ok_dia,
    tiempo_total_ok_dia + tiempo_total_no_ok_dia
  ) as ratio_horario,

  -- 3. Buckets de tiempo
  CASE
    WHEN tiempo_total_ok_dia < 900 THEN 'A-<15min'
    WHEN tiempo_total_ok_dia < 1800 THEN 'B-15-30min'
    WHEN tiempo_total_ok_dia < 3600 THEN 'C-30-60min'
    WHEN tiempo_total_ok_dia < 5400 THEN 'D-60-90min'
    WHEN tiempo_total_ok_dia < 7200 THEN 'E-90-120min'
    WHEN tiempo_total_ok_dia < 10800 THEN 'F-2-3h'
    ELSE 'G->3h'
  END as bucket_tiempo,

  -- 4. Bucket de ratio
  CASE
    WHEN tiempo_total_no_ok_dia = 0 THEN 'A-Ratio 1.0 (sin NO_OK)'
    WHEN SAFE_DIVIDE(tiempo_total_ok_dia, tiempo_total_ok_dia + tiempo_total_no_ok_dia) >= 0.95
      THEN 'B-Ratio 0.95-1.0'
    WHEN SAFE_DIVIDE(tiempo_total_ok_dia, tiempo_total_ok_dia + tiempo_total_no_ok_dia) >= 0.8
      THEN 'C-Ratio 0.8-0.95'
    WHEN SAFE_DIVIDE(tiempo_total_ok_dia, tiempo_total_ok_dia + tiempo_total_no_ok_dia) >= 0.6
      THEN 'D-Ratio 0.6-0.8'
    WHEN SAFE_DIVIDE(tiempo_total_ok_dia, tiempo_total_ok_dia + tiempo_total_no_ok_dia) >= 0.4
      THEN 'E-Ratio 0.4-0.6'
    WHEN SAFE_DIVIDE(tiempo_total_ok_dia, tiempo_total_ok_dia + tiempo_total_no_ok_dia) >= 0.2
      THEN 'F-Ratio 0.2-0.4'
    ELSE 'G-Ratio <0.2'
  END as bucket_ratio,

  -- 5. Tipo de frecuencia
  CASE
    WHEN dias_msisdn_ubicacion_PERIODO = 1 THEN 'BAJA_FREC'
    WHEN dias_msisdn_ubicacion_PERIODO BETWEEN 2 AND 4 THEN 'MEDIA_FREC'
    ELSE 'ALTA_FREC'
  END as tipo_frecuencia,

  -- 6. Clasificación actual (filtro 30-90 min)
  CASE
    WHEN tiempo_total_ok_dia BETWEEN 1800 AND 5400 AND tiempo_total_no_ok_dia = 0
      THEN 'VALIDO_ACTUAL'
    WHEN tiempo_total_ok_dia BETWEEN 1800 AND 5400 AND tiempo_total_no_ok_dia > 0
      THEN 'PERDIDO_POR_NO_OK'
    WHEN tiempo_total_ok_dia < 1800 THEN 'DESCARTADO_CORTO'
    WHEN tiempo_total_ok_dia > 5400 THEN 'DESCARTADO_LARGO'
    ELSE 'OTRO'
  END as clasificacion_actual,

  -- 7. Flags de horario
  CASE WHEN hora_minima < 10 THEN 1 ELSE 0 END as llega_antes_abrir,
  CASE WHEN hora_maxima > 20 THEN 1 ELSE 0 END as sale_despues_cerrar,
  CASE WHEN hora_maxima <= 10 OR hora_minima >= 20 THEN 1 ELSE 0 END as solo_fuera_horario,

  -- 8. Patrón laboral básico (se calcula mejor a nivel usuario)
  CASE
    WHEN dif_horas >= 7
      AND hora_minima BETWEEN 7 AND 10
      AND hora_maxima BETWEEN 17 AND 20
      AND dias_msisdn_ubicacion_PERIODO >= 4
    THEN 1
    ELSE 0
  END as patron_laboral_basico

FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_UBICACION_GEO_TILES_CELIA_ISA_V2`
WHERE poc = 'VOLVO_XC40-AON_ABR2026_4'
  AND PERIODO = 'CAMPAIGN'
  AND tiempo_total_ok_dia > 0;  -- Debe haber al menos algún tiempo OK

-- Ver primeras filas
SELECT * FROM BASE LIMIT 10;


-- ============================================================================
-- QUERY 2: TABLA CON PATRONES HORARIOS POR USUARIO
-- ============================================================================
-- Añade variables de variabilidad horaria a nivel usuario-ubicación

CREATE OR REPLACE TEMP TABLE BASE_CON_PATRONES AS
SELECT
  b.*,

  -- Variabilidad de horarios (por usuario-ubicación)
  STDDEV(hora_minima) OVER (
    PARTITION BY msisdn, id_ubicacion
  ) as stddev_hora_minima,

  STDDEV(hora_maxima) OVER (
    PARTITION BY msisdn, id_ubicacion
  ) as stddev_hora_maxima,

  -- Promedios de horarios (por usuario-ubicación)
  AVG(hora_minima) OVER (
    PARTITION BY msisdn, id_ubicacion
  ) as hora_minima_promedio,

  AVG(hora_maxima) OVER (
    PARTITION BY msisdn, id_ubicacion
  ) as hora_maxima_promedio,

  AVG(dif_horas) OVER (
    PARTITION BY msisdn, id_ubicacion
  ) as dif_horas_promedio,

  AVG(ratio_horario) OVER (
    PARTITION BY msisdn, id_ubicacion
  ) as ratio_horario_promedio,

  -- Categoría de patrón horario
  CASE
    WHEN STDDEV(hora_minima) OVER (PARTITION BY msisdn, id_ubicacion) < 1.5
      AND STDDEV(hora_maxima) OVER (PARTITION BY msisdn, id_ubicacion) < 1.5
      THEN 'PATRON_MUY_CONSISTENTE'
    WHEN STDDEV(hora_minima) OVER (PARTITION BY msisdn, id_ubicacion) < 3
      AND STDDEV(hora_maxima) OVER (PARTITION BY msisdn, id_ubicacion) < 3
      THEN 'PATRON_ALGO_CONSISTENTE'
    ELSE 'PATRON_VARIABLE'
  END as categoria_patron,

  -- Patrón laboral mejorado (considera consistencia)
  CASE
    WHEN dif_horas >= 7
      AND hora_minima BETWEEN 7 AND 10
      AND hora_maxima BETWEEN 17 AND 20
      AND dias_visita >= 4
      AND STDDEV(hora_minima) OVER (PARTITION BY msisdn, id_ubicacion) < 2
      AND STDDEV(hora_maxima) OVER (PARTITION BY msisdn, id_ubicacion) < 2
    THEN 1
    ELSE 0
  END as patron_laboral_mejorado

FROM BASE b;

-- Ver primeras filas
SELECT * FROM BASE_CON_PATRONES LIMIT 10;


-- ============================================================================
-- QUERY 3: RESUMEN GENERAL
-- ============================================================================

SELECT
  '=== RESUMEN GENERAL ===' as seccion,
  COUNT(*) as total_registros,
  COUNT(DISTINCT msisdn) as total_usuarios,
  COUNT(DISTINCT id_ubicacion) as total_ubicaciones,
  MIN(fecha) as fecha_min,
  MAX(fecha) as fecha_max,
  COUNT(DISTINCT fecha) as dias_campana
FROM BASE;


-- ============================================================================
-- QUERY 4: DISTRIBUCIÓN POR CLASIFICACIÓN ACTUAL
-- ============================================================================

SELECT
  clasificacion_actual,
  COUNT(*) as n_registros,
  COUNT(DISTINCT msisdn) as n_usuarios,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) as pct_registros,
  ROUND(100.0 * COUNT(DISTINCT msisdn) / SUM(COUNT(DISTINCT msisdn)) OVER(), 2) as pct_usuarios,

  -- Estadísticas tiempo
  ROUND(AVG(tiempo_ok_min), 1) as tiempo_ok_min_promedio,
  ROUND(AVG(tiempo_no_ok_min), 1) as tiempo_no_ok_min_promedio,
  ROUND(AVG(ratio_horario), 3) as ratio_promedio,

  -- Estadísticas espaciales
  ROUND(AVG(prob_espacial), 4) as prob_espacial_promedio

FROM BASE
GROUP BY clasificacion_actual
ORDER BY
  CASE clasificacion_actual
    WHEN 'VALIDO_ACTUAL' THEN 1
    WHEN 'PERDIDO_POR_NO_OK' THEN 2
    WHEN 'DESCARTADO_CORTO' THEN 3
    WHEN 'DESCARTADO_LARGO' THEN 4
    ELSE 5
  END;


-- ============================================================================
-- QUERY 5: DISTRIBUCIÓN POR BUCKET DE TIEMPO
-- ============================================================================

SELECT
  bucket_tiempo,
  COUNT(*) as n_registros,
  COUNT(DISTINCT msisdn) as n_usuarios,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) as pct_registros,

  -- Por clasificación actual
  SUM(CASE WHEN clasificacion_actual = 'VALIDO_ACTUAL' THEN 1 ELSE 0 END) as n_validos,
  SUM(CASE WHEN clasificacion_actual = 'PERDIDO_POR_NO_OK' THEN 1 ELSE 0 END) as n_perdidos_no_ok,

  -- Promedios
  ROUND(AVG(tiempo_ok_min), 1) as tiempo_ok_min_promedio,
  ROUND(AVG(ratio_horario), 3) as ratio_promedio,
  ROUND(AVG(prob_espacial), 4) as prob_espacial_promedio

FROM BASE
GROUP BY bucket_tiempo
ORDER BY bucket_tiempo;


-- ============================================================================
-- QUERY 6: DISTRIBUCIÓN POR BUCKET DE RATIO
-- ============================================================================

SELECT
  bucket_ratio,
  COUNT(*) as n_registros,
  COUNT(DISTINCT msisdn) as n_usuarios,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) as pct_registros,

  -- Por clasificación actual
  SUM(CASE WHEN clasificacion_actual = 'VALIDO_ACTUAL' THEN 1 ELSE 0 END) as n_validos,
  SUM(CASE WHEN clasificacion_actual = 'PERDIDO_POR_NO_OK' THEN 1 ELSE 0 END) as n_perdidos_no_ok,

  -- Promedios
  ROUND(AVG(tiempo_ok_min), 1) as tiempo_ok_min_promedio,
  ROUND(AVG(tiempo_no_ok_min), 1) as tiempo_no_ok_min_promedio,
  ROUND(AVG(ratio_horario), 3) as ratio_promedio,
  ROUND(AVG(prob_espacial), 4) as prob_espacial_promedio

FROM BASE
GROUP BY bucket_ratio
ORDER BY bucket_ratio;


-- ============================================================================
-- QUERY 7: DISTRIBUCIÓN POR TIPO DE FRECUENCIA
-- ============================================================================

SELECT
  tipo_frecuencia,
  COUNT(*) as n_registros,
  COUNT(DISTINCT msisdn) as n_usuarios,
  ROUND(100.0 * COUNT(DISTINCT msisdn) / SUM(COUNT(DISTINCT msisdn)) OVER(), 2) as pct_usuarios,

  -- Días promedio
  ROUND(AVG(dias_visita), 1) as dias_promedio,

  -- Por clasificación actual
  SUM(CASE WHEN clasificacion_actual = 'VALIDO_ACTUAL' THEN 1 ELSE 0 END) as n_validos,
  SUM(CASE WHEN clasificacion_actual = 'PERDIDO_POR_NO_OK' THEN 1 ELSE 0 END) as n_perdidos_no_ok,

  -- Promedios
  ROUND(AVG(tiempo_ok_min), 1) as tiempo_ok_min_promedio,
  ROUND(AVG(ratio_horario), 3) as ratio_promedio,
  ROUND(AVG(prob_espacial), 4) as prob_espacial_promedio

FROM BASE
GROUP BY tipo_frecuencia
ORDER BY
  CASE tipo_frecuencia
    WHEN 'BAJA_FREC' THEN 1
    WHEN 'MEDIA_FREC' THEN 2
    WHEN 'ALTA_FREC' THEN 3
  END;


-- ============================================================================
-- QUERY 8: ANÁLISIS DE PATRONES HORARIOS
-- ============================================================================

SELECT
  categoria_patron,
  tipo_frecuencia,

  COUNT(DISTINCT msisdn) as n_usuarios,

  -- Estadísticas horarias
  ROUND(AVG(stddev_hora_minima), 2) as stddev_hora_min_promedio,
  ROUND(AVG(stddev_hora_maxima), 2) as stddev_hora_max_promedio,
  ROUND(AVG(hora_minima_promedio), 1) as hora_min_promedio,
  ROUND(AVG(hora_maxima_promedio), 1) as hora_max_promedio,
  ROUND(AVG(dif_horas_promedio), 2) as dif_horas_promedio,

  -- Ratio
  ROUND(AVG(ratio_horario_promedio), 3) as ratio_promedio,

  -- Prob espacial
  ROUND(AVG(prob_espacial), 4) as prob_espacial_promedio,

  -- Flags
  ROUND(100.0 * AVG(llega_antes_abrir), 2) as pct_llega_antes,
  ROUND(100.0 * AVG(sale_despues_cerrar), 2) as pct_sale_despues,
  ROUND(100.0 * AVG(patron_laboral_mejorado), 2) as pct_patron_laboral

FROM BASE_CON_PATRONES
GROUP BY 1, 2
ORDER BY 1, 2;


-- ============================================================================
-- QUERY 9: IMPACTO DEL FILTRO tiempo_no_ok = 0
-- ============================================================================

SELECT
  bucket_tiempo,
  tipo_frecuencia,

  -- Totales
  COUNT(*) as total_registros,
  COUNT(DISTINCT msisdn) as total_usuarios,

  -- Válidos actuales (30-90 min + sin NO_OK)
  SUM(CASE WHEN clasificacion_actual = 'VALIDO_ACTUAL' THEN 1 ELSE 0 END) as n_validos_actuales,
  COUNT(DISTINCT CASE WHEN clasificacion_actual = 'VALIDO_ACTUAL' THEN msisdn END) as usuarios_validos_actuales,

  -- Perdidos por NO_OK (30-90 min PERO con NO_OK>0)
  SUM(CASE WHEN clasificacion_actual = 'PERDIDO_POR_NO_OK' THEN 1 ELSE 0 END) as n_perdidos_no_ok,
  COUNT(DISTINCT CASE WHEN clasificacion_actual = 'PERDIDO_POR_NO_OK' THEN msisdn END) as usuarios_perdidos_no_ok,

  -- Ratio válidos / perdidos
  ROUND(
    SAFE_DIVIDE(
      SUM(CASE WHEN clasificacion_actual = 'PERDIDO_POR_NO_OK' THEN 1 ELSE 0 END),
      SUM(CASE WHEN clasificacion_actual = 'VALIDO_ACTUAL' THEN 1 ELSE 0 END)
    ),
    2
  ) as ratio_perdidos_vs_validos,

  -- Estadísticas de los PERDIDOS
  ROUND(AVG(CASE WHEN clasificacion_actual = 'PERDIDO_POR_NO_OK' THEN ratio_horario END), 3) as ratio_promedio_perdidos,
  ROUND(AVG(CASE WHEN clasificacion_actual = 'PERDIDO_POR_NO_OK' THEN prob_espacial END), 4) as prob_espacial_promedio_perdidos

FROM BASE
WHERE bucket_tiempo IN ('C-30-60min', 'D-60-90min')  -- Solo rango válido actual
GROUP BY 1, 2
ORDER BY 1, 2;


-- ============================================================================
-- QUERY 10: USUARIOS RECUPERABLES CON RATIO ALTO
-- ============================================================================
-- Identifica usuarios que se pierden por tiempo_no_ok pero tienen ratio alto

SELECT
  bucket_tiempo,
  tipo_frecuencia,
  bucket_ratio,

  COUNT(DISTINCT msisdn) as n_usuarios_recuperables,
  COUNT(*) as n_registros,

  -- Estadísticas
  ROUND(AVG(tiempo_ok_min), 1) as tiempo_ok_min_promedio,
  ROUND(AVG(tiempo_no_ok_min), 1) as tiempo_no_ok_min_promedio,
  ROUND(AVG(ratio_horario), 3) as ratio_promedio,
  ROUND(AVG(prob_espacial), 4) as prob_espacial_promedio,

  -- Días
  ROUND(AVG(dias_visita), 1) as dias_promedio

FROM BASE
WHERE clasificacion_actual = 'PERDIDO_POR_NO_OK'  -- Perdidos por NO_OK
  AND ratio_horario >= 0.6  -- Pero con ratio razonable
GROUP BY 1, 2, 3
ORDER BY n_usuarios_recuperables DESC
LIMIT 20;


-- ============================================================================
-- QUERY 11: TOP USUARIOS CON PATRÓN LABORAL
-- ============================================================================
-- Usuarios ALTA_FREC con horarios consistentes (posibles trabajadores)

SELECT
  msisdn,
  COUNT(DISTINCT fecha) as dias_visita,

  -- Horarios
  ROUND(AVG(hora_minima), 2) as hora_min_promedio,
  ROUND(AVG(hora_maxima), 2) as hora_max_promedio,
  ROUND(STDDEV(hora_minima), 2) as stddev_hora_min,
  ROUND(STDDEV(hora_maxima), 2) as stddev_hora_max,

  -- Tiempos
  ROUND(AVG(tiempo_ok_min), 1) as tiempo_ok_min_promedio,
  ROUND(AVG(tiempo_no_ok_min), 1) as tiempo_no_ok_min_promedio,
  ROUND(AVG(ratio_horario), 3) as ratio_promedio,

  -- Duración
  ROUND(AVG(dif_horas), 1) as dif_horas_promedio,

  -- Patrón
  MAX(patron_laboral_basico) as cumple_patron_laboral,

  -- Espacial
  ROUND(AVG(prob_espacial), 4) as prob_espacial_promedio,

  -- Clasificación
  SUM(CASE WHEN clasificacion_actual = 'VALIDO_ACTUAL' THEN 1 ELSE 0 END) as n_dias_valido

FROM BASE
WHERE tipo_frecuencia = 'ALTA_FREC'
GROUP BY msisdn
HAVING COUNT(DISTINCT fecha) >= 4
  AND STDDEV(hora_minima) < 2  -- Horarios consistentes
  AND STDDEV(hora_maxima) < 2
  AND AVG(dif_horas) >= 6  -- Permanencias largas
ORDER BY dias_visita DESC, stddev_hora_min ASC
LIMIT 50;


-- ============================================================================
-- QUERY 12: TOP USUARIOS VISITANTES CLAROS
-- ============================================================================
-- Usuarios con patrón de visitante claro (horarios variables, ratio alto, baja frecuencia)

SELECT
  msisdn,
  COUNT(DISTINCT fecha) as dias_visita,

  -- Horarios
  ROUND(AVG(hora_minima), 2) as hora_min_promedio,
  ROUND(AVG(hora_maxima), 2) as hora_max_promedio,
  ROUND(STDDEV(hora_minima), 2) as stddev_hora_min,
  ROUND(STDDEV(hora_maxima), 2) as stddev_hora_max,

  -- Tiempos
  ROUND(AVG(tiempo_ok_min), 1) as tiempo_ok_min_promedio,
  ROUND(AVG(tiempo_no_ok_min), 1) as tiempo_no_ok_min_promedio,
  ROUND(AVG(ratio_horario), 3) as ratio_promedio,

  -- Duración
  ROUND(AVG(dif_horas), 1) as dif_horas_promedio,

  -- Espacial
  ROUND(AVG(prob_espacial), 4) as prob_espacial_promedio,

  -- Clasificación
  SUM(CASE WHEN clasificacion_actual = 'VALIDO_ACTUAL' THEN 1 ELSE 0 END) as n_dias_valido,
  SUM(CASE WHEN clasificacion_actual = 'PERDIDO_POR_NO_OK' THEN 1 ELSE 0 END) as n_dias_perdido_no_ok

FROM BASE
WHERE bucket_tiempo IN ('C-30-60min', 'D-60-90min')  -- Duración válida
GROUP BY msisdn
HAVING COUNT(DISTINCT fecha) BETWEEN 1 AND 4  -- Baja-Media frecuencia
  AND AVG(ratio_horario) >= 0.7  -- Ratio alto
  AND (STDDEV(hora_minima) > 3 OR COUNT(DISTINCT fecha) = 1)  -- Horarios variables o solo 1 día
ORDER BY ratio_promedio DESC, prob_espacial_promedio DESC
LIMIT 50;


-- ============================================================================
-- QUERY 13: ESCENARIOS DE RECUPERACIÓN
-- ============================================================================
-- Cuantifica usuarios recuperables según diferentes umbrales de ratio

WITH escenarios AS (
  SELECT
    msisdn,
    MAX(CASE WHEN clasificacion_actual = 'VALIDO_ACTUAL' THEN 1 ELSE 0 END) as es_valido_actual,
    MAX(CASE WHEN clasificacion_actual = 'PERDIDO_POR_NO_OK' THEN 1 ELSE 0 END) as es_perdido_no_ok,
    AVG(ratio_horario) as ratio_promedio
  FROM BASE
  GROUP BY msisdn
)
SELECT
  'Válidos actuales (baseline)' as escenario,
  SUM(es_valido_actual) as n_usuarios,
  NULL as incremento_vs_actual,
  NULL as pct_incremento
FROM escenarios

UNION ALL

SELECT
  'Escenario 1: Recuperar ratio ≥ 0.9' as escenario,
  SUM(es_valido_actual) + SUM(CASE WHEN es_perdido_no_ok = 1 AND ratio_promedio >= 0.9 THEN 1 ELSE 0 END) as n_usuarios,
  SUM(CASE WHEN es_perdido_no_ok = 1 AND ratio_promedio >= 0.9 THEN 1 ELSE 0 END) as incremento_vs_actual,
  ROUND(100.0 * SUM(CASE WHEN es_perdido_no_ok = 1 AND ratio_promedio >= 0.9 THEN 1 ELSE 0 END) /
    NULLIF(SUM(es_valido_actual), 0), 1) as pct_incremento
FROM escenarios

UNION ALL

SELECT
  'Escenario 2: Recuperar ratio ≥ 0.8 (RECOMENDADO)' as escenario,
  SUM(es_valido_actual) + SUM(CASE WHEN es_perdido_no_ok = 1 AND ratio_promedio >= 0.8 THEN 1 ELSE 0 END) as n_usuarios,
  SUM(CASE WHEN es_perdido_no_ok = 1 AND ratio_promedio >= 0.8 THEN 1 ELSE 0 END) as incremento_vs_actual,
  ROUND(100.0 * SUM(CASE WHEN es_perdido_no_ok = 1 AND ratio_promedio >= 0.8 THEN 1 ELSE 0 END) /
    NULLIF(SUM(es_valido_actual), 0), 1) as pct_incremento
FROM escenarios

UNION ALL

SELECT
  'Escenario 3: Recuperar ratio ≥ 0.7' as escenario,
  SUM(es_valido_actual) + SUM(CASE WHEN es_perdido_no_ok = 1 AND ratio_promedio >= 0.7 THEN 1 ELSE 0 END) as n_usuarios,
  SUM(CASE WHEN es_perdido_no_ok = 1 AND ratio_promedio >= 0.7 THEN 1 ELSE 0 END) as incremento_vs_actual,
  ROUND(100.0 * SUM(CASE WHEN es_perdido_no_ok = 1 AND ratio_promedio >= 0.7 THEN 1 ELSE 0 END) /
    NULLIF(SUM(es_valido_actual), 0), 1) as pct_incremento
FROM escenarios

UNION ALL

SELECT
  'Escenario 4: Recuperar ratio ≥ 0.6' as escenario,
  SUM(es_valido_actual) + SUM(CASE WHEN es_perdido_no_ok = 1 AND ratio_promedio >= 0.6 THEN 1 ELSE 0 END) as n_usuarios,
  SUM(CASE WHEN es_perdido_no_ok = 1 AND ratio_promedio >= 0.6 THEN 1 ELSE 0 END) as incremento_vs_actual,
  ROUND(100.0 * SUM(CASE WHEN es_perdido_no_ok = 1 AND ratio_promedio >= 0.6 THEN 1 ELSE 0 END) /
    NULLIF(SUM(es_valido_actual), 0), 1) as pct_incremento
FROM escenarios;
