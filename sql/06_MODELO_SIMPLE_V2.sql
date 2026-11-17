-- ============================================================================
-- MODELO SIMPLIFICADO V2.1
-- ============================================================================
--
-- FILOSOFÍA: Simple pero efectivo
-- - Una tabla de config (parámetros directos, nada derivado)
-- - Modelo 2-pass (elimina data leakage) ✅
-- - Pesos correctos (promedio ponderado) ✅
-- - Fácil de ajustar manualmente
-- - Helper opcional para calcular parámetros automáticamente
--
-- ============================================================================


-- ============================================================================
-- PARTE 1: TABLA DE CONFIGURACIÓN SIMPLE
-- ============================================================================
-- UNA sola tabla, parámetros directos (sin jerarquías ni derivaciones)

CREATE OR REPLACE TABLE `mo-advertising-sta.ADVERTISING_TEST.CONFIG_SIMPLE` AS
SELECT * FROM UNNEST([

  -- =========================================================================
  -- CONCESIONARIOS
  -- =========================================================================
  STRUCT(
    'CONCESIONARIO' as tipo_poc,
    'v2.1' as version,
    CURRENT_TIMESTAMP() as fecha_actualizacion,

    -- HORARIOS
    10.0 as hora_apertura,
    20.0 as hora_cierre,

    -- TIEMPOS (en segundos) - DIRECTOS
    900 as tiempo_min,          -- 15 min
    1800 as tiempo_optimo_min,  -- 30 min
    5400 as tiempo_optimo_max,  -- 90 min
    10800 as tiempo_max,        -- 3 horas

    -- FRECUENCIA (días) - DIRECTOS
    1 as dias_optimo_min,
    5 as dias_optimo_max,
    12 as dias_max,             -- Más de esto = trabajador

    -- RATIOS
    0.80 as ratio_minimo,
    0.90 as ratio_optimo,

    -- DETECCIÓN TRABAJADORES
    1.5 as stddev_max_trabajador,    -- stddev < 1.5h = patrón fijo
    6.0 as dif_horas_min_trabajador, -- >= 6h = jornada laboral
    50.0 as pct_fuera_max,           -- > 50% fuera horario = trabajador

    -- UMBRALES
    0.20 as umbral_muy_probable,
    0.15 as umbral_probable,
    0.10 as umbral_posible,

    -- PESOS (deben sumar 1.0)
    0.30 as peso_espacial,
    0.40 as peso_temporal,
    0.30 as peso_patron,

    'Concesionarios: visitas planificadas, baja frecuencia' as notas
  ),

  -- =========================================================================
  -- SUPERMERCADOS
  -- =========================================================================
  STRUCT(
    'SUPERMERCADO' as tipo_poc,
    'v2.1' as version,
    CURRENT_TIMESTAMP() as fecha_actualizacion,

    8.0 as hora_apertura,
    22.0 as hora_cierre,

    300 as tiempo_min,          -- 5 min
    600 as tiempo_optimo_min,   -- 10 min
    3600 as tiempo_optimo_max,  -- 60 min
    7200 as tiempo_max,         -- 2 horas

    1 as dias_optimo_min,
    3 as dias_optimo_max,
    18 as dias_max,

    0.50 as ratio_minimo,
    0.80 as ratio_optimo,

    1.0 as stddev_max_trabajador,
    6.0 as dif_horas_min_trabajador,
    60.0 as pct_fuera_max,

    0.18 as umbral_muy_probable,
    0.12 as umbral_probable,
    0.08 as umbral_posible,

    0.25 as peso_espacial,      -- Menos peso (vecinos)
    0.35 as peso_temporal,
    0.40 as peso_patron,        -- Más peso (trabajadores)

    'Supermercados: frecuentes, alto riesgo trabajadores'
  ),

  -- =========================================================================
  -- RESTAURANTES
  -- =========================================================================
  STRUCT(
    'RESTAURANTE' as tipo_poc,
    'v2.1' as version,
    CURRENT_TIMESTAMP() as fecha_actualizacion,

    11.0 as hora_apertura,
    23.0 as hora_cierre,

    600 as tiempo_min,
    1200 as tiempo_optimo_min,
    2700 as tiempo_optimo_max,
    5400 as tiempo_max,

    1 as dias_optimo_min,
    6 as dias_optimo_max,
    14 as dias_max,

    0.60 as ratio_minimo,
    0.85 as ratio_optimo,

    1.2 as stddev_max_trabajador,
    6.0 as dif_horas_min_trabajador,
    55.0 as pct_fuera_max,

    0.18 as umbral_muy_probable,
    0.12 as umbral_probable,
    0.08 as umbral_posible,

    0.25 as peso_espacial,
    0.40 as peso_temporal,
    0.35 as peso_patron,

    'Restaurantes: visitas medianas, frecuencia media'
  ),

  -- =========================================================================
  -- BANCOS
  -- =========================================================================
  STRUCT(
    'BANCO' as tipo_poc,
    'v2.1' as version,
    CURRENT_TIMESTAMP() as fecha_actualizacion,

    9.0 as hora_apertura,
    14.0 as hora_cierre,

    600 as tiempo_min,
    900 as tiempo_optimo_min,
    2400 as tiempo_optimo_max,
    3600 as tiempo_max,

    1 as dias_optimo_min,
    4 as dias_optimo_max,
    9 as dias_max,

    0.75 as ratio_minimo,
    0.90 as ratio_optimo,

    1.5 as stddev_max_trabajador,
    5.0 as dif_horas_min_trabajador,
    50.0 as pct_fuera_max,

    0.20 as umbral_muy_probable,
    0.15 as umbral_probable,
    0.10 as umbral_posible,

    0.30 as peso_espacial,
    0.45 as peso_temporal,
    0.25 as peso_patron,

    'Bancos: visitas cortas, horario reducido'
  )
]);


-- ============================================================================
-- VALIDACIÓN AUTOMÁTICA DE CONFIG
-- ============================================================================

WITH validacion AS (
  SELECT
    tipo_poc,

    -- Validar tiempos
    tiempo_min < tiempo_optimo_min as check_tiempo_1,
    tiempo_optimo_min < tiempo_optimo_max as check_tiempo_2,
    tiempo_optimo_max < tiempo_max as check_tiempo_3,

    -- Validar frecuencia
    dias_optimo_min < dias_optimo_max as check_dias_1,
    dias_optimo_max < dias_max as check_dias_2,

    -- Validar ratios
    ratio_minimo < ratio_optimo as check_ratio,

    -- Validar pesos suman 1.0
    ABS((peso_espacial + peso_temporal + peso_patron) - 1.0) < 0.01 as check_pesos,

    -- Validar umbrales
    umbral_posible < umbral_probable as check_umbral_1,
    umbral_probable < umbral_muy_probable as check_umbral_2

  FROM `mo-advertising-sta.ADVERTISING_TEST.CONFIG_SIMPLE`
)

SELECT
  tipo_poc,
  CASE
    WHEN NOT check_tiempo_1 THEN '❌ tiempo_min >= tiempo_optimo_min'
    WHEN NOT check_tiempo_2 THEN '❌ tiempo_optimo_min >= tiempo_optimo_max'
    WHEN NOT check_tiempo_3 THEN '❌ tiempo_optimo_max >= tiempo_max'
    WHEN NOT check_dias_1 THEN '❌ dias_optimo_min >= dias_optimo_max'
    WHEN NOT check_dias_2 THEN '❌ dias_optimo_max >= dias_max'
    WHEN NOT check_ratio THEN '❌ ratio_minimo >= ratio_optimo'
    WHEN NOT check_pesos THEN '❌ pesos no suman 1.0'
    WHEN NOT check_umbral_1 THEN '❌ umbral_posible >= umbral_probable'
    WHEN NOT check_umbral_2 THEN '❌ umbral_probable >= umbral_muy_probable'
    ELSE '✅ OK'
  END as validacion
FROM validacion;


-- ============================================================================
-- PARTE 2: FUNCIONES UDF SIMPLIFICADAS
-- ============================================================================

-- ============================================================================
-- 2.1 Probabilidad Temporal del Día
-- ============================================================================

CREATE OR REPLACE FUNCTION `mo-advertising-sta.ADVERTISING_TEST.prob_temporal_dia`(
  tiempo_ok INT64,
  ratio_ok FLOAT64,
  config STRUCT<
    tiempo_min INT64,
    tiempo_optimo_min INT64,
    tiempo_optimo_max INT64,
    tiempo_max INT64,
    ratio_minimo FLOAT64,
    ratio_optimo FLOAT64
  >
)
RETURNS FLOAT64
AS (
  -- Factor tiempo
  (CASE
    WHEN tiempo_ok < config.tiempo_min THEN 0.2
    WHEN tiempo_ok < config.tiempo_optimo_min THEN 0.6
    WHEN tiempo_ok BETWEEN config.tiempo_optimo_min AND config.tiempo_optimo_max THEN 1.0
    WHEN tiempo_ok < config.tiempo_max THEN 0.7
    ELSE 0.15
  END)
  *
  -- Factor ratio
  (CASE
    WHEN ratio_ok >= config.ratio_optimo THEN 1.0
    WHEN ratio_ok >= config.ratio_minimo THEN 0.80
    WHEN ratio_ok >= (config.ratio_minimo - 0.1) THEN 0.50
    ELSE 0.20
  END)
);


-- ============================================================================
-- 2.2 Factor Patrón Agregado (detección trabajadores)
-- ============================================================================

CREATE OR REPLACE FUNCTION `mo-advertising-sta.ADVERTISING_TEST.factor_patron`(
  stddev_hora FLOAT64,
  dif_horas_promedio FLOAT64,
  dias_total INT64,
  pct_fuera FLOAT64,
  config STRUCT<
    stddev_max_trabajador FLOAT64,
    dif_horas_min_trabajador FLOAT64,
    dias_max INT64,
    pct_fuera_max FLOAT64
  >
)
RETURNS FLOAT64
AS (
  CASE
    -- Trabajador MUY claro
    WHEN dias_total > config.dias_max
      AND stddev_hora < config.stddev_max_trabajador
      AND dif_horas_promedio >= config.dif_horas_min_trabajador
      THEN 0.05

    -- Trabajador probable
    WHEN dias_total >= (config.dias_max - 2)
      AND (stddev_hora < (config.stddev_max_trabajador * 1.5)
           OR dif_horas_promedio >= (config.dif_horas_min_trabajador + 1))
      THEN 0.15

    -- Frecuente fuera de horario
    WHEN dias_total >= (config.dias_max - 4)
      AND pct_fuera > config.pct_fuera_max
      THEN 0.40

    -- Patrón algo consistente
    WHEN stddev_hora < 3.0 AND dias_total >= 2
      THEN 0.75

    -- Visitante claro
    ELSE 1.0
  END
);


-- ============================================================================
-- 2.3 Probabilidad Final (promedio ponderado)
-- ============================================================================

CREATE OR REPLACE FUNCTION `mo-advertising-sta.ADVERTISING_TEST.prob_final`(
  comp_espacial FLOAT64,
  comp_temporal FLOAT64,
  comp_patron FLOAT64,
  peso_espacial FLOAT64,
  peso_temporal FLOAT64,
  peso_patron FLOAT64
)
RETURNS FLOAT64
AS (
  (peso_espacial * comp_espacial) +
  (peso_temporal * comp_temporal) +
  (peso_patron * comp_patron)
);


-- ============================================================================
-- PARTE 3: MODELO 2-PASS
-- ============================================================================

-- ============================================================================
-- CONFIGURAR POC
-- ============================================================================

CREATE OR REPLACE TEMP TABLE CONFIG_ACTIVA AS
SELECT *
FROM `mo-advertising-sta.ADVERTISING_TEST.CONFIG_SIMPLE`
WHERE tipo_poc = 'SUPERMERCADO';  -- 🔧 CAMBIAR SEGÚN POC


-- ============================================================================
-- PASS 1: Clasificar días (solo info del día)
-- ============================================================================

CREATE OR REPLACE TEMP TABLE DIAS_PASS1 AS
SELECT
  v.msisdn,
  v.id_ubicacion,
  v.fecha,
  v.poc,
  c.tipo_poc,

  -- Info del día
  v.tiempo_total_ok_dia as tiempo_ok,
  v.tiempo_total_no_ok_dia as tiempo_no_ok,
  SAFE_DIVIDE(v.tiempo_total_ok_dia,
              v.tiempo_total_ok_dia + v.tiempo_total_no_ok_dia) as ratio_ok,
  v.hora_minima,
  v.hora_maxima,
  v.dif_horas,
  v.PROBABILIDAD_VISITA_OK as prob_espacial,

  -- Flags fuera horario
  CASE WHEN v.hora_minima < c.hora_apertura THEN TRUE ELSE FALSE END as llega_antes,
  CASE WHEN v.hora_maxima > c.hora_cierre THEN TRUE ELSE FALSE END as sale_despues,

  -- Probabilidad temporal del día
  `mo-advertising-sta.ADVERTISING_TEST.prob_temporal_dia`(
    v.tiempo_total_ok_dia,
    SAFE_DIVIDE(v.tiempo_total_ok_dia, v.tiempo_total_ok_dia + v.tiempo_total_no_ok_dia),
    STRUCT(
      c.tiempo_min,
      c.tiempo_optimo_min,
      c.tiempo_optimo_max,
      c.tiempo_max,
      c.ratio_minimo,
      c.ratio_optimo
    )
  ) as prob_temporal_dia,

  -- Factor si ese día parece jornada laboral
  CASE
    WHEN v.dif_horas >= (c.dif_horas_min_trabajador + 2)
      AND (v.hora_minima < c.hora_apertura OR v.hora_maxima > c.hora_cierre)
      THEN 0.1
    WHEN v.dif_horas >= c.dif_horas_min_trabajador
      THEN 0.5
    WHEN v.hora_minima < c.hora_apertura OR v.hora_maxima > c.hora_cierre
      THEN 0.8
    ELSE 1.0
  END as factor_dia,

  -- Guardar config para Pass 2
  c.tiempo_min,
  c.tiempo_optimo_min,
  c.tiempo_optimo_max,
  c.tiempo_max,
  c.dias_optimo_min,
  c.dias_optimo_max,
  c.dias_max,
  c.ratio_minimo,
  c.ratio_optimo,
  c.stddev_max_trabajador,
  c.dif_horas_min_trabajador,
  c.pct_fuera_max,
  c.umbral_muy_probable,
  c.umbral_probable,
  c.umbral_posible,
  c.peso_espacial,
  c.peso_temporal,
  c.peso_patron

FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_UBICACION_GEO_TILES_CELIA_ISA_V2` v
CROSS JOIN CONFIG_ACTIVA c
WHERE v.poc = 'NORGES_SEAFOOD-SALMON_AGO26'  -- 🔧 CAMBIAR SEGÚN CAMPAÑA
  AND v.PERIODO = 'CAMPAIGN'
  AND v.tiempo_total_ok_dia > 0;


-- Clasificación preliminar
CREATE OR REPLACE TEMP TABLE DIAS_CLASIFICADOS_PASS1 AS
SELECT
  *,
  CASE
    WHEN (prob_temporal_dia * factor_dia) >= 0.4
      AND tiempo_ok BETWEEN tiempo_optimo_min AND tiempo_max
      THEN 'VALIDO'
    ELSE 'DESCARTADO'
  END as clasificacion_pass1
FROM DIAS_PASS1;


-- ============================================================================
-- ESTADÍSTICAS LIMPIAS (solo días válidos de Pass 1)
-- ============================================================================

CREATE OR REPLACE TEMP TABLE PATRON_LIMPIO AS
SELECT
  msisdn,
  id_ubicacion,

  -- Frecuencia (solo días válidos)
  COUNT(DISTINCT fecha) as dias_total,

  -- Patrón horario (solo días válidos)
  STDDEV(hora_minima) as stddev_hora_minima,
  AVG(dif_horas) as dif_horas_promedio,

  -- % fuera de horario
  100.0 * SUM(CASE WHEN llega_antes OR sale_despues THEN 1 ELSE 0 END) / COUNT(*) as pct_fuera,

  -- Config (tomar max porque es igual para todos)
  MAX(tiempo_min) as tiempo_min,
  MAX(tiempo_optimo_min) as tiempo_optimo_min,
  MAX(tiempo_optimo_max) as tiempo_optimo_max,
  MAX(tiempo_max) as tiempo_max,
  MAX(dias_optimo_min) as dias_optimo_min,
  MAX(dias_optimo_max) as dias_optimo_max,
  MAX(dias_max) as dias_max,
  MAX(ratio_minimo) as ratio_minimo,
  MAX(ratio_optimo) as ratio_optimo,
  MAX(stddev_max_trabajador) as stddev_max_trabajador,
  MAX(dif_horas_min_trabajador) as dif_horas_min_trabajador,
  MAX(pct_fuera_max) as pct_fuera_max,
  MAX(umbral_muy_probable) as umbral_muy_probable,
  MAX(umbral_probable) as umbral_probable,
  MAX(umbral_posible) as umbral_posible,
  MAX(peso_espacial) as peso_espacial,
  MAX(peso_temporal) as peso_temporal,
  MAX(peso_patron) as peso_patron

FROM DIAS_CLASIFICADOS_PASS1
WHERE clasificacion_pass1 = 'VALIDO'  -- ✅ SOLO DÍAS BUENOS
GROUP BY msisdn, id_ubicacion;


-- ============================================================================
-- PASS 2: Re-evaluar con patrón limpio
-- ============================================================================

CREATE OR REPLACE TABLE `mo-advertising-sta.ADVERTISING_TEST.RESULTADOS_SIMPLE` AS
SELECT
  d.msisdn,
  d.id_ubicacion,
  d.fecha,
  d.poc,
  d.tipo_poc,

  -- Info del día
  d.tiempo_ok,
  ROUND(d.tiempo_ok / 60, 1) as tiempo_ok_min,
  d.ratio_ok,
  d.hora_minima,
  d.hora_maxima,
  d.dif_horas,
  d.llega_antes,
  d.sale_despues,

  -- Patrón del usuario (limpio)
  COALESCE(p.dias_total, 0) as dias_total,
  COALESCE(p.stddev_hora_minima, 999) as stddev_hora,
  COALESCE(p.dif_horas_promedio, d.dif_horas) as dif_horas_prom,
  COALESCE(p.pct_fuera, 0) as pct_fuera,

  -- Componentes de probabilidad
  d.prob_espacial,

  (d.prob_temporal_dia * d.factor_dia) as prob_temporal,

  (CASE
    WHEN COALESCE(p.dias_total, 0) BETWEEN d.dias_optimo_min AND d.dias_optimo_max THEN 1.0
    WHEN COALESCE(p.dias_total, 0) < d.dias_optimo_min THEN 0.6
    WHEN COALESCE(p.dias_total, 0) < d.dias_max THEN 0.7
    ELSE 0.1
  END) *
  `mo-advertising-sta.ADVERTISING_TEST.factor_patron`(
    COALESCE(p.stddev_hora_minima, 999),
    COALESCE(p.dif_horas_promedio, d.dif_horas),
    COALESCE(p.dias_total, 0),
    COALESCE(p.pct_fuera, 0),
    STRUCT(
      d.stddev_max_trabajador,
      d.dif_horas_min_trabajador,
      d.dias_max,
      d.pct_fuera_max
    )
  ) as prob_patron,

  -- Probabilidad final
  `mo-advertising-sta.ADVERTISING_TEST.prob_final`(
    d.prob_espacial,
    (d.prob_temporal_dia * d.factor_dia),
    (CASE
      WHEN COALESCE(p.dias_total, 0) BETWEEN d.dias_optimo_min AND d.dias_optimo_max THEN 1.0
      WHEN COALESCE(p.dias_total, 0) < d.dias_optimo_min THEN 0.6
      WHEN COALESCE(p.dias_total, 0) < d.dias_max THEN 0.7
      ELSE 0.1
    END) *
    `mo-advertising-sta.ADVERTISING_TEST.factor_patron`(
      COALESCE(p.stddev_hora_minima, 999),
      COALESCE(p.dif_horas_promedio, d.dif_horas),
      COALESCE(p.dias_total, 0),
      COALESCE(p.pct_fuera, 0),
      STRUCT(
        d.stddev_max_trabajador,
        d.dif_horas_min_trabajador,
        d.dias_max,
        d.pct_fuera_max
      )
    ),
    d.peso_espacial,
    d.peso_temporal,
    d.peso_patron
  ) as prob_final,

  -- Clasificación
  CASE
    WHEN `mo-advertising-sta.ADVERTISING_TEST.prob_final`(
      d.prob_espacial,
      (d.prob_temporal_dia * d.factor_dia),
      (CASE
        WHEN COALESCE(p.dias_total, 0) BETWEEN d.dias_optimo_min AND d.dias_optimo_max THEN 1.0
        WHEN COALESCE(p.dias_total, 0) < d.dias_optimo_min THEN 0.6
        WHEN COALESCE(p.dias_total, 0) < d.dias_max THEN 0.7
        ELSE 0.1
      END) *
      `mo-advertising-sta.ADVERTISING_TEST.factor_patron`(
        COALESCE(p.stddev_hora_minima, 999),
        COALESCE(p.dif_horas_promedio, d.dif_horas),
        COALESCE(p.dias_total, 0),
        COALESCE(p.pct_fuera, 0),
        STRUCT(
          d.stddev_max_trabajador,
          d.dif_horas_min_trabajador,
          d.dias_max,
          d.pct_fuera_max
        )
      ),
      d.peso_espacial,
      d.peso_temporal,
      d.peso_patron
    ) >= d.umbral_muy_probable THEN 'VISITA_MUY_PROBABLE'

    WHEN `mo-advertising-sta.ADVERTISING_TEST.prob_final`(
      d.prob_espacial,
      (d.prob_temporal_dia * d.factor_dia),
      (CASE
        WHEN COALESCE(p.dias_total, 0) BETWEEN d.dias_optimo_min AND d.dias_optimo_max THEN 1.0
        WHEN COALESCE(p.dias_total, 0) < d.dias_optimo_min THEN 0.6
        WHEN COALESCE(p.dias_total, 0) < d.dias_max THEN 0.7
        ELSE 0.1
      END) *
      `mo-advertising-sta.ADVERTISING_TEST.factor_patron`(
        COALESCE(p.stddev_hora_minima, 999),
        COALESCE(p.dif_horas_promedio, d.dif_horas),
        COALESCE(p.dias_total, 0),
        COALESCE(p.pct_fuera, 0),
        STRUCT(
          d.stddev_max_trabajador,
          d.dif_horas_min_trabajador,
          d.dias_max,
          d.pct_fuera_max
        )
      ),
      d.peso_espacial,
      d.peso_temporal,
      d.peso_patron
    ) >= d.umbral_probable THEN 'VISITA_PROBABLE'

    WHEN `mo-advertising-sta.ADVERTISING_TEST.prob_final`(
      d.prob_espacial,
      (d.prob_temporal_dia * d.factor_dia),
      (CASE
        WHEN COALESCE(p.dias_total, 0) BETWEEN d.dias_optimo_min AND d.dias_optimo_max THEN 1.0
        WHEN COALESCE(p.dias_total, 0) < d.dias_optimo_min THEN 0.6
        WHEN COALESCE(p.dias_total, 0) < d.dias_max THEN 0.7
        ELSE 0.1
      END) *
      `mo-advertising-sta.ADVERTISING_TEST.factor_patron`(
        COALESCE(p.stddev_hora_minima, 999),
        COALESCE(p.dif_horas_promedio, d.dif_horas),
        COALESCE(p.dias_total, 0),
        COALESCE(p.pct_fuera, 0),
        STRUCT(
          d.stddev_max_trabajador,
          d.dif_horas_min_trabajador,
          d.dias_max,
          d.pct_fuera_max
        )
      ),
      d.peso_espacial,
      d.peso_temporal,
      d.peso_patron
    ) >= d.umbral_posible THEN 'VISITA_POSIBLE'

    ELSE 'DESCARTADO'
  END as clasificacion

FROM DIAS_CLASIFICADOS_PASS1 d
LEFT JOIN PATRON_LIMPIO p
  ON d.msisdn = p.msisdn
  AND d.id_ubicacion = p.id_ubicacion;


-- ============================================================================
-- PARTE 4: QUERIES DE VALIDACIÓN
-- ============================================================================

-- Resumen por clasificación
SELECT
  tipo_poc,
  clasificacion,
  COUNT(*) as n_visitas,
  COUNT(DISTINCT msisdn) as n_usuarios,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) as pct,

  ROUND(AVG(prob_final), 4) as prob_prom,
  ROUND(AVG(prob_espacial), 3) as esp_prom,
  ROUND(AVG(prob_temporal), 3) as temp_prom,
  ROUND(AVG(prob_patron), 3) as pat_prom,

  ROUND(AVG(tiempo_ok_min), 1) as tiempo_prom_min,
  ROUND(AVG(dias_total), 1) as dias_prom

FROM `mo-advertising-sta.ADVERTISING_TEST.RESULTADOS_SIMPLE`
GROUP BY tipo_poc, clasificacion
ORDER BY
  CASE clasificacion
    WHEN 'VISITA_MUY_PROBABLE' THEN 1
    WHEN 'VISITA_PROBABLE' THEN 2
    WHEN 'VISITA_POSIBLE' THEN 3
    ELSE 4
  END;


-- Top visitas para validación
SELECT
  msisdn,
  fecha,
  tiempo_ok_min,
  dias_total,
  ROUND(stddev_hora, 2) as stddev_h,
  ROUND(prob_espacial, 3) as p_esp,
  ROUND(prob_temporal, 3) as p_temp,
  ROUND(prob_patron, 3) as p_pat,
  ROUND(prob_final, 4) as p_final,
  clasificacion

FROM `mo-advertising-sta.ADVERTISING_TEST.RESULTADOS_SIMPLE`
WHERE clasificacion IN ('VISITA_MUY_PROBABLE', 'VISITA_PROBABLE')
ORDER BY prob_final DESC
LIMIT 100;


-- ============================================================================
-- FIN DEL MODELO SIMPLE
-- ============================================================================

/*
============================================================================
CÓMO USAR
============================================================================

PASO 1: Ajustar CONFIG_SIMPLE (arriba)
  - Añade tu POC o ajusta uno existente
  - Parámetros directos, fácil de entender

PASO 2: Cambiar líneas de configuración
  - Línea 446: WHERE tipo_poc = 'TU_POC'
  - Línea 564: WHERE v.poc = 'TU_CAMPAÑA'

PASO 3: Ejecutar todo el script

PASO 4: Ver resultados en RESULTADOS_SIMPLE

============================================================================
AÑADIR NUEVO POC
============================================================================

INSERT INTO `mo-advertising-sta.ADVERTISING_TEST.CONFIG_SIMPLE`
VALUES (
  'MI_POC',                -- tipo_poc
  'v2.1',                  -- version
  CURRENT_TIMESTAMP(),     -- fecha_actualizacion

  9.0,                     -- hora_apertura
  21.0,                    -- hora_cierre

  600,                     -- tiempo_min (10 min)
  1200,                    -- tiempo_optimo_min (20 min)
  3600,                    -- tiempo_optimo_max (60 min)
  7200,                    -- tiempo_max (2 horas)

  1,                       -- dias_optimo_min
  4,                       -- dias_optimo_max
  12,                      -- dias_max

  0.70,                    -- ratio_minimo
  0.85,                    -- ratio_optimo

  1.3,                     -- stddev_max_trabajador
  6.0,                     -- dif_horas_min_trabajador
  55.0,                    -- pct_fuera_max

  0.18,                    -- umbral_muy_probable
  0.12,                    -- umbral_probable
  0.08,                    -- umbral_posible

  0.30,                    -- peso_espacial
  0.40,                    -- peso_temporal
  0.30,                    -- peso_patron

  'Notas sobre mi POC'
);

============================================================================
AJUSTAR POC EXISTENTE
============================================================================

UPDATE `mo-advertising-sta.ADVERTISING_TEST.CONFIG_SIMPLE`
SET
  tiempo_optimo_min = 1500,        -- Cambiar a 25 min
  peso_patron = 0.45,              -- Más énfasis en patrón
  version = 'v2.1.1',              -- Nueva versión
  fecha_actualizacion = CURRENT_TIMESTAMP()
WHERE tipo_poc = 'SUPERMERCADO';

============================================================================
USAR AUTO-CÁLCULO (OPCIONAL)
============================================================================

Si quieres calcular parámetros automáticamente:
Ver archivo: 07_HELPER_CALCULO_PARAMETROS.sql

Ese script calcula percentiles y te sugiere valores.
Luego copias esos valores a CONFIG_SIMPLE.

*/
