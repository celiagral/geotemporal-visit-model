-- ============================================================================
-- ANÁLISIS DE UMBRALES ÓPTIMOS - BURGER KING
-- ============================================================================
-- PREREQUISITO: Haber ejecutado 03_MODELO_BURGER_KING.sql
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. DISTRIBUCIÓN DE PROBABILIDADES
-- ---------------------------------------------------------------------------

SELECT
  'Distribución general - Burger King' as analisis,
  COUNT(*) as n_usuarios,
  ROUND(MIN(prob_visita_final), 4) as prob_minima,
  ROUND(APPROX_QUANTILES(prob_visita_final, 100)[OFFSET(25)], 4) as percentil_25,
  ROUND(APPROX_QUANTILES(prob_visita_final, 100)[OFFSET(50)], 4) as mediana,
  ROUND(APPROX_QUANTILES(prob_visita_final, 100)[OFFSET(75)], 4) as percentil_75,
  ROUND(APPROX_QUANTILES(prob_visita_final, 100)[OFFSET(90)], 4) as percentil_90,
  ROUND(APPROX_QUANTILES(prob_visita_final, 100)[OFFSET(95)], 4) as percentil_95,
  ROUND(APPROX_QUANTILES(prob_visita_final, 100)[OFFSET(99)], 4) as percentil_99,
  ROUND(MAX(prob_visita_final), 4) as prob_maxima,
  ROUND(AVG(prob_visita_final), 4) as prob_promedio,
  ROUND(STDDEV(prob_visita_final), 4) as prob_stddev

FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_BK`;


-- ---------------------------------------------------------------------------
-- 2. DISTRIBUCIÓN POR BUCKETS
-- ---------------------------------------------------------------------------

SELECT
  CASE
    WHEN prob_visita_final >= 0.40 THEN '0.40+'
    WHEN prob_visita_final >= 0.25 THEN '0.25-0.40'
    WHEN prob_visita_final >= 0.18 THEN '0.18-0.25'
    WHEN prob_visita_final >= 0.12 THEN '0.12-0.18'
    WHEN prob_visita_final >= 0.08 THEN '0.08-0.12'
    WHEN prob_visita_final >= 0.04 THEN '0.04-0.08'
    WHEN prob_visita_final >= 0.01 THEN '0.01-0.04'
    ELSE '< 0.01'
  END as bucket_probabilidad,

  COUNT(*) as n_usuarios,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) as pct_usuarios,

  -- Acumulado
  ROUND(100.0 * SUM(COUNT(*)) OVER(ORDER BY
    CASE
      WHEN prob_visita_final >= 0.40 THEN 1
      WHEN prob_visita_final >= 0.25 THEN 2
      WHEN prob_visita_final >= 0.18 THEN 3
      WHEN prob_visita_final >= 0.12 THEN 4
      WHEN prob_visita_final >= 0.08 THEN 5
      WHEN prob_visita_final >= 0.04 THEN 6
      WHEN prob_visita_final >= 0.01 THEN 7
      ELSE 8
    END
  ) / SUM(COUNT(*)) OVER(), 2) as pct_acumulado,

  ROUND(AVG(prob_visita_final), 4) as prob_promedio,
  ROUND(AVG(tiempo_ok_promedio / 60), 1) as tiempo_ok_min_promedio,
  ROUND(AVG(dias_visita), 1) as dias_promedio,
  ROUND(AVG(ratio_horario), 3) as ratio_promedio,
  ROUND(AVG(stddev_hora_minima), 2) as stddev_hora_min_promedio

FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_BK`
GROUP BY bucket_probabilidad
ORDER BY
  CASE bucket_probabilidad
    WHEN '0.40+' THEN 1
    WHEN '0.25-0.40' THEN 2
    WHEN '0.18-0.25' THEN 3
    WHEN '0.12-0.18' THEN 4
    WHEN '0.08-0.12' THEN 5
    WHEN '0.04-0.08' THEN 6
    WHEN '0.01-0.04' THEN 7
    ELSE 8
  END;


-- ---------------------------------------------------------------------------
-- 3. CURVA DE USUARIOS POR UMBRAL (AJUSTADA PARA RESTAURANTE)
-- ---------------------------------------------------------------------------

WITH umbrales AS (
  SELECT umbral FROM UNNEST([
    0.40, 0.30, 0.25, 0.20, 0.18, 0.15, 0.12, 0.10, 0.08, 0.06, 0.04, 0.02
  ]) as umbral
)
SELECT
  u.umbral,
  COUNT(v.msisdn) as n_usuarios_recuperados,

  -- % del total
  ROUND(100.0 * COUNT(v.msisdn) / (SELECT COUNT(*) FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_BK`), 2) as pct_total,

  -- Características promedio de este grupo
  ROUND(AVG(v.prob_visita_final), 4) as prob_promedio,
  ROUND(AVG(v.tiempo_ok_promedio / 60), 1) as tiempo_ok_min_promedio,
  ROUND(AVG(v.dias_visita), 1) as dias_promedio,
  ROUND(AVG(v.ratio_horario), 3) as ratio_promedio,
  ROUND(AVG(v.stddev_hora_minima), 2) as stddev_hora_min_promedio,
  ROUND(AVG(v.dif_horas_promedio), 1) as dif_horas_promedio,

  -- Porcentaje que cumple filtro actual
  ROUND(100.0 * SUM(CASE WHEN v.tiempo_ok_promedio BETWEEN 600 AND 3600 AND v.tiempo_no_ok_promedio = 0 THEN 1 ELSE 0 END) / COUNT(*), 1) as pct_validos_filtro_actual

FROM umbrales u
LEFT JOIN `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_BK` v
  ON v.prob_visita_final >= u.umbral
GROUP BY u.umbral
ORDER BY u.umbral DESC;


-- ---------------------------------------------------------------------------
-- 4. COMPARACIÓN CON FILTRO ACTUAL
-- ---------------------------------------------------------------------------

SELECT
  'Método' as tipo,
  'N usuarios' as metrica,
  CAST(COUNT(*) AS STRING) as valor
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_BK`
WHERE tiempo_ok_promedio BETWEEN 600 AND 3600
  AND tiempo_no_ok_promedio = 0

UNION ALL

SELECT
  'Umbral 0.18 (MUY_PROBABLE)' as tipo,
  'N usuarios' as metrica,
  CAST(COUNT(*) AS STRING) as valor
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_BK`
WHERE prob_visita_final >= 0.18

UNION ALL

SELECT
  'Umbral 0.12 (PROBABLE+)' as tipo,
  'N usuarios' as metrica,
  CAST(COUNT(*) AS STRING) as valor
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_BK`
WHERE prob_visita_final >= 0.12

UNION ALL

SELECT
  'Umbral 0.08 (POSIBLE+)' as tipo,
  'N usuarios' as metrica,
  CAST(COUNT(*) AS STRING) as valor
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_BK`
WHERE prob_visita_final >= 0.08;


-- ---------------------------------------------------------------------------
-- 5. ANÁLISIS POR FRECUENCIA
-- ---------------------------------------------------------------------------

SELECT
  CASE
    WHEN dias_visita = 1 THEN '1 día'
    WHEN dias_visita BETWEEN 2 AND 4 THEN '2-4 días'
    WHEN dias_visita BETWEEN 5 AND 7 THEN '5-7 días'
    WHEN dias_visita BETWEEN 8 AND 12 THEN '8-12 días'
    ELSE '13+ días'
  END as frecuencia,

  COUNT(*) as n_usuarios,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) as pct_usuarios,

  -- Promedios
  ROUND(AVG(prob_visita_final), 4) as prob_promedio,
  ROUND(AVG(tiempo_ok_promedio / 60), 1) as tiempo_ok_min_promedio,
  ROUND(AVG(ratio_horario), 3) as ratio_promedio,
  ROUND(AVG(stddev_hora_minima), 2) as stddev_hora_min_promedio,

  -- % válidos en cada grupo
  ROUND(100.0 * SUM(CASE WHEN prob_visita_final >= 0.12 THEN 1 ELSE 0 END) / COUNT(*), 1) as pct_validos_umbral_012

FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_BK`
GROUP BY frecuencia
ORDER BY
  CASE
    WHEN dias_visita = 1 THEN 1
    WHEN dias_visita BETWEEN 2 AND 4 THEN 2
    WHEN dias_visita BETWEEN 5 AND 7 THEN 3
    WHEN dias_visita BETWEEN 8 AND 12 THEN 4
    ELSE 5
  END;


-- ---------------------------------------------------------------------------
-- 6. ANÁLISIS POR TIEMPO DE VISITA
-- ---------------------------------------------------------------------------

SELECT
  CASE
    WHEN tiempo_ok_promedio < 600 THEN '< 10 min (muy corto)'
    WHEN tiempo_ok_promedio < 1200 THEN '10-20 min (rápido)'
    WHEN tiempo_ok_promedio < 2700 THEN '20-45 min (típico)'
    WHEN tiempo_ok_promedio < 5400 THEN '45-90 min (largo)'
    ELSE '> 90 min (muy largo)'
  END as bucket_tiempo,

  COUNT(*) as n_usuarios,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) as pct_usuarios,

  ROUND(AVG(prob_visita_final), 4) as prob_promedio,
  ROUND(AVG(dias_visita), 1) as dias_promedio,
  ROUND(AVG(ratio_horario), 3) as ratio_promedio,

  -- % válidos en cada grupo
  ROUND(100.0 * SUM(CASE WHEN prob_visita_final >= 0.12 THEN 1 ELSE 0 END) / COUNT(*), 1) as pct_validos_umbral_012

FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_BK`
GROUP BY bucket_tiempo
ORDER BY
  CASE
    WHEN tiempo_ok_promedio < 600 THEN 1
    WHEN tiempo_ok_promedio < 1200 THEN 2
    WHEN tiempo_ok_promedio < 2700 THEN 3
    WHEN tiempo_ok_promedio < 5400 THEN 4
    ELSE 5
  END;


-- ---------------------------------------------------------------------------
-- 7. VALIDACIÓN MANUAL (muestra aleatoria)
-- ---------------------------------------------------------------------------

-- Grupo 1: Alta probabilidad (>= 0.18)
SELECT
  '0.18+' as grupo,
  msisdn,
  ROUND(prob_visita_final, 4) as prob,
  dias_visita,
  ROUND(tiempo_ok_promedio / 60, 1) as tiempo_ok_min,
  ROUND(ratio_horario, 3) as ratio,
  ROUND(stddev_hora_minima, 2) as stddev_hora,
  ROUND(hora_minima_promedio, 1) as hora_min_prom,
  ROUND(hora_maxima_promedio, 1) as hora_max_prom
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_BK`
WHERE prob_visita_final >= 0.18
ORDER BY RAND()
LIMIT 20

UNION ALL

-- Grupo 2: Probabilidad media-alta (0.12-0.18)
SELECT
  '0.12-0.18' as grupo,
  msisdn,
  ROUND(prob_visita_final, 4) as prob,
  dias_visita,
  ROUND(tiempo_ok_promedio / 60, 1) as tiempo_ok_min,
  ROUND(ratio_horario, 3) as ratio,
  ROUND(stddev_hora_minima, 2) as stddev_hora,
  ROUND(hora_minima_promedio, 1) as hora_min_prom,
  ROUND(hora_maxima_promedio, 1) as hora_max_prom
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_BK`
WHERE prob_visita_final >= 0.12 AND prob_visita_final < 0.18
ORDER BY RAND()
LIMIT 20

UNION ALL

-- Grupo 3: Probabilidad media (0.08-0.12)
SELECT
  '0.08-0.12' as grupo,
  msisdn,
  ROUND(prob_visita_final, 4) as prob,
  dias_visita,
  ROUND(tiempo_ok_promedio / 60, 1) as tiempo_ok_min,
  ROUND(ratio_horario, 3) as ratio,
  ROUND(stddev_hora_minima, 2) as stddev_hora,
  ROUND(hora_minima_promedio, 1) as hora_min_prom,
  ROUND(hora_maxima_promedio, 1) as hora_max_prom
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_BK`
WHERE prob_visita_final >= 0.08 AND prob_visita_final < 0.12
ORDER BY RAND()
LIMIT 20

ORDER BY grupo;


-- ============================================================================
-- INTERPRETACIÓN PARA BURGER KING
-- ============================================================================
/*

DIFERENCIAS ESPERADAS vs VOLVO:

1. DISTRIBUCIÓN DE PROBABILIDADES:
   - Volvo: Mediana ~0.08, Percentil_95 ~0.25
   - BK esperado: Mediana ~0.10-0.12 (más permisivo), Percentil_95 ~0.30

2. FRECUENCIA:
   - Volvo: Pico en 1-3 días
   - BK esperado: Pico en 2-7 días (la gente come fuera más seguido)

3. TIEMPOS:
   - Volvo: Pico en 30-90 min
   - BK esperado: Pico en 20-45 min

4. RATIO:
   - Volvo: Muy alto (0.85-0.95)
   - BK esperado: Más variable (0.70-0.90)

AJUSTE DE UMBRALES:

Si Query 3 muestra:
- 0.18 → N usuarios con características de visitantes típicos
  → Usar como VISITA_MUY_PROBABLE

- 0.12 → N usuarios razonables
  → Usar como VISITA_PROBABLE

Validar con Query 7 (muestra aleatoria) para confirmar.

*/
