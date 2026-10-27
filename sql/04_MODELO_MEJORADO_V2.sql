-- ============================================================================
-- MODELO PROBABILÍSTICO MEJORADO - VERSIÓN 2.0
-- ============================================================================
--
-- MEJORAS CRÍTICAS vs Versión anterior:
-- ✅ Modelo 2-PASS: elimina data leakage (estadísticas solo de días válidos)
-- ✅ Pesos corregidos: promedio ponderado en vez de POWER incorrecto
-- ✅ Validación automática de parámetros
-- ✅ Perfiles base + especialización por POC (jerarquía)
-- ✅ Trazabilidad: config_version, fecha_actualizacion
-- ✅ STRUCT para agrupar parámetros relacionados
-- ✅ Parámetros derivados automáticamente
--
-- ============================================================================


-- ============================================================================
-- PARTE 1: PERFILES BASE DE NEGOCIO (3 categorías fundamentales)
-- ============================================================================

CREATE OR REPLACE TABLE `mo-advertising-sta.ADVERTISING_TEST.PERFILES_NEGOCIO_BASE` AS
SELECT * FROM UNNEST([

  -- PERFIL 1: Compras planificadas (visitas largas, infrecuentes)
  STRUCT(
    'COMPRA_PLANIFICADA' as perfil,
    'Visitas largas y planificadas: concesionarios, bancos, inmobiliarias' as descripcion,

    -- Comportamiento típico
    3600 as tiempo_base_segundos,        -- 1 hora típica
    3 as frecuencia_base_dias,           -- 3 días típico
    'LOW' as riesgo_trabajadores,        -- Bajo riesgo de trabajadores (poca gente trabaja ahí)
    0.85 as strictness,                  -- Muy estricto (0.0=permisivo, 1.0=estricto)

    -- Factores de tolerancia (multiplicadores)
    0.25 as tolerancia_tiempo_min,       -- 25% del base = mínimo válido
    3.0 as tolerancia_tiempo_max,        -- 300% del base = máximo válido
    0.5 as tolerancia_tiempo_optimo,     -- 50% = inicio óptimo
    1.5 as tolerancia_tiempo_optimo_max, -- 150% = fin óptimo

    0.3 as tolerancia_freq_min,          -- 30% del base
    3.0 as tolerancia_freq_max           -- 300% del base
  ),

  -- PERFIL 2: Compras rutinarias (visitas medianas, más frecuentes)
  STRUCT(
    'COMPRA_RUTINARIA' as perfil,
    'Visitas rutinarias regulares: supermercados, farmacias' as descripcion,

    1800 as tiempo_base_segundos,        -- 30 min típica
    2 as frecuencia_base_dias,           -- 2 días típico (más frecuente)
    'HIGH' as riesgo_trabajadores,       -- Alto riesgo (muchos trabajadores)
    0.50 as strictness,                  -- Más permisivo

    0.3 as tolerancia_tiempo_min,
    4.0 as tolerancia_tiempo_max,
    0.6 as tolerancia_tiempo_optimo,
    2.0 as tolerancia_tiempo_optimo_max,

    0.5 as tolerancia_freq_min,
    7.0 as tolerancia_freq_max
  ),

  -- PERFIL 3: Ocio (visitas variadas, frecuencia media)
  STRUCT(
    'OCIO' as perfil,
    'Visitas de ocio: restaurantes, cines, centros comerciales' as descripcion,

    2700 as tiempo_base_segundos,        -- 45 min típica
    4 as frecuencia_base_dias,           -- 4 días típico
    'MEDIUM' as riesgo_trabajadores,     -- Riesgo medio
    0.65 as strictness,                  -- Moderadamente estricto

    0.4 as tolerancia_tiempo_min,
    3.5 as tolerancia_tiempo_max,
    0.7 as tolerancia_tiempo_optimo,
    1.8 as tolerancia_tiempo_optimo_max,

    0.25 as tolerancia_freq_min,
    4.0 as tolerancia_freq_max
  )
]);


-- ============================================================================
-- PARTE 2: CONFIGURACIÓN ESPECÍFICA POR TIPO DE POC
-- ============================================================================
-- Hereda del perfil base + ajustes específicos

CREATE OR REPLACE TABLE `mo-advertising-sta.ADVERTISING_TEST.CONFIG_POC_V2` AS
SELECT * FROM UNNEST([

  -- CONCESIONARIOS
  STRUCT(
    'CONCESIONARIO' as tipo_poc,
    'COMPRA_PLANIFICADA' as perfil_base,
    'v2.0' as config_version,
    CURRENT_TIMESTAMP() as fecha_actualizacion,

    -- Horarios específicos
    10.0 as hora_apertura,
    20.0 as hora_cierre,

    -- Ajustes sobre el perfil base (multiplicadores)
    1.0 as ajuste_tiempo,        -- Sin ajuste (usa tiempo_base del perfil)
    1.0 as ajuste_frecuencia,    -- Sin ajuste

    -- Patrón horario (detección trabajadores)
    STRUCT(
      1.5 as stddev_max,           -- < 1.5h stddev = patrón fijo (trabajador)
      3.0 as stddev_visitante_min, -- >= 3h stddev = patrón variable (visitante)
      6.0 as dif_horas_min,        -- >= 6h promedio = jornada laboral
      50.0 as pct_fuera_horario_max -- > 50% días fuera horario = trabajador
    ) as patron_trabajador,

    -- Ratios
    STRUCT(
      0.80 as minimo,
      0.90 as optimo
    ) as ratio,

    -- Umbrales de clasificación
    STRUCT(
      0.20 as muy_probable,
      0.15 as probable,
      0.10 as posible,
      0.05 as dudoso
    ) as umbrales,

    -- Pesos (suma = 1.0 para promedio ponderado)
    STRUCT(
      0.30 as espacial,
      0.40 as temporal,
      0.30 as patron
    ) as pesos,

    'Concesionarios: visitas planificadas, baja frecuencia' as notas
  ),

  -- SUPERMERCADOS
  STRUCT(
    'SUPERMERCADO' as tipo_poc,
    'COMPRA_RUTINARIA' as perfil_base,
    'v2.0' as config_version,
    CURRENT_TIMESTAMP() as fecha_actualizacion,

    8.0 as hora_apertura,
    22.0 as hora_cierre,

    1.2 as ajuste_tiempo,        -- 20% más largo que base (36 min típico)
    1.0 as ajuste_frecuencia,

    STRUCT(
      1.0 as stddev_max,
      3.0 as stddev_visitante_min,
      6.0 as dif_horas_min,
      60.0 as pct_fuera_horario_max
    ) as patron_trabajador,

    STRUCT(
      0.50 as minimo,
      0.80 as optimo
    ) as ratio,

    STRUCT(
      0.18 as muy_probable,
      0.12 as probable,
      0.08 as posible,
      0.04 as dudoso
    ) as umbrales,

    STRUCT(
      0.25 as espacial,    -- Menos peso espacial (vecinos)
      0.35 as temporal,
      0.40 as patron       -- Más peso en patrón (detectar trabajadores)
    ) as pesos,

    'Supermercados: frecuentes, alto riesgo trabajadores' as notas
  ),

  -- RESTAURANTES
  STRUCT(
    'RESTAURANTE' as tipo_poc,
    'OCIO' as perfil_base,
    'v2.0' as config_version,
    CURRENT_TIMESTAMP() as fecha_actualizacion,

    11.0 as hora_apertura,
    23.0 as hora_cierre,

    0.8 as ajuste_tiempo,        -- 20% más corto (36 min típico)
    1.5 as ajuste_frecuencia,    -- 50% más frecuente

    STRUCT(
      1.2 as stddev_max,
      3.0 as stddev_visitante_min,
      6.0 as dif_horas_min,
      55.0 as pct_fuera_horario_max
    ) as patron_trabajador,

    STRUCT(
      0.60 as minimo,
      0.85 as optimo
    ) as ratio,

    STRUCT(
      0.18 as muy_probable,
      0.12 as probable,
      0.08 as posible,
      0.04 as dudoso
    ) as umbrales,

    STRUCT(
      0.25 as espacial,
      0.40 as temporal,
      0.35 as patron
    ) as pesos,

    'Restaurantes: visitas medianas, frecuencia media-alta' as notas
  ),

  -- CENTROS COMERCIALES
  STRUCT(
    'CENTRO_COMERCIAL' as tipo_poc,
    'OCIO' as perfil_base,
    'v2.0' as config_version,
    CURRENT_TIMESTAMP() as fecha_actualizacion,

    10.0 as hora_apertura,
    22.0 as hora_cierre,

    1.5 as ajuste_tiempo,        -- 50% más largo (visitas de compras)
    1.0 as ajuste_frecuencia,

    STRUCT(
      1.3 as stddev_max,
      3.0 as stddev_visitante_min,
      6.0 as dif_horas_min,
      55.0 as pct_fuera_horario_max
    ) as patron_trabajador,

    STRUCT(
      0.60 as minimo,
      0.85 as optimo
    ) as ratio,

    STRUCT(
      0.18 as muy_probable,
      0.13 as probable,
      0.08 as posible,
      0.04 as dudoso
    ) as umbrales,

    STRUCT(
      0.30 as espacial,
      0.35 as temporal,
      0.35 as patron
    ) as pesos,

    'Centros comerciales: visitas largas, muchos trabajadores' as notas
  ),

  -- BANCOS
  STRUCT(
    'BANCO' as tipo_poc,
    'COMPRA_PLANIFICADA' as perfil_base,
    'v2.0' as config_version,
    CURRENT_TIMESTAMP() as fecha_actualizacion,

    9.0 as hora_apertura,
    14.0 as hora_cierre,

    0.6 as ajuste_tiempo,        -- 40% más corto (visitas rápidas)
    0.8 as ajuste_frecuencia,    -- 20% menos frecuente

    STRUCT(
      1.5 as stddev_max,
      3.0 as stddev_visitante_min,
      5.0 as dif_horas_min,
      50.0 as pct_fuera_horario_max
    ) as patron_trabajador,

    STRUCT(
      0.75 as minimo,
      0.90 as optimo
    ) as ratio,

    STRUCT(
      0.20 as muy_probable,
      0.15 as probable,
      0.10 as posible,
      0.05 as dudoso
    ) as umbrales,

    STRUCT(
      0.30 as espacial,
      0.45 as temporal,
      0.25 as patron
    ) as pesos,

    'Bancos: visitas cortas, horario reducido' as notas
  )
]);


-- ============================================================================
-- PARTE 3: VISTA MATERIALIZADA - CONFIGURACIÓN CALCULADA
-- ============================================================================
-- Combina perfil base + config específica y deriva todos los parámetros

CREATE OR REPLACE TABLE `mo-advertising-sta.ADVERTISING_TEST.CONFIG_CALCULADA_V2` AS
SELECT
  c.tipo_poc,
  c.perfil_base,
  c.config_version,
  c.fecha_actualizacion,

  -- Horarios
  c.hora_apertura,
  c.hora_cierre,

  -- PARÁMETROS DERIVADOS - Tiempo (en segundos)
  CAST(p.tiempo_base_segundos * c.ajuste_tiempo * p.tolerancia_tiempo_min AS INT64)
    as tiempo_min_valido,
  CAST(p.tiempo_base_segundos * c.ajuste_tiempo * p.tolerancia_tiempo_max AS INT64)
    as tiempo_max_valido,
  CAST(p.tiempo_base_segundos * c.ajuste_tiempo * p.tolerancia_tiempo_optimo AS INT64)
    as tiempo_optimo_min,
  CAST(p.tiempo_base_segundos * c.ajuste_tiempo * p.tolerancia_tiempo_optimo_max AS INT64)
    as tiempo_optimo_max,

  -- PARÁMETROS DERIVADOS - Frecuencia (en días)
  0 as dias_min_valido,  -- Siempre 0 (menos de 1 día = ruido)
  CAST(p.frecuencia_base_dias * c.ajuste_frecuencia * p.tolerancia_freq_max AS INT64)
    as dias_max_valido,
  1 as dias_optimo_min,  -- Siempre 1 (mínimo una visita)
  CAST(p.frecuencia_base_dias * c.ajuste_frecuencia AS INT64)
    as dias_optimo_max,

  -- Ratios
  c.ratio.minimo as ratio_minimo,
  c.ratio.optimo as ratio_optimo,

  -- Patrón trabajador
  c.patron_trabajador.stddev_max as stddev_trabajador_max,
  c.patron_trabajador.stddev_visitante_min as stddev_visitante_min,
  c.patron_trabajador.dif_horas_min as dif_horas_trabajador_min,
  c.patron_trabajador.pct_fuera_horario_max as pct_fuera_horario_max,

  -- Umbrales
  c.umbrales.muy_probable as umbral_muy_probable,
  c.umbrales.probable as umbral_probable,
  c.umbrales.posible as umbral_posible,
  c.umbrales.dudoso as umbral_dudoso,

  -- Pesos (NORMALIZADOS - suma = 1.0)
  c.pesos.espacial / (c.pesos.espacial + c.pesos.temporal + c.pesos.patron) as peso_espacial,
  c.pesos.temporal / (c.pesos.espacial + c.pesos.temporal + c.pesos.patron) as peso_temporal,
  c.pesos.patron / (c.pesos.espacial + c.pesos.temporal + c.pesos.patron) as peso_patron,

  -- Metadata
  p.riesgo_trabajadores,
  p.strictness,
  c.notas

FROM `mo-advertising-sta.ADVERTISING_TEST.CONFIG_POC_V2` c
INNER JOIN `mo-advertising-sta.ADVERTISING_TEST.PERFILES_NEGOCIO_BASE` p
  ON c.perfil_base = p.perfil;


-- ============================================================================
-- PARTE 4: VALIDACIÓN AUTOMÁTICA DE CONFIGURACIÓN
-- ============================================================================

CREATE OR REPLACE TEMP TABLE validacion_config AS
SELECT
  tipo_poc,

  -- Validar tiempo
  tiempo_min_valido < tiempo_optimo_min as tiempo_check_1,
  tiempo_optimo_min < tiempo_optimo_max as tiempo_check_2,
  tiempo_optimo_max < tiempo_max_valido as tiempo_check_3,

  -- Validar frecuencia
  dias_min_valido < dias_optimo_min as freq_check_1,
  dias_optimo_min <= dias_optimo_max as freq_check_2,
  dias_optimo_max < dias_max_valido as freq_check_3,

  -- Validar ratios
  ratio_minimo < ratio_optimo as ratio_check,
  ratio_minimo BETWEEN 0 AND 1 as ratio_range_1,
  ratio_optimo BETWEEN 0 AND 1 as ratio_range_2,

  -- Validar pesos (deben sumar ~1.0)
  ABS((peso_espacial + peso_temporal + peso_patron) - 1.0) < 0.01 as pesos_sum_check,

  -- Validar umbrales
  umbral_dudoso < umbral_posible as umbral_check_1,
  umbral_posible < umbral_probable as umbral_check_2,
  umbral_probable < umbral_muy_probable as umbral_check_3

FROM `mo-advertising-sta.ADVERTISING_TEST.CONFIG_CALCULADA_V2`;

-- Mostrar errores de validación
SELECT
  tipo_poc,
  CASE
    WHEN NOT tiempo_check_1 THEN 'ERROR: tiempo_min >= tiempo_optimo_min'
    WHEN NOT tiempo_check_2 THEN 'ERROR: tiempo_optimo_min >= tiempo_optimo_max'
    WHEN NOT tiempo_check_3 THEN 'ERROR: tiempo_optimo_max >= tiempo_max'
    WHEN NOT freq_check_1 THEN 'ERROR: dias_min >= dias_optimo_min'
    WHEN NOT freq_check_2 THEN 'ERROR: dias_optimo_min > dias_optimo_max'
    WHEN NOT freq_check_3 THEN 'ERROR: dias_optimo_max >= dias_max'
    WHEN NOT ratio_check THEN 'ERROR: ratio_minimo >= ratio_optimo'
    WHEN NOT ratio_range_1 OR NOT ratio_range_2 THEN 'ERROR: ratios fuera de [0,1]'
    WHEN NOT pesos_sum_check THEN 'ERROR: pesos no suman 1.0'
    WHEN NOT umbral_check_1 THEN 'ERROR: umbral_dudoso >= umbral_posible'
    WHEN NOT umbral_check_2 THEN 'ERROR: umbral_posible >= umbral_probable'
    WHEN NOT umbral_check_3 THEN 'ERROR: umbral_probable >= umbral_muy_probable'
    ELSE '✅ OK'
  END as estado_validacion
FROM validacion_config;


-- ============================================================================
-- PARTE 5: FUNCIONES UDF MEJORADAS
-- ============================================================================

-- ============================================================================
-- 5.1 Factor Temporal del Día (sin cambios, ya estaba bien)
-- ============================================================================

CREATE OR REPLACE FUNCTION `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_temporal_dia_v2`(
  tiempo_ok_segundos INT64,
  ratio_horario FLOAT64,
  tiempo_min_valido INT64,
  tiempo_max_valido INT64,
  tiempo_optimo_min INT64,
  tiempo_optimo_max INT64,
  ratio_minimo FLOAT64,
  ratio_optimo FLOAT64
)
RETURNS FLOAT64
AS (
  -- Factor por duración
  (CASE
    WHEN tiempo_ok_segundos < tiempo_min_valido THEN 0.2
    WHEN tiempo_ok_segundos < tiempo_optimo_min THEN 0.6
    WHEN tiempo_ok_segundos BETWEEN tiempo_optimo_min AND tiempo_optimo_max THEN 1.0
    WHEN tiempo_ok_segundos < tiempo_max_valido THEN 0.7
    ELSE 0.15
  END)
  *
  -- Factor por ratio
  (CASE
    WHEN ratio_horario >= ratio_optimo THEN 1.0
    WHEN ratio_horario >= (ratio_optimo - 0.05) THEN 0.95
    WHEN ratio_horario >= ratio_minimo THEN 0.80
    WHEN ratio_horario >= (ratio_minimo - 0.1) THEN 0.50
    WHEN ratio_horario >= (ratio_minimo - 0.2) THEN 0.30
    ELSE 0.15
  END)
);


-- ============================================================================
-- 5.2 Factor del Día (detección jornada laboral ese día)
-- ============================================================================

CREATE OR REPLACE FUNCTION `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_dia_v2`(
  dif_horas FLOAT64,
  llega_antes_abrir BOOL,
  sale_despues_cerrar BOOL,
  dif_horas_trabajador_min FLOAT64
)
RETURNS FLOAT64
AS (
  CASE
    WHEN dif_horas >= (dif_horas_trabajador_min + 2)
      AND (llega_antes_abrir OR sale_despues_cerrar)
      THEN 0.05
    WHEN dif_horas >= (dif_horas_trabajador_min + 1)
      THEN 0.2
    WHEN dif_horas >= (dif_horas_trabajador_min - 1)
      AND (llega_antes_abrir OR sale_despues_cerrar)
      THEN 0.4
    WHEN dif_horas >= (dif_horas_trabajador_min - 1)
      THEN 0.7
    WHEN llega_antes_abrir OR sale_despues_cerrar
      THEN 0.8
    ELSE 1.0
  END
);


-- ============================================================================
-- 5.3 Factor de Frecuencia
-- ============================================================================

CREATE OR REPLACE FUNCTION `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_frecuencia_v2`(
  dias_visita_total INT64,
  dias_min_valido INT64,
  dias_max_valido INT64,
  dias_optimo_min INT64,
  dias_optimo_max INT64
)
RETURNS FLOAT64
AS (
  CASE
    WHEN dias_visita_total < dias_min_valido THEN 0.2
    WHEN dias_visita_total < dias_optimo_min THEN 0.6
    WHEN dias_visita_total BETWEEN dias_optimo_min AND dias_optimo_max THEN 1.0
    WHEN dias_visita_total < dias_max_valido THEN 0.7
    ELSE 0.1
  END
);


-- ============================================================================
-- 5.4 Factor de Patrón Agregado (MEJORADO: basado en días limpios)
-- ============================================================================

CREATE OR REPLACE FUNCTION `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_patron_agregado_v2`(
  stddev_hora_minima FLOAT64,
  stddev_hora_maxima FLOAT64,
  dif_horas_promedio FLOAT64,
  dias_visita_total INT64,
  pct_llega_antes FLOAT64,
  pct_sale_despues FLOAT64,
  stddev_trabajador_max FLOAT64,
  stddev_visitante_min FLOAT64,
  dif_horas_trabajador_min FLOAT64,
  pct_fuera_horario_max FLOAT64,
  dias_max_valido INT64
)
RETURNS FLOAT64
AS (
  CASE
    -- CASO 1: Patrón laboral MUY claro
    WHEN dias_visita_total > dias_max_valido
      AND stddev_hora_minima < stddev_trabajador_max
      AND stddev_hora_maxima < stddev_trabajador_max
      AND dif_horas_promedio >= dif_horas_trabajador_min
      THEN 0.05

    -- CASO 2: Patrón laboral claro
    WHEN dias_visita_total >= (dias_max_valido - 1)
      AND stddev_hora_minima < (stddev_trabajador_max * 1.5)
      AND stddev_hora_maxima < (stddev_trabajador_max * 1.5)
      AND dif_horas_promedio >= dif_horas_trabajador_min
      THEN 0.1

    -- CASO 3: Probable trabajador
    WHEN (dias_visita_total >= (dias_max_valido - 1)
          AND stddev_hora_minima < (stddev_trabajador_max * 2)
          AND stddev_hora_maxima < (stddev_trabajador_max * 2))
      OR (dias_visita_total >= (dias_max_valido - 4)
          AND dif_horas_promedio >= (dif_horas_trabajador_min + 1))
      THEN 0.3

    -- CASO 4: Fuera de horario FRECUENTEMENTE
    WHEN dias_visita_total >= (dias_max_valido - 4)
      AND (pct_llega_antes > pct_fuera_horario_max OR pct_sale_despues > pct_fuera_horario_max)
      THEN 0.4

    -- CASO 5: Algo de consistencia
    WHEN stddev_hora_minima < stddev_visitante_min
      AND stddev_hora_maxima < stddev_visitante_min
      AND dias_visita_total >= 2
      THEN 0.75

    -- CASO 6: Horarios variables (visitante)
    WHEN stddev_hora_minima >= stddev_visitante_min
      OR stddev_hora_maxima >= stddev_visitante_min
      OR dias_visita_total = 1
      THEN 1.0

    ELSE 0.60
  END
);


-- ============================================================================
-- 5.5 Probabilidad Final - PROMEDIO PONDERADO (CORREGIDO)
-- ============================================================================

CREATE OR REPLACE FUNCTION `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_final_v2`(
  prob_espacial FLOAT64,
  prob_temporal FLOAT64,
  prob_patron FLOAT64,
  peso_espacial FLOAT64,
  peso_temporal FLOAT64,
  peso_patron FLOAT64
)
RETURNS FLOAT64
AS (
  -- PROMEDIO PONDERADO CORRECTO (no POWER)
  -- Normaliza cada probabilidad a [0,1] y pondera
  (peso_espacial * prob_espacial) +
  (peso_temporal * prob_temporal) +
  (peso_patron * prob_patron)
  -- Los pesos ya están normalizados (suman 1.0), así que el resultado está en [0,1]
);


-- ============================================================================
-- PARTE 6: MODELO 2-PASS (ELIMINACIÓN DE DATA LEAKAGE)
-- ============================================================================

-- ============================================================================
-- PASO 1: Configurar POC
-- ============================================================================

CREATE OR REPLACE TEMP TABLE CONFIG_POC_ACTIVA AS
SELECT *
FROM `mo-advertising-sta.ADVERTISING_TEST.CONFIG_CALCULADA_V2`
WHERE tipo_poc = 'SUPERMERCADO';  -- 🔧 CAMBIAR SEGÚN POC


-- ============================================================================
-- PASO 2: PASS 1 - Clasificación preliminar (solo info del día)
-- ============================================================================
-- Evalúa cada día con estadísticas "sucias" (todos los días del usuario)

CREATE OR REPLACE TEMP TABLE DIAS_PASS1 AS
SELECT
  v.msisdn,
  v.id_ubicacion,
  v.fecha,
  v.DIA_SEMANA,
  v.poc,
  c.tipo_poc,

  -- Variables del día
  v.tiempo_total_ok_dia,
  v.tiempo_total_no_ok_dia,
  v.dif_horas,
  v.hora_minima,
  v.hora_maxima,
  v.PROBABILIDAD_VISITA_OK as prob_espacial,

  -- Ratio del día
  SAFE_DIVIDE(v.tiempo_total_ok_dia, v.tiempo_total_ok_dia + v.tiempo_total_no_ok_dia) as ratio_horario,

  -- Flags del día
  CASE WHEN v.hora_minima < c.hora_apertura THEN TRUE ELSE FALSE END as llega_antes_abrir,
  CASE WHEN v.hora_maxima > c.hora_cierre THEN TRUE ELSE FALSE END as sale_despues_cerrar,

  -- Factores solo del día
  `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_temporal_dia_v2`(
    v.tiempo_total_ok_dia,
    SAFE_DIVIDE(v.tiempo_total_ok_dia, v.tiempo_total_ok_dia + v.tiempo_total_no_ok_dia),
    c.tiempo_min_valido,
    c.tiempo_max_valido,
    c.tiempo_optimo_min,
    c.tiempo_optimo_max,
    c.ratio_minimo,
    c.ratio_optimo
  ) as factor_temporal_dia,

  `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_dia_v2`(
    v.dif_horas,
    CASE WHEN v.hora_minima < c.hora_apertura THEN TRUE ELSE FALSE END,
    CASE WHEN v.hora_maxima > c.hora_cierre THEN TRUE ELSE FALSE END,
    c.dif_horas_trabajador_min
  ) as factor_dia,

  -- Guardar parámetros para Pass 2
  c.tiempo_min_valido,
  c.tiempo_max_valido,
  c.tiempo_optimo_min,
  c.tiempo_optimo_max,
  c.dias_min_valido,
  c.dias_max_valido,
  c.dias_optimo_min,
  c.dias_optimo_max,
  c.ratio_minimo,
  c.ratio_optimo,
  c.stddev_trabajador_max,
  c.stddev_visitante_min,
  c.dif_horas_trabajador_min,
  c.pct_fuera_horario_max,
  c.umbral_muy_probable,
  c.umbral_probable,
  c.umbral_posible,
  c.umbral_dudoso,
  c.peso_espacial,
  c.peso_temporal,
  c.peso_patron

FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_UBICACION_GEO_TILES_CELIA_ISA_V2` v
CROSS JOIN CONFIG_POC_ACTIVA c
WHERE v.poc = 'NORGES_SEAFOOD-SALMON_AGO26'  -- 🔧 CAMBIAR SEGÚN CAMPAÑA
  AND v.PERIODO = 'CAMPAIGN'
  AND v.tiempo_total_ok_dia > 0;


-- ============================================================================
-- PASO 3: Clasificación preliminar (umbral bajo)
-- ============================================================================
-- Clasificar días con umbral MUY permisivo para Pass 1

CREATE OR REPLACE TEMP TABLE DIAS_CLASIFICADOS_PASS1 AS
SELECT
  *,

  -- Clasificación preliminar SOLO con info del día
  -- Umbral bajo: prob_temporal > 0.4 = probablemente válido
  CASE
    WHEN (factor_temporal_dia * factor_dia) >= 0.4
      AND tiempo_total_ok_dia BETWEEN tiempo_optimo_min AND tiempo_max_valido
    THEN 'PASS1_VALIDO'
    ELSE 'PASS1_DESCARTADO'
  END as clasificacion_pass1

FROM DIAS_PASS1;


-- ============================================================================
-- PASO 4: ESTADÍSTICAS LIMPIAS (solo días PASS1_VALIDO)
-- ============================================================================
-- ✅ AQUÍ SE ELIMINA EL DATA LEAKAGE

CREATE OR REPLACE TEMP TABLE PATRON_LIMPIO AS
SELECT
  msisdn,
  id_ubicacion,
  tipo_poc,

  -- Frecuencia (solo días válidos)
  COUNT(DISTINCT fecha) as dias_visita_total,

  -- Variabilidad horaria (solo días válidos)
  STDDEV(hora_minima) as stddev_hora_minima,
  STDDEV(hora_maxima) as stddev_hora_maxima,

  -- Promedios (solo días válidos)
  AVG(dif_horas) as dif_horas_promedio,
  AVG(hora_minima) as hora_minima_promedio,
  AVG(hora_maxima) as hora_maxima_promedio,

  -- Porcentajes fuera horario (solo días válidos)
  100.0 * SUM(CASE WHEN llega_antes_abrir THEN 1 ELSE 0 END) / COUNT(*) as pct_llega_antes,
  100.0 * SUM(CASE WHEN sale_despues_cerrar THEN 1 ELSE 0 END) / COUNT(*) as pct_sale_despues,

  -- Conservar parámetros (tomar el max porque son iguales para todos)
  MAX(tiempo_min_valido) as tiempo_min_valido,
  MAX(tiempo_max_valido) as tiempo_max_valido,
  MAX(tiempo_optimo_min) as tiempo_optimo_min,
  MAX(tiempo_optimo_max) as tiempo_optimo_max,
  MAX(dias_min_valido) as dias_min_valido,
  MAX(dias_max_valido) as dias_max_valido,
  MAX(dias_optimo_min) as dias_optimo_min,
  MAX(dias_optimo_max) as dias_optimo_max,
  MAX(ratio_minimo) as ratio_minimo,
  MAX(ratio_optimo) as ratio_optimo,
  MAX(stddev_trabajador_max) as stddev_trabajador_max,
  MAX(stddev_visitante_min) as stddev_visitante_min,
  MAX(dif_horas_trabajador_min) as dif_horas_trabajador_min,
  MAX(pct_fuera_horario_max) as pct_fuera_horario_max,
  MAX(umbral_muy_probable) as umbral_muy_probable,
  MAX(umbral_probable) as umbral_probable,
  MAX(umbral_posible) as umbral_posible,
  MAX(umbral_dudoso) as umbral_dudoso,
  MAX(peso_espacial) as peso_espacial,
  MAX(peso_temporal) as peso_temporal,
  MAX(peso_patron) as peso_patron

FROM DIAS_CLASIFICADOS_PASS1
WHERE clasificacion_pass1 = 'PASS1_VALIDO'  -- ✅ SOLO DÍAS BUENOS
GROUP BY msisdn, id_ubicacion, tipo_poc;


-- ============================================================================
-- PASO 5: PASS 2 - Evaluación final con patrón limpio
-- ============================================================================

CREATE OR REPLACE TABLE `mo-advertising-sta.ADVERTISING_TEST.VISITAS_FINALES_V2` AS
SELECT
  d.msisdn,
  d.id_ubicacion,
  d.fecha,
  d.DIA_SEMANA,
  d.poc,
  d.tipo_poc,

  -- Variables del día
  d.tiempo_total_ok_dia,
  d.tiempo_total_no_ok_dia,
  d.dif_horas,
  d.hora_minima,
  d.hora_maxima,
  d.prob_espacial,
  d.ratio_horario,
  d.llega_antes_abrir,
  d.sale_despues_cerrar,

  -- Estadísticas limpias del usuario
  COALESCE(p.dias_visita_total, 0) as dias_visita_total,
  COALESCE(p.stddev_hora_minima, 999) as stddev_hora_minima,
  COALESCE(p.stddev_hora_maxima, 999) as stddev_hora_maxima,
  COALESCE(p.dif_horas_promedio, d.dif_horas) as dif_horas_promedio,
  COALESCE(p.pct_llega_antes, 0) as pct_llega_antes,
  COALESCE(p.pct_sale_despues, 0) as pct_sale_despues,

  -- Componentes de probabilidad
  d.prob_espacial as comp_espacial,
  (d.factor_temporal_dia * d.factor_dia) as comp_temporal,

  `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_frecuencia_v2`(
    COALESCE(p.dias_visita_total, 0),
    d.dias_min_valido,
    d.dias_max_valido,
    d.dias_optimo_min,
    d.dias_optimo_max
  ) *
  `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_patron_agregado_v2`(
    COALESCE(p.stddev_hora_minima, 999),
    COALESCE(p.stddev_hora_maxima, 999),
    COALESCE(p.dif_horas_promedio, d.dif_horas),
    COALESCE(p.dias_visita_total, 0),
    COALESCE(p.pct_llega_antes, 0),
    COALESCE(p.pct_sale_despues, 0),
    d.stddev_trabajador_max,
    d.stddev_visitante_min,
    d.dif_horas_trabajador_min,
    d.pct_fuera_horario_max,
    d.dias_max_valido
  ) as comp_patron,

  -- Probabilidad final (PROMEDIO PONDERADO)
  `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_final_v2`(
    d.prob_espacial,
    (d.factor_temporal_dia * d.factor_dia),
    `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_frecuencia_v2`(
      COALESCE(p.dias_visita_total, 0),
      d.dias_min_valido,
      d.dias_max_valido,
      d.dias_optimo_min,
      d.dias_optimo_max
    ) *
    `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_patron_agregado_v2`(
      COALESCE(p.stddev_hora_minima, 999),
      COALESCE(p.stddev_hora_maxima, 999),
      COALESCE(p.dif_horas_promedio, d.dif_horas),
      COALESCE(p.dias_visita_total, 0),
      COALESCE(p.pct_llega_antes, 0),
      COALESCE(p.pct_sale_despues, 0),
      d.stddev_trabajador_max,
      d.stddev_visitante_min,
      d.dif_horas_trabajador_min,
      d.pct_fuera_horario_max,
      d.dias_max_valido
    ),
    d.peso_espacial,
    d.peso_temporal,
    d.peso_patron
  ) as prob_visita_final,

  -- Clasificación final
  CASE
    WHEN `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_final_v2`(
      d.prob_espacial,
      (d.factor_temporal_dia * d.factor_dia),
      `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_frecuencia_v2`(
        COALESCE(p.dias_visita_total, 0),
        d.dias_min_valido, d.dias_max_valido, d.dias_optimo_min, d.dias_optimo_max
      ) *
      `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_patron_agregado_v2`(
        COALESCE(p.stddev_hora_minima, 999), COALESCE(p.stddev_hora_maxima, 999),
        COALESCE(p.dif_horas_promedio, d.dif_horas), COALESCE(p.dias_visita_total, 0),
        COALESCE(p.pct_llega_antes, 0), COALESCE(p.pct_sale_despues, 0),
        d.stddev_trabajador_max, d.stddev_visitante_min, d.dif_horas_trabajador_min,
        d.pct_fuera_horario_max, d.dias_max_valido
      ),
      d.peso_espacial, d.peso_temporal, d.peso_patron
    ) >= d.umbral_muy_probable THEN 'VISITA_MUY_PROBABLE'

    WHEN `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_final_v2`(
      d.prob_espacial, (d.factor_temporal_dia * d.factor_dia),
      `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_frecuencia_v2`(
        COALESCE(p.dias_visita_total, 0),
        d.dias_min_valido, d.dias_max_valido, d.dias_optimo_min, d.dias_optimo_max
      ) *
      `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_patron_agregado_v2`(
        COALESCE(p.stddev_hora_minima, 999), COALESCE(p.stddev_hora_maxima, 999),
        COALESCE(p.dif_horas_promedio, d.dif_horas), COALESCE(p.dias_visita_total, 0),
        COALESCE(p.pct_llega_antes, 0), COALESCE(p.pct_sale_despues, 0),
        d.stddev_trabajador_max, d.stddev_visitante_min, d.dif_horas_trabajador_min,
        d.pct_fuera_horario_max, d.dias_max_valido
      ),
      d.peso_espacial, d.peso_temporal, d.peso_patron
    ) >= d.umbral_probable THEN 'VISITA_PROBABLE'

    WHEN `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_final_v2`(
      d.prob_espacial, (d.factor_temporal_dia * d.factor_dia),
      `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_frecuencia_v2`(
        COALESCE(p.dias_visita_total, 0),
        d.dias_min_valido, d.dias_max_valido, d.dias_optimo_min, d.dias_optimo_max
      ) *
      `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_patron_agregado_v2`(
        COALESCE(p.stddev_hora_minima, 999), COALESCE(p.stddev_hora_maxima, 999),
        COALESCE(p.dif_horas_promedio, d.dif_horas), COALESCE(p.dias_visita_total, 0),
        COALESCE(p.pct_llega_antes, 0), COALESCE(p.pct_sale_despues, 0),
        d.stddev_trabajador_max, d.stddev_visitante_min, d.dif_horas_trabajador_min,
        d.pct_fuera_horario_max, d.dias_max_valido
      ),
      d.peso_espacial, d.peso_temporal, d.peso_patron
    ) >= d.umbral_posible THEN 'VISITA_POSIBLE'

    WHEN `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_final_v2`(
      d.prob_espacial, (d.factor_temporal_dia * d.factor_dia),
      `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_frecuencia_v2`(
        COALESCE(p.dias_visita_total, 0),
        d.dias_min_valido, d.dias_max_valido, d.dias_optimo_min, d.dias_optimo_max
      ) *
      `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_patron_agregado_v2`(
        COALESCE(p.stddev_hora_minima, 999), COALESCE(p.stddev_hora_maxima, 999),
        COALESCE(p.dif_horas_promedio, d.dif_horas), COALESCE(p.dias_visita_total, 0),
        COALESCE(p.pct_llega_antes, 0), COALESCE(p.pct_sale_despues, 0),
        d.stddev_trabajador_max, d.stddev_visitante_min, d.dif_horas_trabajador_min,
        d.pct_fuera_horario_max, d.dias_max_valido
      ),
      d.peso_espacial, d.peso_temporal, d.peso_patron
    ) >= d.umbral_dudoso THEN 'DUDOSO'

    ELSE 'DESCARTADO'
  END as clasificacion_final,

  -- Metadata
  d.clasificacion_pass1,
  d.peso_espacial,
  d.peso_temporal,
  d.peso_patron,
  d.umbral_muy_probable,
  d.umbral_probable

FROM DIAS_CLASIFICADOS_PASS1 d
LEFT JOIN PATRON_LIMPIO p
  ON d.msisdn = p.msisdn
  AND d.id_ubicacion = p.id_ubicacion;


-- ============================================================================
-- PARTE 7: QUERIES DE VALIDACIÓN
-- ============================================================================

-- Query A: Resumen por clasificación
SELECT
  tipo_poc,
  clasificacion_final,
  COUNT(*) as n_visitas,
  COUNT(DISTINCT msisdn) as n_usuarios_unicos,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(PARTITION BY tipo_poc), 2) as pct_visitas,

  ROUND(AVG(prob_visita_final), 4) as prob_promedio,
  ROUND(AVG(comp_espacial), 4) as comp_espacial_prom,
  ROUND(AVG(comp_temporal), 4) as comp_temporal_prom,
  ROUND(AVG(comp_patron), 4) as comp_patron_prom,

  ROUND(AVG(ratio_horario), 3) as ratio_prom,
  ROUND(AVG(tiempo_total_ok_dia / 60), 1) as tiempo_min_prom,
  ROUND(AVG(dias_visita_total), 1) as dias_prom

FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_FINALES_V2`
GROUP BY tipo_poc, clasificacion_final
ORDER BY tipo_poc,
  CASE clasificacion_final
    WHEN 'VISITA_MUY_PROBABLE' THEN 1
    WHEN 'VISITA_PROBABLE' THEN 2
    WHEN 'VISITA_POSIBLE' THEN 3
    WHEN 'DUDOSO' THEN 4
    ELSE 5
  END;


-- Query B: Distribución de pesos (verificar normalización)
SELECT
  tipo_poc,
  ROUND(AVG(peso_espacial), 3) as peso_espacial,
  ROUND(AVG(peso_temporal), 3) as peso_temporal,
  ROUND(AVG(peso_patron), 3) as peso_patron,
  ROUND(AVG(peso_espacial + peso_temporal + peso_patron), 4) as suma_pesos

FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_FINALES_V2`
GROUP BY tipo_poc;


-- Query C: Impacto del modelo 2-pass
SELECT
  tipo_poc,
  'Pass 1: Clasificados como válidos' as etapa,
  COUNT(*) as n_visitas
FROM DIAS_CLASIFICADOS_PASS1
WHERE clasificacion_pass1 = 'PASS1_VALIDO'
GROUP BY tipo_poc

UNION ALL

SELECT
  tipo_poc,
  'Pass 2: Visitas muy probables' as etapa,
  COUNT(*) as n_visitas
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_FINALES_V2`
WHERE clasificacion_final = 'VISITA_MUY_PROBABLE'
GROUP BY tipo_poc

UNION ALL

SELECT
  tipo_poc,
  'Pass 2: Visitas probables+' as etapa,
  COUNT(*) as n_visitas
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_FINALES_V2`
WHERE clasificacion_final IN ('VISITA_MUY_PROBABLE', 'VISITA_PROBABLE')
GROUP BY tipo_poc

ORDER BY tipo_poc, etapa;


-- Query D: Top usuarios para validación manual
SELECT
  msisdn,
  fecha,
  ROUND(tiempo_total_ok_dia / 60, 1) as tiempo_min,
  dias_visita_total,
  ROUND(stddev_hora_minima, 2) as stddev_hora_min,
  ROUND(comp_espacial, 3) as comp_esp,
  ROUND(comp_temporal, 3) as comp_temp,
  ROUND(comp_patron, 3) as comp_pat,
  ROUND(prob_visita_final, 4) as prob_final,
  clasificacion_final

FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_FINALES_V2`
WHERE clasificacion_final IN ('VISITA_MUY_PROBABLE', 'VISITA_PROBABLE')
ORDER BY prob_visita_final DESC
LIMIT 100;


-- ============================================================================
-- FIN DEL MODELO MEJORADO V2
-- ============================================================================

/*
============================================================================
CAMBIOS PRINCIPALES vs Versión Anterior
============================================================================

1. ✅ MODELO 2-PASS (elimina data leakage)
   - Pass 1: Clasifica días con umbrales permisivos
   - Estadísticas limpias: solo días válidos de Pass 1
   - Pass 2: Re-evalúa con estadísticas limpias

2. ✅ PESOS CORREGIDOS
   - Antes: POWER(prob, peso) → incorrecto matemáticamente
   - Ahora: promedio_ponderado → pesos suman 1.0

3. ✅ JERARQUÍA DE CONFIGURACIÓN
   - 3 perfiles base (PLANIFICADO, RUTINARIO, OCIO)
   - POCs específicos heredan + ajustes
   - Parámetros derivados automáticamente

4. ✅ VALIDACIÓN AUTOMÁTICA
   - Verifica consistencia de parámetros
   - Alerta si hay configuraciones inválidas

5. ✅ TRAZABILIDAD
   - config_version, fecha_actualizacion
   - Puedes trackear qué config generó qué resultados

============================================================================
CÓMO USAR
============================================================================

PASO 1: Cambiar línea 612 (configuración POC)
WHERE tipo_poc = 'TU_TIPO'

PASO 2: Cambiar línea 759 (campaña)
WHERE v.poc = 'TU_CAMPAÑA'

PASO 3: Ejecutar todo el script

PASO 4: Revisar validación (debe mostrar ✅ OK)

PASO 5: Analizar resultados con queries de validación

============================================================================
PRÓXIMOS PASOS OPCIONALES
============================================================================

- Implementar calibración de umbrales con ground truth
- Añadir features temporales (día semana, festivos)
- Dashboard de monitoreo de modelo
- Tests A/B entre versiones

*/
