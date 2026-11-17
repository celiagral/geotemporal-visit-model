-- ============================================================================
-- HELPER: CÁLCULO AUTOMÁTICO DE PARÁMETROS
-- ============================================================================
--
-- Script OPCIONAL para ayudarte a calcular parámetros para CONFIG_SIMPLE
--
-- Uso:
-- 1. Cambia el nombre del POC (línea 30)
-- 2. Ejecuta este script
-- 3. Copia los valores sugeridos
-- 4. Pégalos en CONFIG_SIMPLE manualmente
--
-- ============================================================================


-- ============================================================================
-- PASO 1: Extraer datos del POC
-- ============================================================================

CREATE OR REPLACE TEMP TABLE DATOS_POC AS
SELECT
  msisdn,
  AVG(tiempo_total_ok_dia) as tiempo_promedio,
  COUNT(DISTINCT fecha) as dias_visita,
  STDDEV(hora_minima) as stddev_hora_minima,
  AVG(dif_horas) as dif_horas_promedio,

  -- % fuera horario (asumiendo horario 9-21 genérico)
  100.0 * SUM(CASE WHEN hora_minima < 9 THEN 1 ELSE 0 END) / COUNT(*) as pct_llega_antes,
  100.0 * SUM(CASE WHEN hora_maxima > 21 THEN 1 ELSE 0 END) / COUNT(*) as pct_sale_despues

FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_UBICACION_GEO_TILES_CELIA_ISA_V2`
WHERE poc = 'NORGES_SEAFOOD-SALMON_AGO26'  -- 🔧 CAMBIAR POR TU POC
  AND PERIODO = 'CAMPAIGN'
  AND tiempo_total_ok_dia > 0
GROUP BY msisdn;


-- ============================================================================
-- PASO 2: Calcular Percentiles
-- ============================================================================

WITH percentiles AS (
  SELECT
    -- Percentiles de tiempo (segundos)
    APPROX_QUANTILES(tiempo_promedio, 100)[OFFSET(5)] as tiempo_p05,
    APPROX_QUANTILES(tiempo_promedio, 100)[OFFSET(25)] as tiempo_p25,
    APPROX_QUANTILES(tiempo_promedio, 100)[OFFSET(50)] as tiempo_p50,
    APPROX_QUANTILES(tiempo_promedio, 100)[OFFSET(75)] as tiempo_p75,
    APPROX_QUANTILES(tiempo_promedio, 100)[OFFSET(95)] as tiempo_p95,

    -- Percentiles de frecuencia (días)
    APPROX_QUANTILES(dias_visita, 100)[OFFSET(50)] as dias_p50,
    APPROX_QUANTILES(dias_visita, 100)[OFFSET(75)] as dias_p75,
    APPROX_QUANTILES(dias_visita, 100)[OFFSET(95)] as dias_p95,

    -- Estadísticas de patrón
    APPROX_QUANTILES(stddev_hora_minima, 100)[OFFSET(25)] as stddev_p25,
    AVG(dif_horas_promedio) as dif_horas_media,
    AVG(pct_llega_antes + pct_sale_despues) as pct_fuera_media,

    -- Metadatos
    COUNT(*) as n_usuarios,
    AVG(tiempo_promedio) as tiempo_media,
    STDDEV(tiempo_promedio) as tiempo_stddev

  FROM DATOS_POC
)

-- ============================================================================
-- PASO 3: Sugerir Parámetros
-- ============================================================================

SELECT
  '📊 PARÁMETROS SUGERIDOS PARA CONFIG_SIMPLE' as titulo,
  '' as separador,

  -- =========================================================================
  -- TIEMPOS (en segundos, luego convertir a minutos)
  -- =========================================================================
  '⏱️ TIEMPOS:' as seccion_tiempo,
  CAST(tiempo_p05 AS INT64) as tiempo_min,
  CONCAT('  ', ROUND(tiempo_p05 / 60, 1), ' min') as tiempo_min_legible,

  CAST(tiempo_p25 AS INT64) as tiempo_optimo_min,
  CONCAT('  ', ROUND(tiempo_p25 / 60, 1), ' min') as tiempo_optimo_min_legible,

  CAST(tiempo_p75 AS INT64) as tiempo_optimo_max,
  CONCAT('  ', ROUND(tiempo_p75 / 60, 1), ' min') as tiempo_optimo_max_legible,

  CAST(tiempo_p95 AS INT64) as tiempo_max,
  CONCAT('  ', ROUND(tiempo_p95 / 60, 1), ' min') as tiempo_max_legible,

  '' as separador2,

  -- =========================================================================
  -- FRECUENCIA (días)
  -- =========================================================================
  '📅 FRECUENCIA:' as seccion_frecuencia,
  1 as dias_optimo_min,
  '  (siempre 1)' as dias_optimo_min_nota,

  CAST(dias_p75 AS INT64) as dias_optimo_max,
  CONCAT('  (p75)') as dias_optimo_max_nota,

  CAST(dias_p95 AS INT64) as dias_max,
  CONCAT('  (p95, trabajadores si > esto)') as dias_max_nota,

  '' as separador3,

  -- =========================================================================
  -- DETECCIÓN TRABAJADORES
  -- =========================================================================
  '👷 DETECCIÓN TRABAJADORES:' as seccion_trabajadores,
  ROUND(stddev_p25, 1) as stddev_max_trabajador,
  '  (p25 de stddev_hora)' as stddev_nota,

  ROUND(dif_horas_media, 1) as dif_horas_min_trabajador,
  '  (media dif_horas)' as dif_horas_nota,

  ROUND(GREATEST(50.0, pct_fuera_media + 10), 1) as pct_fuera_max,
  '  (media + margen)' as pct_fuera_nota,

  '' as separador4,

  -- =========================================================================
  -- RATIOS (basados en riesgo trabajadores)
  -- =========================================================================
  '📊 RATIOS:' as seccion_ratios,
  CASE
    WHEN dias_p95 > 15 THEN 0.50
    WHEN dias_p95 > 10 THEN 0.65
    ELSE 0.75
  END as ratio_minimo,
  CONCAT('  (basado en dias_p95=', CAST(dias_p95 AS INT64), ')') as ratio_min_nota,

  CASE
    WHEN dias_p95 > 15 THEN 0.75
    WHEN dias_p95 > 10 THEN 0.85
    ELSE 0.90
  END as ratio_optimo,
  '' as ratio_opt_nota,

  '' as separador5,

  -- =========================================================================
  -- UMBRALES (basados en dispersión)
  -- =========================================================================
  '🎯 UMBRALES:' as seccion_umbrales,
  CASE
    WHEN (tiempo_stddev / NULLIF(tiempo_media, 0)) < 0.5 THEN 0.20
    WHEN (tiempo_stddev / NULLIF(tiempo_media, 0)) < 1.0 THEN 0.15
    ELSE 0.12
  END as umbral_muy_probable,
  CONCAT('  (CV=', ROUND(tiempo_stddev / NULLIF(tiempo_media, 0), 2), ')') as umbral_mp_nota,

  CASE
    WHEN (tiempo_stddev / NULLIF(tiempo_media, 0)) < 0.5 THEN 0.15
    WHEN (tiempo_stddev / NULLIF(tiempo_media, 0)) < 1.0 THEN 0.12
    ELSE 0.08
  END as umbral_probable,
  '' as umbral_p_nota,

  CASE
    WHEN (tiempo_stddev / NULLIF(tiempo_media, 0)) < 0.5 THEN 0.10
    WHEN (tiempo_stddev / NULLIF(tiempo_media, 0)) < 1.0 THEN 0.08
    ELSE 0.05
  END as umbral_posible,
  '' as umbral_pos_nota,

  '' as separador6,

  -- =========================================================================
  -- PESOS (basados en riesgo trabajadores)
  -- =========================================================================
  '⚖️ PESOS:' as seccion_pesos,
  CASE
    WHEN dias_p95 > 15 THEN 0.20
    WHEN dias_p95 > 10 THEN 0.25
    ELSE 0.30
  END as peso_espacial,
  '  (suma debe ser 1.0)' as peso_esp_nota,

  CASE
    WHEN dias_p95 > 15 THEN 0.30
    WHEN dias_p95 > 10 THEN 0.35
    ELSE 0.40
  END as peso_temporal,
  '' as peso_temp_nota,

  CASE
    WHEN dias_p95 > 15 THEN 0.50
    WHEN dias_p95 > 10 THEN 0.40
    ELSE 0.30
  END as peso_patron,
  CONCAT('  (alto si dias_p95 alto: ', CAST(dias_p95 AS INT64), ')') as peso_pat_nota,

  '' as separador7,

  -- =========================================================================
  -- METADATA
  -- =========================================================================
  '📈 METADATA:' as seccion_metadata,
  n_usuarios as usuarios_analizados,
  CONCAT(ROUND(tiempo_media / 60, 1), ' min') as tiempo_medio,
  ROUND(tiempo_stddev / NULLIF(tiempo_media, 0), 2) as coef_variacion,
  ROUND(dias_p50, 1) as dias_mediana

FROM percentiles;


-- ============================================================================
-- PASO 4: SQL Listo para Copiar
-- ============================================================================

WITH params AS (
  SELECT
    CAST(APPROX_QUANTILES(tiempo_promedio, 100)[OFFSET(5)] AS INT64) as tiempo_min,
    CAST(APPROX_QUANTILES(tiempo_promedio, 100)[OFFSET(25)] AS INT64) as tiempo_optimo_min,
    CAST(APPROX_QUANTILES(tiempo_promedio, 100)[OFFSET(75)] AS INT64) as tiempo_optimo_max,
    CAST(APPROX_QUANTILES(tiempo_promedio, 100)[OFFSET(95)] AS INT64) as tiempo_max,

    CAST(APPROX_QUANTILES(dias_visita, 100)[OFFSET(75)] AS INT64) as dias_optimo_max,
    CAST(APPROX_QUANTILES(dias_visita, 100)[OFFSET(95)] AS INT64) as dias_max,

    ROUND(APPROX_QUANTILES(stddev_hora_minima, 100)[OFFSET(25)], 1) as stddev_max_trabajador,
    ROUND(AVG(dif_horas_promedio), 1) as dif_horas_min_trabajador,
    ROUND(GREATEST(50.0, AVG(pct_llega_antes + pct_sale_despues) + 10), 1) as pct_fuera_max,

    CASE
      WHEN APPROX_QUANTILES(dias_visita, 100)[OFFSET(95)] > 15 THEN 0.50
      WHEN APPROX_QUANTILES(dias_visita, 100)[OFFSET(95)] > 10 THEN 0.65
      ELSE 0.75
    END as ratio_minimo,

    CASE
      WHEN APPROX_QUANTILES(dias_visita, 100)[OFFSET(95)] > 15 THEN 0.75
      WHEN APPROX_QUANTILES(dias_visita, 100)[OFFSET(95)] > 10 THEN 0.85
      ELSE 0.90
    END as ratio_optimo,

    CASE
      WHEN (STDDEV(tiempo_promedio) / NULLIF(AVG(tiempo_promedio), 0)) < 0.5 THEN 0.20
      WHEN (STDDEV(tiempo_promedio) / NULLIF(AVG(tiempo_promedio), 0)) < 1.0 THEN 0.15
      ELSE 0.12
    END as umbral_muy_probable,

    CASE
      WHEN (STDDEV(tiempo_promedio) / NULLIF(AVG(tiempo_promedio), 0)) < 0.5 THEN 0.15
      WHEN (STDDEV(tiempo_promedio) / NULLIF(AVG(tiempo_promedio), 0)) < 1.0 THEN 0.12
      ELSE 0.08
    END as umbral_probable,

    CASE
      WHEN (STDDEV(tiempo_promedio) / NULLIF(AVG(tiempo_promedio), 0)) < 0.5 THEN 0.10
      WHEN (STDDEV(tiempo_promedio) / NULLIF(AVG(tiempo_promedio), 0)) < 1.0 THEN 0.08
      ELSE 0.05
    END as umbral_posible,

    CASE
      WHEN APPROX_QUANTILES(dias_visita, 100)[OFFSET(95)] > 15 THEN 0.20
      WHEN APPROX_QUANTILES(dias_visita, 100)[OFFSET(95)] > 10 THEN 0.25
      ELSE 0.30
    END as peso_espacial,

    CASE
      WHEN APPROX_QUANTILES(dias_visita, 100)[OFFSET(95)] > 15 THEN 0.30
      WHEN APPROX_QUANTILES(dias_visita, 100)[OFFSET(95)] > 10 THEN 0.35
      ELSE 0.40
    END as peso_temporal,

    CASE
      WHEN APPROX_QUANTILES(dias_visita, 100)[OFFSET(95)] > 15 THEN 0.50
      WHEN APPROX_QUANTILES(dias_visita, 100)[OFFSET(95)] > 10 THEN 0.40
      ELSE 0.30
    END as peso_patron

  FROM DATOS_POC
)

SELECT
  '============================================================================' as linea1,
  'COPIA ESTE BLOQUE EN CONFIG_SIMPLE' as instruccion,
  '============================================================================' as linea2,
  '' as espacio1,

  "STRUCT(" as sql_inicio,
  "  'MI_POC' as tipo_poc,                    -- 🔧 CAMBIAR NOMBRE" as sql_1,
  "  'v2.1' as version," as sql_2,
  "  CURRENT_TIMESTAMP() as fecha_actualizacion," as sql_3,
  "  " as sql_4,
  "  9.0 as hora_apertura,                     -- 🔧 AJUSTAR HORARIOS" as sql_5,
  "  21.0 as hora_cierre," as sql_6,
  "  " as sql_7,

  CONCAT("  ", tiempo_min, " as tiempo_min,") as sql_tiempo_min,
  CONCAT("  ", tiempo_optimo_min, " as tiempo_optimo_min,") as sql_tiempo_opt_min,
  CONCAT("  ", tiempo_optimo_max, " as tiempo_optimo_max,") as sql_tiempo_opt_max,
  CONCAT("  ", tiempo_max, " as tiempo_max,") as sql_tiempo_max,
  "  " as sql_8,

  "  1 as dias_optimo_min," as sql_dias_opt_min,
  CONCAT("  ", dias_optimo_max, " as dias_optimo_max,") as sql_dias_opt_max,
  CONCAT("  ", dias_max, " as dias_max,") as sql_dias_max,
  "  " as sql_9,

  CONCAT("  ", ratio_minimo, " as ratio_minimo,") as sql_ratio_min,
  CONCAT("  ", ratio_optimo, " as ratio_optimo,") as sql_ratio_opt,
  "  " as sql_10,

  CONCAT("  ", stddev_max_trabajador, " as stddev_max_trabajador,") as sql_stddev,
  CONCAT("  ", dif_horas_min_trabajador, " as dif_horas_min_trabajador,") as sql_dif_horas,
  CONCAT("  ", pct_fuera_max, " as pct_fuera_max,") as sql_pct_fuera,
  "  " as sql_11,

  CONCAT("  ", umbral_muy_probable, " as umbral_muy_probable,") as sql_umbral_mp,
  CONCAT("  ", umbral_probable, " as umbral_probable,") as sql_umbral_p,
  CONCAT("  ", umbral_posible, " as umbral_posible,") as sql_umbral_pos,
  "  " as sql_12,

  CONCAT("  ", peso_espacial, " as peso_espacial,") as sql_peso_esp,
  CONCAT("  ", peso_temporal, " as peso_temporal,") as sql_peso_temp,
  CONCAT("  ", peso_patron, " as peso_patron,") as sql_peso_pat,
  "  " as sql_13,

  "  'Auto-calculado con helper' as notas" as sql_notas,
  ")" as sql_fin

FROM params;


-- ============================================================================
-- NOTAS DE USO
-- ============================================================================

/*
DESPUÉS DE EJECUTAR ESTE SCRIPT:

1. Revisa la tabla de parámetros sugeridos
2. Copia el bloque SQL generado
3. Pégalo en 06_MODELO_SIMPLE_V2.sql en la sección CONFIG_SIMPLE
4. Ajusta manualmente:
   - Nombre del POC (tipo_poc)
   - Horarios (hora_apertura, hora_cierre)
   - Cualquier parámetro que no tenga sentido

EJEMPLO: Si tiempo_min_calculado = 45 segundos, pero sabes que
nadie visita tu POC en menos de 5 minutos, cambia a 300 segundos.

Los valores calculados son SUGERENCIAS, no verdades absolutas.
Usa tu conocimiento del negocio para refinar.
*/
