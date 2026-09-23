-- ============================================================================
-- ANÁLISIS DE UMBRALES ÓPTIMOS
-- ============================================================================
-- Este script te ayuda a encontrar los umbrales correctos para clasificar
-- visitas según la probabilidad final del modelo.
--
-- PREREQUISITO: Haber ejecutado 03_MODELO.sql
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. DISTRIBUCIÓN DE PROBABILIDADES
-- ---------------------------------------------------------------------------
-- Ver cómo se distribuyen las probabilidades finales

SELECT
  'Distribución general' as analisis,
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

FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_VOLVO`;


-- ---------------------------------------------------------------------------
-- 2. DISTRIBUCIÓN POR BUCKETS (ver dónde se concentran los datos)
-- ---------------------------------------------------------------------------

SELECT
  CASE
    WHEN prob_visita_final >= 0.50 THEN '0.50+'
    WHEN prob_visita_final >= 0.30 THEN '0.30-0.50'
    WHEN prob_visita_final >= 0.20 THEN '0.20-0.30'
    WHEN prob_visita_final >= 0.15 THEN '0.15-0.20'
    WHEN prob_visita_final >= 0.10 THEN '0.10-0.15'
    WHEN prob_visita_final >= 0.05 THEN '0.05-0.10'
    WHEN prob_visita_final >= 0.01 THEN '0.01-0.05'
    ELSE '< 0.01'
  END as bucket_probabilidad,

  COUNT(*) as n_usuarios,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) as pct_usuarios,

  -- Acumulado
  ROUND(100.0 * SUM(COUNT(*)) OVER(ORDER BY
    CASE
      WHEN prob_visita_final >= 0.50 THEN 1
      WHEN prob_visita_final >= 0.30 THEN 2
      WHEN prob_visita_final >= 0.20 THEN 3
      WHEN prob_visita_final >= 0.15 THEN 4
      WHEN prob_visita_final >= 0.10 THEN 5
      WHEN prob_visita_final >= 0.05 THEN 6
      WHEN prob_visita_final >= 0.01 THEN 7
      ELSE 8
    END
  ) / SUM(COUNT(*)) OVER(), 2) as pct_acumulado,

  ROUND(AVG(prob_visita_final), 4) as prob_promedio,
  ROUND(AVG(tiempo_ok_promedio / 60), 1) as tiempo_ok_min_promedio,
  ROUND(AVG(dias_visita), 1) as dias_promedio,
  ROUND(AVG(ratio_horario), 3) as ratio_promedio

FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_VOLVO`
GROUP BY bucket_probabilidad
ORDER BY
  CASE bucket_probabilidad
    WHEN '0.50+' THEN 1
    WHEN '0.30-0.50' THEN 2
    WHEN '0.20-0.30' THEN 3
    WHEN '0.15-0.20' THEN 4
    WHEN '0.10-0.15' THEN 5
    WHEN '0.05-0.10' THEN 6
    WHEN '0.01-0.05' THEN 7
    ELSE 8
  END;


-- ---------------------------------------------------------------------------
-- 3. CURVA DE USUARIOS POR UMBRAL
-- ---------------------------------------------------------------------------
-- Para cada posible umbral, cuántos usuarios recuperas

WITH umbrales AS (
  SELECT umbral FROM UNNEST([
    0.50, 0.40, 0.30, 0.25, 0.20, 0.18, 0.15, 0.12, 0.10, 0.08, 0.05, 0.03, 0.01
  ]) as umbral
)
SELECT
  u.umbral,
  COUNT(v.msisdn) as n_usuarios_recuperados,

  -- % del total
  ROUND(100.0 * COUNT(v.msisdn) / (SELECT COUNT(*) FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_VOLVO`), 2) as pct_total,

  -- Características promedio de este grupo
  ROUND(AVG(v.prob_visita_final), 4) as prob_promedio,
  ROUND(AVG(v.tiempo_ok_promedio / 60), 1) as tiempo_ok_min_promedio,
  ROUND(AVG(v.dias_visita), 1) as dias_promedio,
  ROUND(AVG(v.ratio_horario), 3) as ratio_promedio,
  ROUND(AVG(v.stddev_hora_minima), 2) as stddev_hora_min_promedio,

  -- Porcentaje que cumple filtro actual (para comparar)
  ROUND(100.0 * SUM(CASE WHEN v.tiempo_ok_promedio BETWEEN 1800 AND 5400 AND v.tiempo_no_ok_promedio = 0 THEN 1 ELSE 0 END) / COUNT(*), 1) as pct_validos_filtro_actual

FROM umbrales u
LEFT JOIN `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_VOLVO` v
  ON v.prob_visita_final >= u.umbral
GROUP BY u.umbral
ORDER BY u.umbral DESC;


-- ---------------------------------------------------------------------------
-- 4. ANÁLISIS DE SENSIBILIDAD (si tienes ground truth)
-- ---------------------------------------------------------------------------
-- Si tienes datos de ventas reales o validación manual, cruza aquí

/*
-- EJEMPLO: Si tienes tabla de ventas reales
WITH ventas_reales AS (
  SELECT DISTINCT msisdn
  FROM `mo-advertising-sta.ADVERTISING_TEST.VENTAS_VOLVO_REALES`
  WHERE fecha_venta BETWEEN '2026-04-01' AND '2026-04-30'
),
umbrales AS (
  SELECT umbral FROM UNNEST([
    0.50, 0.40, 0.30, 0.25, 0.20, 0.18, 0.15, 0.12, 0.10, 0.08, 0.05
  ]) as umbral
)
SELECT
  u.umbral,

  -- True Positives: modelo dice SÍ y compró
  COUNT(CASE WHEN v.prob_visita_final >= u.umbral AND vr.msisdn IS NOT NULL THEN 1 END) as TP,

  -- False Positives: modelo dice SÍ pero NO compró
  COUNT(CASE WHEN v.prob_visita_final >= u.umbral AND vr.msisdn IS NULL THEN 1 END) as FP,

  -- False Negatives: modelo dice NO pero SÍ compró
  COUNT(CASE WHEN v.prob_visita_final < u.umbral AND vr.msisdn IS NOT NULL THEN 1 END) as FN,

  -- True Negatives: modelo dice NO y NO compró
  COUNT(CASE WHEN v.prob_visita_final < u.umbral AND vr.msisdn IS NULL THEN 1 END) as TN,

  -- Métricas
  ROUND(100.0 * COUNT(CASE WHEN v.prob_visita_final >= u.umbral AND vr.msisdn IS NOT NULL THEN 1 END) /
    NULLIF(COUNT(CASE WHEN vr.msisdn IS NOT NULL THEN 1 END), 0), 2) as recall,

  ROUND(100.0 * COUNT(CASE WHEN v.prob_visita_final >= u.umbral AND vr.msisdn IS NOT NULL THEN 1 END) /
    NULLIF(COUNT(CASE WHEN v.prob_visita_final >= u.umbral THEN 1 END), 0), 2) as precision,

  ROUND(2 *
    (100.0 * COUNT(CASE WHEN v.prob_visita_final >= u.umbral AND vr.msisdn IS NOT NULL THEN 1 END) /
      NULLIF(COUNT(CASE WHEN vr.msisdn IS NOT NULL THEN 1 END), 0)) *
    (100.0 * COUNT(CASE WHEN v.prob_visita_final >= u.umbral AND vr.msisdn IS NOT NULL THEN 1 END) /
      NULLIF(COUNT(CASE WHEN v.prob_visita_final >= u.umbral THEN 1 END), 0)) /
    NULLIF((100.0 * COUNT(CASE WHEN v.prob_visita_final >= u.umbral AND vr.msisdn IS NOT NULL THEN 1 END) /
      NULLIF(COUNT(CASE WHEN vr.msisdn IS NOT NULL THEN 1 END), 0)) +
    (100.0 * COUNT(CASE WHEN v.prob_visita_final >= u.umbral AND vr.msisdn IS NOT NULL THEN 1 END) /
      NULLIF(COUNT(CASE WHEN v.prob_visita_final >= u.umbral THEN 1 END), 0)), 0)
  , 2) as f1_score

FROM umbrales u
CROSS JOIN `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_VOLVO` v
LEFT JOIN ventas_reales vr ON v.msisdn = vr.msisdn
GROUP BY u.umbral
ORDER BY f1_score DESC;
*/


-- ---------------------------------------------------------------------------
-- 5. VALIDACIÓN MANUAL (muestra para revisar)
-- ---------------------------------------------------------------------------
-- Para cada rango de probabilidad, extrae 20 usuarios aleatorios para validar manualmente

-- Grupo 1: Alta probabilidad (>= 0.20)
SELECT
  '0.20+' as grupo,
  msisdn,
  ROUND(prob_visita_final, 4) as prob,
  dias_visita,
  ROUND(tiempo_ok_promedio / 60, 1) as tiempo_ok_min,
  ROUND(ratio_horario, 3) as ratio,
  ROUND(stddev_hora_minima, 2) as stddev_hora
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_VOLVO`
WHERE prob_visita_final >= 0.20
ORDER BY RAND()
LIMIT 20

UNION ALL

-- Grupo 2: Probabilidad media-alta (0.15-0.20)
SELECT
  '0.15-0.20' as grupo,
  msisdn,
  ROUND(prob_visita_final, 4) as prob,
  dias_visita,
  ROUND(tiempo_ok_promedio / 60, 1) as tiempo_ok_min,
  ROUND(ratio_horario, 3) as ratio,
  ROUND(stddev_hora_minima, 2) as stddev_hora
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_VOLVO`
WHERE prob_visita_final >= 0.15 AND prob_visita_final < 0.20
ORDER BY RAND()
LIMIT 20

UNION ALL

-- Grupo 3: Probabilidad media (0.10-0.15)
SELECT
  '0.10-0.15' as grupo,
  msisdn,
  ROUND(prob_visita_final, 4) as prob,
  dias_visita,
  ROUND(tiempo_ok_promedio / 60, 1) as tiempo_ok_min,
  ROUND(ratio_horario, 3) as ratio,
  ROUND(stddev_hora_minima, 2) as stddev_hora
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_VOLVO`
WHERE prob_visita_final >= 0.10 AND prob_visita_final < 0.15
ORDER BY RAND()
LIMIT 20

UNION ALL

-- Grupo 4: Probabilidad baja (0.05-0.10)
SELECT
  '0.05-0.10' as grupo,
  msisdn,
  ROUND(prob_visita_final, 4) as prob,
  dias_visita,
  ROUND(tiempo_ok_promedio / 60, 1) as tiempo_ok_min,
  ROUND(ratio_horario, 3) as ratio,
  ROUND(stddev_hora_minima, 2) as stddev_hora
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_VOLVO`
WHERE prob_visita_final >= 0.05 AND prob_visita_final < 0.10
ORDER BY RAND()
LIMIT 20

ORDER BY grupo;


-- ---------------------------------------------------------------------------
-- 6. RECOMENDACIÓN SEGÚN OBJETIVO
-- ---------------------------------------------------------------------------

SELECT
  'Si quieres ~77K usuarios (target esperado)' as objetivo,
  umbral,
  n_usuarios as usuarios_recuperados
FROM (
  SELECT
    0.15 as umbral,
    COUNT(*) as n_usuarios
  FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_VOLVO`
  WHERE prob_visita_final >= 0.15
)

UNION ALL

SELECT
  'Si quieres maximizar recall (más usuarios, menos precisión)' as objetivo,
  0.10 as umbral,
  COUNT(*) as usuarios_recuperados
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_VOLVO`
WHERE prob_visita_final >= 0.10

UNION ALL

SELECT
  'Si quieres maximizar precision (menos usuarios, más confianza)' as objetivo,
  0.20 as umbral,
  COUNT(*) as usuarios_recuperados
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_VOLVO`
WHERE prob_visita_final >= 0.20;


-- ============================================================================
-- INTERPRETACIÓN DE RESULTADOS
-- ============================================================================
/*

1. DISTRIBUCIÓN GENERAL:
   - Si la mediana es ~0.08 → la mayoría tiene probabilidades bajas
   - Si percentil_95 es ~0.25 → solo el 5% top tiene prob > 0.25
   → Ajusta umbrales según esta distribución

2. DISTRIBUCIÓN POR BUCKETS:
   - Busca dónde está la "rodilla" de la curva
   - Ejemplo: si 0.15-0.20 tiene 50K usuarios pero 0.10-0.15 tiene 200K
   → 0.15 es un buen corte (evitas inflar con casos dudosos)

3. CURVA DE USUARIOS POR UMBRAL:
   - Encuentra el umbral que te da ~77K usuarios
   - Revisa las características de ese grupo (ratio, stddev, etc.)
   - ¿Parecen visitantes o trabajadores?

4. SI TIENES GROUND TRUTH:
   - Busca el umbral con mejor F1-score
   - O prioriza recall si prefieres no perder visitantes
   - O prioriza precision si prefieres evitar trabajadores

5. VALIDACIÓN MANUAL:
   - Revisa los 20 usuarios de cada grupo
   - ¿Los de 0.20+ son claramente visitantes?
   - ¿Los de 0.05-0.10 son claramente trabajadores?
   → Ajusta umbrales según tu criterio

*/


-- ============================================================================
-- FIN DEL ANÁLISIS DE UMBRALES
-- ============================================================================
