-- ============================================================================
-- MODELO PROBABILÍSTICO GENÉRICO - EVALUACIÓN POR DÍA
-- Versión: 4.1 - HÍBRIDO: Factor patrón agregado + Evaluación diaria
-- ============================================================================
--
-- ENFOQUE HÍBRIDO:
-- ✅ Evalúa cada visita por día (msisdn + fecha + ubicación)
-- ✅ Usa patrón agregado del usuario (stddev, frecuencia total, %)
-- ✅ Parametrizado: funciona para cualquier tipo de POC
--
-- DIFERENCIAS vs 03_MODELO_GENERICO.sql:
-- - GENERICO: 1 fila por usuario-ubicación (agregado completo)
-- - POR_DIA: N filas por usuario-ubicación (una por día)
--
-- USO:
-- - Cuando quieres ver qué días específicos son visitas válidas
-- - Cuando el patrón general del usuario importa, pero evalúas día a día
--
-- ============================================================================

-- ============================================================================
-- PARTE 1: USAR MISMA TABLA DE CONFIGURACIÓN
-- ============================================================================
-- NOTA: Este modelo usa CONFIG_MODELO_PARAMETRIZADA del modelo genérico
-- Si no existe, ejecutar primero PARTE 1 de 03_MODELO_GENERICO.sql
CREATE OR REPLACE TABLE `mo-advertising-sta.ADVERTISING_TEST.CONFIG_MODELO_PARAMETRIZADA` AS
SELECT * FROM UNNEST([

  -- =========================================================================
  -- CONCESIONARIOS (Volvo, Mercedes, BMW, etc.)
  -- =========================================================================
  STRUCT(
    'CONCESIONARIO' as tipo_poc,
    'Concesionarios de vehículos' as descripcion,

    -- HORARIOS
    10.0 as hora_apertura,
    20.0 as hora_cierre,

    -- TIEMPOS DE VISITA (en segundos)
    900 as tiempo_min_valido,        -- 15 min
    10800 as tiempo_max_valido,      -- 3 horas
    1800 as tiempo_optimo_min,       -- 30 min
    5400 as tiempo_optimo_max,       -- 90 min

    -- FRECUENCIA (días) - Rango válido
    1 as dias_minimo,                -- Mínimo días para ser válido (< esto = ruido)
    9 as dias_maximo,                -- Máximo días visitante (> esto = trabajador)

    -- RATIOS
    0.80 as ratio_minimo,            -- Mínimo aceptable
    0.90 as ratio_optimo,            -- Óptimo

    -- PATRÓN HORARIO
    1.5 as stddev_trabajador_max,    -- < 1.5h stddev = trabajador
    3.0 as stddev_visitante_min,     -- >= 3h stddev = visitante
    6.0 as dif_horas_trabajador_min, -- >= 6h promedio = trabajador
    50.0 as pct_fuera_horario_max,   -- > 50% días fuera = trabajador

    -- UMBRALES DE CLASIFICACIÓN
    0.20 as umbral_muy_probable,
    0.15 as umbral_probable,
    0.10 as umbral_posible,
    0.05 as umbral_dudoso,

    -- PESOS (para ajustar importancia de cada componente)
    -- Valores < 1.0 = suavizan (elevan valores bajos, reducen impacto)
    -- Valores = 1.0 = sin cambio
    -- Valores > 1.0 = acentúan (penalizan más valores bajos)
    0.5 as peso_espacial,      -- Suaviza prob_espacial (reduce su impacto negativo)
    1.0 as peso_temporal,      -- Mantiene importancia normal
    1.0 as peso_patron,        -- Mantiene importancia normal

    'Estricto. Visitas largas planificadas. Nadie vive al lado.' as notas
  ),

  -- =========================================================================
  -- SUPERMERCADOS (Mercadona, Lidl, Carrefour, etc.)
  -- =========================================================================
  STRUCT(
    'SUPERMERCADO' as tipo_poc,
    'Supermercados y tiendas de alimentación' as descripcion,

    -- HORARIOS (más amplios)
    8.0 as hora_apertura,
    22.0 as hora_cierre,

    -- TIEMPOS DE VISITA
    600 as tiempo_min_valido,        -- 10 min
    7200 as tiempo_max_valido,       -- 2 horas
    1200 as tiempo_optimo_min,       -- 20 min
    3600 as tiempo_optimo_max,       -- 60 min

    -- FRECUENCIA (más permisivo)
    1 as dias_minimo,
    14 as dias_maximo,

    -- RATIOS (más flexible)
    0.50 as ratio_minimo,
    0.80 as ratio_optimo,

    -- PATRÓN HORARIO (más permisivo)
    1.0 as stddev_trabajador_max,
    3.0 as stddev_visitante_min,
    6.0 as dif_horas_trabajador_min,
    60.0 as pct_fuera_horario_max,

    -- UMBRALES
    0.18 as umbral_muy_probable,
    0.12 as umbral_probable,
    0.08 as umbral_posible,
    0.04 as umbral_dudoso,

    -- PESOS
    0.5 as peso_espacial,      -- Suaviza (vecinos frecuentes, prob_espacial menos fiable)
    1.0 as peso_temporal,
    0.9 as peso_patron,        -- Reduce ligeramente (patrón menos relevante con vecinos)

    'Flexible. Vecinos frecuentes. Horarios variables.' as notas
  ),

  -- =========================================================================
  -- RESTAURANTES (Burger King, McDonald's, KFC, etc.)
  -- =========================================================================
  STRUCT(
    'RESTAURANTE' as tipo_poc,
    'Restaurantes y comida rápida' as descripcion,

    -- HORARIOS
    11.0 as hora_apertura,
    23.0 as hora_cierre,

    -- TIEMPOS DE VISITA
    600 as tiempo_min_valido,        -- 10 min
    5400 as tiempo_max_valido,       -- 90 min
    1200 as tiempo_optimo_min,       -- 20 min
    2700 as tiempo_optimo_max,       -- 45 min

    -- FRECUENCIA
    1 as dias_minimo,
    11 as dias_maximo,

    -- RATIOS
    0.60 as ratio_minimo,
    0.85 as ratio_optimo,

    -- PATRÓN HORARIO
    1.2 as stddev_trabajador_max,
    3.0 as stddev_visitante_min,
    6.0 as dif_horas_trabajador_min,
    55.0 as pct_fuera_horario_max,

    -- UMBRALES
    0.18 as umbral_muy_probable,
    0.12 as umbral_probable,
    0.08 as umbral_posible,
    0.04 as umbral_dudoso,

    -- PESOS
    0.5 as peso_espacial,
    1.0 as peso_temporal,
    0.95 as peso_patron,

    'Intermedio. Visitas cortas frecuentes. Algunos trabajadores.' as notas
  ),

  -- =========================================================================
  -- CENTROS COMERCIALES
  -- =========================================================================
  STRUCT(
    'CENTRO_COMERCIAL' as tipo_poc,
    'Centros comerciales y outlets' as descripcion,

    -- HORARIOS
    10.0 as hora_apertura,
    22.0 as hora_cierre,

    -- TIEMPOS DE VISITA
    1800 as tiempo_min_valido,       -- 30 min
    10800 as tiempo_max_valido,      -- 3 horas
    3600 as tiempo_optimo_min,       -- 1 hora
    7200 as tiempo_optimo_max,       -- 2 horas

    -- FRECUENCIA
    1 as dias_minimo,
    11 as dias_maximo,

    -- RATIOS
    0.60 as ratio_minimo,
    0.85 as ratio_optimo,

    -- PATRÓN HORARIO
    1.3 as stddev_trabajador_max,
    3.0 as stddev_visitante_min,
    6.0 as dif_horas_trabajador_min,
    55.0 as pct_fuera_horario_max,

    -- UMBRALES
    0.18 as umbral_muy_probable,
    0.13 as umbral_probable,
    0.08 as umbral_posible,
    0.04 as umbral_dudoso,

    -- PESOS
    0.5 as peso_espacial,
    1.0 as peso_temporal,
    0.95 as peso_patron,

    'Flexible. Muchos trabajadores pero también visitantes frecuentes.' as notas
  ),

  -- =========================================================================
  -- BANCOS
  -- =========================================================================
  STRUCT(
    'BANCO' as tipo_poc,
    'Oficinas bancarias' as descripcion,

    -- HORARIOS
    9.0 as hora_apertura,
    14.0 as hora_cierre,

    -- TIEMPOS DE VISITA
    600 as tiempo_min_valido,        -- 10 min
    3600 as tiempo_max_valido,       -- 1 hora
    900 as tiempo_optimo_min,        -- 15 min
    2400 as tiempo_optimo_max,       -- 40 min

    -- FRECUENCIA
    1 as dias_minimo,
    7 as dias_maximo,

    -- RATIOS
    0.75 as ratio_minimo,
    0.90 as ratio_optimo,

    -- PATRÓN HORARIO
    1.5 as stddev_trabajador_max,
    3.0 as stddev_visitante_min,
    5.0 as dif_horas_trabajador_min,
    50.0 as pct_fuera_horario_max,

    -- UMBRALES
    0.20 as umbral_muy_probable,
    0.15 as umbral_probable,
    0.10 as umbral_posible,
    0.05 as umbral_dudoso,

    -- PESOS
    0.5 as peso_espacial,
    1.0 as peso_temporal,
    1.0 as peso_patron,

    'Estricto. Visitas cortas planificadas. Horario reducido.' as notas
  )
]);


-- ============================================================================
-- PARTE 2: FUNCIÓN UDF - PROBABILIDAD TEMPORAL DEL DÍA (parametrizada)
-- ============================================================================
-- Evalúa tiempo_ok y ratio de UN DÍA específico

CREATE OR REPLACE FUNCTION `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_temporal_dia_param`(
  tiempo_ok_segundos INT64,
  ratio_horario FLOAT64,
  -- Parámetros del POC
  tiempo_min_valido INT64,
  tiempo_max_valido INT64,
  tiempo_optimo_min INT64,
  tiempo_optimo_max INT64,
  ratio_minimo FLOAT64,
  ratio_optimo FLOAT64
)
RETURNS FLOAT64
AS (
  -- Factor por duración del día
  (CASE
    WHEN tiempo_ok_segundos < tiempo_min_valido THEN 0.2
    WHEN tiempo_ok_segundos < tiempo_optimo_min THEN 0.6
    WHEN tiempo_ok_segundos BETWEEN tiempo_optimo_min AND tiempo_optimo_max THEN 1.0
    WHEN tiempo_ok_segundos < tiempo_max_valido THEN 0.7
    ELSE 0.15
  END)

  *

  -- Factor por ratio del día
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
-- PARTE 3: FUNCIÓN UDF - FACTOR DEL DÍA (parametrizada)
-- ============================================================================
-- Evalúa si ese día específico parece jornada laboral

CREATE OR REPLACE FUNCTION `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_dia_param`(
  dif_horas FLOAT64,
  llega_antes_abrir BOOL,
  sale_despues_cerrar BOOL,
  -- Parámetros del POC
  dif_horas_trabajador_min FLOAT64
)
RETURNS FLOAT64
AS (
  CASE
    -- Jornada MUY larga + fuera de horario
    WHEN dif_horas >= (dif_horas_trabajador_min + 2)
      AND (llega_antes_abrir OR sale_despues_cerrar)
      THEN 0.05

    -- Jornada larga
    WHEN dif_horas >= (dif_horas_trabajador_min + 1)
      THEN 0.2

    -- Jornada media-larga + fuera de horario
    WHEN dif_horas >= (dif_horas_trabajador_min - 1)
      AND (llega_antes_abrir OR sale_despues_cerrar)
      THEN 0.4

    -- Jornada media-larga dentro de horario
    WHEN dif_horas >= (dif_horas_trabajador_min - 1)
      THEN 0.7

    -- Fuera de horario (jornada corta)
    WHEN llega_antes_abrir OR sale_despues_cerrar
      THEN 0.8

    -- Normal
    ELSE 1.0
  END
);


-- ============================================================================
-- PARTE 4: FUNCIÓN UDF - FACTOR DE PATRÓN AGREGADO (parametrizada)
-- ============================================================================
-- Usa estadísticas de TODOS los días del usuario

CREATE OR REPLACE FUNCTION `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_patron_agregado_param`(
  stddev_hora_minima FLOAT64,
  stddev_hora_maxima FLOAT64,
  dif_horas_promedio FLOAT64,
  dias_visita_total INT64,
  pct_llega_antes FLOAT64,
  pct_sale_despues FLOAT64,
  -- Parámetros del POC
  stddev_trabajador_max FLOAT64,
  stddev_visitante_min FLOAT64,
  dif_horas_trabajador_min FLOAT64,
  pct_fuera_horario_max FLOAT64,
  dias_maximo INT64
)
RETURNS FLOAT64
AS (
  CASE
    -- CASO 1: Patrón laboral MUY claro
    WHEN dias_visita_total > dias_maximo
      AND stddev_hora_minima < stddev_trabajador_max
      AND stddev_hora_maxima < stddev_trabajador_max
      AND dif_horas_promedio >= dif_horas_trabajador_min
      THEN 0.05

    -- CASO 2: Patrón laboral claro
    WHEN dias_visita_total >= (dias_maximo - 1)
      AND stddev_hora_minima < (stddev_trabajador_max * 1.5)
      AND stddev_hora_maxima < (stddev_trabajador_max * 1.5)
      AND dif_horas_promedio >= dif_horas_trabajador_min
      THEN 0.1

    -- CASO 3: Probable trabajador
    WHEN (dias_visita_total >= (dias_maximo - 1)
          AND stddev_hora_minima < (stddev_trabajador_max * 2)
          AND stddev_hora_maxima < (stddev_trabajador_max * 2))
      OR (dias_visita_total >= (dias_maximo - 4)
          AND dif_horas_promedio >= (dif_horas_trabajador_min + 1))
      THEN 0.3

    -- CASO 4: Fuera de horario FRECUENTEMENTE
    WHEN dias_visita_total >= (dias_maximo - 4)
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

    -- DEFAULT (conservador)
    ELSE 0.60
  END
);


-- ============================================================================
-- PARTE 5: FUNCIÓN UDF - FACTOR DE FRECUENCIA (parametrizada)
-- ============================================================================

CREATE OR REPLACE FUNCTION `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_frecuencia_param`(
  dias_visita_total INT64,
  dias_minimo INT64,
  dias_maximo INT64
)
RETURNS FLOAT64
AS (
  CASE
    -- Menor que mínimo
    WHEN dias_visita_total < dias_minimo THEN 0.3

    -- En el mínimo
    WHEN dias_visita_total = dias_minimo THEN 1.0

    -- Entre mínimo y máximo (gradiente)
    WHEN dias_visita_total <= dias_maximo THEN
      1.0 - (0.7 * (dias_visita_total - dias_minimo) / NULLIF(dias_maximo - dias_minimo, 0))

    -- Mayor que máximo
    ELSE 0.1
  END
);


-- ============================================================================
-- PARTE 6: FUNCIÓN UDF - PROBABILIDAD FINAL POR DÍA (parametrizada)
-- ============================================================================

CREATE OR REPLACE FUNCTION `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_visita_dia_param`(
  -- Variables del DÍA
  prob_espacial FLOAT64,
  tiempo_ok_segundos INT64,
  tiempo_no_ok_segundos INT64,
  dif_horas FLOAT64,
  llega_antes_abrir BOOL,
  sale_despues_cerrar BOOL,

  -- Variables AGREGADAS del usuario
  stddev_hora_minima FLOAT64,
  stddev_hora_maxima FLOAT64,
  dif_horas_promedio FLOAT64,
  dias_visita_total INT64,
  pct_llega_antes FLOAT64,
  pct_sale_despues FLOAT64,

  -- Parámetros del POC
  tiempo_min_valido INT64,
  tiempo_max_valido INT64,
  tiempo_optimo_min INT64,
  tiempo_optimo_max INT64,
  dias_minimo INT64,
  dias_maximo INT64,
  ratio_minimo FLOAT64,
  ratio_optimo FLOAT64,
  stddev_trabajador_max FLOAT64,
  stddev_visitante_min FLOAT64,
  dif_horas_trabajador_min FLOAT64,
  pct_fuera_horario_max FLOAT64,

  -- PESOS (para ajustar importancia)
  peso_espacial FLOAT64,
  peso_temporal FLOAT64,
  peso_patron FLOAT64
)
RETURNS FLOAT64
AS (
  -- Probabilidad = producto ponderado de componentes
  -- peso < 1.0 = suaviza (eleva valores bajos, reduce impacto negativo)
  -- peso = 1.0 = sin cambio
  -- peso > 1.0 = acentúa (penaliza más valores bajos)

  POWER(prob_espacial, peso_espacial) *

  -- Componente temporal del DÍA (prob_temporal_dia * factor_dia)
  POWER(
    `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_temporal_dia_param`(
      tiempo_ok_segundos,
      SAFE_DIVIDE(tiempo_ok_segundos, tiempo_ok_segundos + tiempo_no_ok_segundos),
      tiempo_min_valido,
      tiempo_max_valido,
      tiempo_optimo_min,
      tiempo_optimo_max,
      ratio_minimo,
      ratio_optimo
    ) *
    `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_dia_param`(
      dif_horas,
      llega_antes_abrir,
      sale_despues_cerrar,
      dif_horas_trabajador_min
    ),
    peso_temporal
  ) *

  -- Componente de patrón AGREGADO (frecuencia * patron_agregado)
  POWER(
    `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_frecuencia_param`(
      dias_visita_total,
      dias_minimo,
      dias_maximo
    ) *
    `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_patron_agregado_param`(
      IFNULL(stddev_hora_minima, 999),
      IFNULL(stddev_hora_maxima, 999),
      dif_horas_promedio,
      dias_visita_total,
      pct_llega_antes,
      pct_sale_despues,
      stddev_trabajador_max,
      stddev_visitante_min,
      dif_horas_trabajador_min,
      pct_fuera_horario_max,
      dias_maximo
    ),
    peso_patron
  )
);


-- ============================================================================
-- PARTE 7: APLICACIÓN DEL MODELO - EJEMPLO CON VOLVO
-- ============================================================================

-- Paso 1: Obtener configuración del POC
CREATE OR REPLACE TEMP TABLE CONFIG_POC_DIA AS
SELECT *
FROM `mo-advertising-sta.ADVERTISING_TEST.CONFIG_MODELO_PARAMETRIZADA`
WHERE tipo_poc = 'CONCESIONARIO';  -- CAMBIAR SEGÚN POC


-- Paso 2: Calcular ESTADÍSTICAS AGREGADAS por usuario-ubicación
CREATE OR REPLACE TEMP TABLE PATRON_USUARIOS_PARAM AS
SELECT
  v.msisdn,
  v.id_ubicacion,
  c.tipo_poc,

  -- Frecuencia
  COUNT(DISTINCT v.fecha) as dias_visita_total,

  -- Variabilidad horaria (patrón agregado)
  STDDEV(v.hora_minima) as stddev_hora_minima,
  STDDEV(v.hora_maxima) as stddev_hora_maxima,

  -- Promedios
  AVG(v.dif_horas) as dif_horas_promedio,
  AVG(v.hora_minima) as hora_minima_promedio,
  AVG(v.hora_maxima) as hora_maxima_promedio,

  -- Porcentaje de días fuera de horario
  100.0 * SUM(CASE WHEN v.hora_minima < c.hora_apertura THEN 1 ELSE 0 END) / COUNT(*) as pct_llega_antes,
  100.0 * SUM(CASE WHEN v.hora_maxima > c.hora_cierre THEN 1 ELSE 0 END) / COUNT(*) as pct_sale_despues,

  -- Traer todos los parámetros del POC
  c.hora_apertura,
  c.hora_cierre,
  c.tiempo_min_valido,
  c.tiempo_max_valido,
  c.tiempo_optimo_min,
  c.tiempo_optimo_max,
  c.dias_minimo,
  c.dias_maximo,
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
CROSS JOIN CONFIG_POC_DIA c
WHERE v.poc = 'VOLVO_XC40-AON_ABR2026_4'  -- CAMBIAR SEGÚN CAMPAÑA
  AND v.PERIODO = 'CAMPAIGN'
  AND v.tiempo_total_ok_dia > 0
GROUP BY
  v.msisdn, v.id_ubicacion, c.tipo_poc,
  c.hora_apertura, c.hora_cierre,
  c.tiempo_min_valido, c.tiempo_max_valido, c.tiempo_optimo_min, c.tiempo_optimo_max,
  c.dias_minimo, c.dias_maximo,
  c.ratio_minimo, c.ratio_optimo, c.stddev_trabajador_max, c.stddev_visitante_min,
  c.dif_horas_trabajador_min, c.pct_fuera_horario_max,
  c.umbral_muy_probable, c.umbral_probable, c.umbral_posible, c.umbral_dudoso,
  c.peso_espacial, c.peso_temporal, c.peso_patron;


-- Paso 3: Evaluar CADA DÍA con contexto agregado
CREATE OR REPLACE TABLE `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_GEN_DIA` AS
SELECT
  v.msisdn,
  v.id_ubicacion,
  v.fecha,
  v.DIA_SEMANA,
  v.poc,
  p.tipo_poc,

  -- Variables del DÍA
  v.tiempo_total_ok_dia,
  v.tiempo_total_no_ok_dia,
  v.dif_horas,
  v.hora_minima,
  v.hora_maxima,
  v.PROBABILIDAD_VISITA_OK as prob_espacial,

  -- Variables AGREGADAS del usuario
  p.dias_visita_total,
  p.stddev_hora_minima,
  p.stddev_hora_maxima,
  p.dif_horas_promedio,
  p.hora_minima_promedio,
  p.hora_maxima_promedio,
  p.pct_llega_antes,
  p.pct_sale_despues,

  -- Variables derivadas del día
  SAFE_DIVIDE(v.tiempo_total_ok_dia, v.tiempo_total_ok_dia + v.tiempo_total_no_ok_dia) as ratio_horario,
  CASE WHEN v.hora_minima < p.hora_apertura THEN TRUE ELSE FALSE END as llega_antes_abrir,
  CASE WHEN v.hora_maxima > p.hora_cierre THEN TRUE ELSE FALSE END as sale_despues_cerrar,

  -- PROBABILIDAD FINAL DEL DÍA
  `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_visita_dia_param`(
    v.PROBABILIDAD_VISITA_OK,
    v.tiempo_total_ok_dia,
    v.tiempo_total_no_ok_dia,
    v.dif_horas,
    CASE WHEN v.hora_minima < p.hora_apertura THEN TRUE ELSE FALSE END,
    CASE WHEN v.hora_maxima > p.hora_cierre THEN TRUE ELSE FALSE END,
    p.stddev_hora_minima,
    p.stddev_hora_maxima,
    p.dif_horas_promedio,
    p.dias_visita_total,
    p.pct_llega_antes,
    p.pct_sale_despues,
    -- Parámetros
    p.tiempo_min_valido,
    p.tiempo_max_valido,
    p.tiempo_optimo_min,
    p.tiempo_optimo_max,
    p.dias_minimo,
    p.dias_maximo,
    p.ratio_minimo,
    p.ratio_optimo,
    p.stddev_trabajador_max,
    p.stddev_visitante_min,
    p.dif_horas_trabajador_min,
    p.pct_fuera_horario_max,
    -- Pesos
    p.peso_espacial,
    p.peso_temporal,
    p.peso_patron
  ) as prob_visita_dia,

  -- Componentes individuales (para análisis)
  `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_temporal_dia_param`(
    v.tiempo_total_ok_dia,
    SAFE_DIVIDE(v.tiempo_total_ok_dia, v.tiempo_total_ok_dia + v.tiempo_total_no_ok_dia),
    p.tiempo_min_valido,
    p.tiempo_max_valido,
    p.tiempo_optimo_min,
    p.tiempo_optimo_max,
    p.ratio_minimo,
    p.ratio_optimo
  ) as prob_temporal_dia,

  `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_dia_param`(
    v.dif_horas,
    CASE WHEN v.hora_minima < p.hora_apertura THEN TRUE ELSE FALSE END,
    CASE WHEN v.hora_maxima > p.hora_cierre THEN TRUE ELSE FALSE END,
    p.dif_horas_trabajador_min
  ) as factor_dia,

  `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_frecuencia_param`(
    p.dias_visita_total,
    p.dias_minimo,
    p.dias_maximo
  ) as factor_frecuencia,

  `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_patron_agregado_param`(
    IFNULL(p.stddev_hora_minima, 999),
    IFNULL(p.stddev_hora_maxima, 999),
    p.dif_horas_promedio,
    p.dias_visita_total,
    p.pct_llega_antes,
    p.pct_sale_despues,
    p.stddev_trabajador_max,
    p.stddev_visitante_min,
    p.dif_horas_trabajador_min,
    p.pct_fuera_horario_max,
    p.dias_maximo
  ) as factor_patron_agregado,

  -- Parámetros (para clasificación)
  p.umbral_muy_probable,
  p.umbral_probable,
  p.umbral_posible,
  p.umbral_dudoso,
  p.tiempo_optimo_min,
  p.tiempo_optimo_max

FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_UBICACION_GEO_TILES_CELIA_ISA_V2` v
INNER JOIN PATRON_USUARIOS_PARAM p
  ON v.msisdn = p.msisdn
  AND v.id_ubicacion = p.id_ubicacion
WHERE v.poc = 'VOLVO_XC40-AON_ABR2026_4'  -- CAMBIAR SEGÚN CAMPAÑA
  AND v.PERIODO = 'CAMPAIGN'
  AND v.tiempo_total_ok_dia > 0;


-- Paso 4: Clasificar cada día
CREATE OR REPLACE TABLE `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_GEN_DIA` AS
SELECT
  *,

  -- Clasificación del día
  CASE
    WHEN prob_visita_dia >= umbral_muy_probable THEN 'VISITA_MUY_PROBABLE'
    WHEN prob_visita_dia >= umbral_probable THEN 'VISITA_PROBABLE'
    WHEN prob_visita_dia >= umbral_posible THEN 'VISITA_POSIBLE'
    WHEN prob_visita_dia >= umbral_dudoso THEN 'DUDOSO'
    ELSE 'DESCARTADO'
  END as clasificacion_final,

  -- ¿Válido con filtro actual?
  CASE
    WHEN tiempo_total_ok_dia BETWEEN tiempo_optimo_min AND tiempo_optimo_max
      AND tiempo_total_no_ok_dia = 0
    THEN TRUE
    ELSE FALSE
  END as valido_filtro_actual,

  -- ¿Recuperado con modelo?
  CASE
    WHEN tiempo_total_ok_dia BETWEEN tiempo_optimo_min AND tiempo_optimo_max
      AND tiempo_total_no_ok_dia > 0
      AND prob_visita_dia >= umbral_probable
    THEN TRUE
    ELSE FALSE
  END as recuperado_con_modelo

FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_GEN_DIA`;


-- ============================================================================
-- PARTE 8: QUERIES DE VALIDACIÓN
-- ============================================================================

-- Query A: Resumen por clasificación (visitas/día)
SELECT
  tipo_poc,
  clasificacion_final,
  COUNT(*) as n_visitas,
  COUNT(DISTINCT msisdn) as n_usuarios_unicos,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(PARTITION BY tipo_poc), 2) as pct_visitas,

  ROUND(AVG(prob_visita_dia), 4) as prob_visita_promedio,
  ROUND(AVG(prob_espacial), 4) as prob_espacial_promedio,
  ROUND(AVG(prob_temporal_dia), 4) as prob_temporal_dia_promedio,
  ROUND(AVG(factor_dia), 4) as factor_dia_promedio,
  ROUND(AVG(factor_frecuencia), 4) as factor_frecuencia_promedio,
  ROUND(AVG(factor_patron_agregado), 4) as factor_patron_agregado_promedio,

  ROUND(AVG(ratio_horario), 3) as ratio_horario_promedio,
  ROUND(AVG(tiempo_total_ok_dia / 60), 1) as tiempo_ok_min_promedio,
  ROUND(AVG(dif_horas), 1) as dif_horas_promedio,
  ROUND(AVG(dias_visita_total), 1) as dias_totales_promedio

FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_GEN_DIA`
GROUP BY tipo_poc, clasificacion_final
ORDER BY
  tipo_poc,
  CASE clasificacion_final
    WHEN 'VISITA_MUY_PROBABLE' THEN 1
    WHEN 'VISITA_PROBABLE' THEN 2
    WHEN 'VISITA_POSIBLE' THEN 3
    WHEN 'DUDOSO' THEN 4
    ELSE 5
  END;


-- Query B: Comparación filtro vs modelo (por visitas)
SELECT
  tipo_poc,
  'Visitas válidas con filtro actual' as metodo,
  COUNT(*) as n_visitas,
  COUNT(DISTINCT msisdn) as n_usuarios
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_GEN_DIA`
WHERE valido_filtro_actual = TRUE
GROUP BY tipo_poc

UNION ALL

SELECT
  tipo_poc,
  'Visitas válidas con modelo (prob >= umbral_probable)' as metodo,
  COUNT(*) as n_visitas,
  COUNT(DISTINCT msisdn) as n_usuarios
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_GEN_DIA`
WHERE prob_visita_dia >= umbral_probable
GROUP BY tipo_poc

UNION ALL

SELECT
  tipo_poc,
  'Visitas recuperadas con modelo' as metodo,
  COUNT(*) as n_visitas,
  COUNT(DISTINCT msisdn) as n_usuarios
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_GEN_DIA`
WHERE recuperado_con_modelo = TRUE
GROUP BY tipo_poc

ORDER BY tipo_poc, metodo;


-- Query C: Análisis por usuario (% de sus días válidos)
WITH dias_validos_usuario AS (
  SELECT
    msisdn,
    id_ubicacion,
    COUNT(*) as n_dias_total,
    SUM(CASE WHEN clasificacion_final IN ('VISITA_MUY_PROBABLE', 'VISITA_PROBABLE') THEN 1 ELSE 0 END) as n_dias_validos,
    ROUND(100.0 * SUM(CASE WHEN clasificacion_final IN ('VISITA_MUY_PROBABLE', 'VISITA_PROBABLE') THEN 1 ELSE 0 END) / COUNT(*), 1) as pct_dias_validos,
    MAX(dias_visita_total) as dias_visita_total,
    MAX(stddev_hora_minima) as stddev_hora_minima
  FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_GEN_DIA`
  GROUP BY msisdn, id_ubicacion
)
SELECT
  CASE
    WHEN pct_dias_validos >= 80 THEN 'Alta validez (80%+)'
    WHEN pct_dias_validos >= 50 THEN 'Media validez (50-80%)'
    WHEN pct_dias_validos >= 20 THEN 'Baja validez (20-50%)'
    ELSE 'Muy baja (<20%)'
  END as bucket_validez,

  COUNT(*) as n_usuarios,
  ROUND(AVG(pct_dias_validos), 1) as pct_dias_validos_promedio,
  ROUND(AVG(dias_visita_total), 1) as dias_totales_promedio,
  ROUND(AVG(stddev_hora_minima), 2) as stddev_hora_min_promedio

FROM dias_validos_usuario
GROUP BY bucket_validez
ORDER BY
  CASE bucket_validez
    WHEN 'Alta validez (80%+)' THEN 1
    WHEN 'Media validez (50-80%)' THEN 2
    WHEN 'Baja validez (20-50%)' THEN 3
    ELSE 4
  END;


-- Query D: Top visitas para validación
SELECT
  msisdn,
  fecha,
  ROUND(tiempo_total_ok_dia / 60, 1) as tiempo_ok_min,
  ROUND(ratio_horario, 3) as ratio,
  dias_visita_total,
  ROUND(stddev_hora_minima, 2) as stddev_hora_min,
  ROUND(prob_temporal_dia, 4) as prob_temporal_dia,
  ROUND(factor_dia, 4) as factor_dia,
  ROUND(factor_frecuencia, 4) as factor_frecuencia,
  ROUND(factor_patron_agregado, 4) as factor_patron_agregado,
  ROUND(prob_visita_dia, 4) as prob_visita_final,
  clasificacion_final
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_GEN_DIA`
WHERE clasificacion_final = 'VISITA_MUY_PROBABLE'
ORDER BY prob_visita_dia DESC
LIMIT 100;


-- ============================================================================
-- FIN DEL MODELO GENÉRICO POR DÍA
-- ============================================================================

/*
============================================================================
CÓMO USAR
============================================================================

PASO 1: Configurar tipo POC (línea 276)
WHERE tipo_poc = 'TU_TIPO'

PASO 2: Configurar campaña (líneas 311 y 425)
WHERE v.poc = 'TU_CAMPAÑA'

PASO 3: Ejecutar todo el script

RESULTADO:
- Tabla por DÍA: VISITAS_CLASIFICADAS_GEN_DIA
- Una fila por cada (msisdn, fecha, ubicación)
- Pero con patrón agregado del usuario

VENTAJAS vs modelo agregado:
✅ Ves qué días específicos son válidos
✅ No pierdes visitas válidas ocasionales
✅ El patrón agregado detecta trabajadores
✅ Parametrizado: funciona para cualquier POC

DESVENTAJAS:
⚠️ Más filas (podría inflar números)
⚠️ Más lento de ejecutar
⚠️ Más complejo de interpretar

CUÁNDO USAR ESTE vs modelo agregado:
- ESTE: Cuando necesitas granularidad por día
- AGREGADO: Cuando solo necesitas "¿es visitante válido?"
*/
