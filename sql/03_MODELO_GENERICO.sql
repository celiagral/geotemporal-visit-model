-- ============================================================================
-- MODELO PROBABILÍSTICO DE ESTIMACIÓN DE VISITAS - GENÉRICO PARAMETRIZADO
-- Versión: 4.0 - UNIVERSAL
-- ============================================================================
--
-- MODELO ÚNICO que se adapta a cualquier tipo de POC mediante parámetros.
-- No necesitas crear un modelo por cada campaña - solo configurar parámetros.
--
-- VENTAJAS:
-- ✅ Un solo modelo para todos los tipos de POC
-- ✅ Fácil de mantener y actualizar
-- ✅ Parámetros centralizados en tabla de configuración
-- ✅ Reutilizable y escalable
--
-- ============================================================================

-- ============================================================================
-- PARTE 1: TABLA DE CONFIGURACIÓN PARAMETRIZADA POR TIPO DE POC
-- ============================================================================

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

    'Estricto. Visitas cortas planificadas. Horario reducido.' as notas
  )
]);


-- ============================================================================
-- PARTE 2: FUNCIÓN UDF - PROBABILIDAD TEMPORAL GENÉRICA
-- ============================================================================

CREATE OR REPLACE FUNCTION `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_temporal_generica`(
  tiempo_ok_segundos INT64,
  dias_visita INT64,
  ratio_horario FLOAT64,
  -- Parámetros del POC
  tiempo_min_valido INT64,
  tiempo_max_valido INT64,
  tiempo_optimo_min INT64,
  tiempo_optimo_max INT64,
  dias_minimo INT64,
  dias_maximo INT64,
  ratio_minimo FLOAT64,
  ratio_optimo FLOAT64
)
RETURNS FLOAT64
AS (
  -- Factor base por duración
  (CASE
    -- Menor que mínimo válido
    WHEN tiempo_ok_segundos < tiempo_min_valido THEN 0.2

    -- Entre mínimo y óptimo mínimo (corto pero válido)
    WHEN tiempo_ok_segundos < tiempo_optimo_min THEN 0.6

    -- Rango óptimo
    WHEN tiempo_ok_segundos BETWEEN tiempo_optimo_min AND tiempo_optimo_max THEN 1.0

    -- Entre óptimo máximo y máximo válido (largo pero aceptable)
    WHEN tiempo_ok_segundos < tiempo_max_valido THEN 0.7

    -- Mayor que máximo válido (muy largo, sospechoso)
    ELSE 0.15
  END)

  *

  -- Factor por frecuencia (RANGO: dias_minimo a dias_maximo)
  (CASE
    -- Menor que mínimo (posible ruido)
    WHEN dias_visita < dias_minimo THEN 0.3

    -- En el mínimo (visitante ocasional ideal)
    WHEN dias_visita = dias_minimo THEN 1.0

    -- Entre mínimo y máximo (escala descendente)
    -- A medida que se acerca al máximo, va bajando la probabilidad
    WHEN dias_visita <= dias_maximo THEN
      1.0 - (0.7 * (dias_visita - dias_minimo) / NULLIF(dias_maximo - dias_minimo, 0))

    -- Mayor que máximo (probable trabajador)
    ELSE 0.1
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
-- PARTE 3: FUNCIÓN UDF - FACTOR DE PATRÓN HORARIO GENÉRICO
-- ============================================================================

CREATE OR REPLACE FUNCTION `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_patron_generico`(
  stddev_hora_minima FLOAT64,
  stddev_hora_maxima FLOAT64,
  dif_horas_promedio FLOAT64,
  dias_visita INT64,
  llega_antes_abrir BOOL,
  sale_despues_cerrar BOOL,
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
    -- Supera máximo + horarios consistentes + jornadas largas
    WHEN dias_visita > dias_maximo
      AND stddev_hora_minima < stddev_trabajador_max
      AND stddev_hora_maxima < stddev_trabajador_max
      AND dif_horas_promedio >= dif_horas_trabajador_min
      THEN 0.05

    -- CASO 2: Patrón laboral claro
    -- Cerca del máximo + horarios muy consistentes + jornadas largas
    WHEN dias_visita >= (dias_maximo - 1)
      AND stddev_hora_minima < (stddev_trabajador_max * 1.5)
      AND stddev_hora_maxima < (stddev_trabajador_max * 1.5)
      AND dif_horas_promedio >= dif_horas_trabajador_min
      THEN 0.1

    -- CASO 3: Probable trabajador
    -- Cerca del máximo + horarios consistentes O jornadas muy largas
    WHEN (dias_visita >= (dias_maximo - 1)
          AND stddev_hora_minima < (stddev_trabajador_max * 2)
          AND stddev_hora_maxima < (stddev_trabajador_max * 2))
      OR (dias_visita >= (dias_maximo - 4)
          AND dif_horas_promedio >= (dif_horas_trabajador_min + 1))
      THEN 0.3

    -- CASO 4: Fuera de horario FRECUENTEMENTE
    WHEN dias_visita >= (dias_maximo - 4)
      AND (pct_llega_antes > pct_fuera_horario_max OR pct_sale_despues > pct_fuera_horario_max)
      THEN 0.4

    -- CASO 5: Fuera de horario alguna vez
    WHEN dias_visita >= (dias_maximo - 4)
      AND (llega_antes_abrir OR sale_despues_cerrar)
      THEN 0.6

    -- CASO 6: Algo de consistencia
    WHEN stddev_hora_minima < stddev_visitante_min
      AND stddev_hora_maxima < stddev_visitante_min
      AND dias_visita >= 2
      THEN 0.75

    -- CASO 7: Horarios variables (visitante claro)
    WHEN stddev_hora_minima >= stddev_visitante_min
      OR stddev_hora_maxima >= stddev_visitante_min
      OR dias_visita = 1
      THEN 1.0

    -- DEFAULT (conservador)
    ELSE 0.60
  END
);


-- ============================================================================
-- PARTE 4: FUNCIÓN UDF - PROBABILIDAD FINAL GENÉRICA
-- ============================================================================

CREATE OR REPLACE FUNCTION `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_visita_generica`(
  -- Variables observadas
  prob_espacial FLOAT64,
  tiempo_ok_segundos INT64,
  tiempo_no_ok_segundos INT64,
  dias_visita INT64,
  stddev_hora_minima FLOAT64,
  stddev_hora_maxima FLOAT64,
  dif_horas_promedio FLOAT64,
  llega_antes_abrir BOOL,
  sale_despues_cerrar BOOL,
  pct_llega_antes FLOAT64,
  pct_sale_despues FLOAT64,

  -- Parámetros del POC (todos los necesarios)
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
  pct_fuera_horario_max FLOAT64
)
RETURNS FLOAT64
AS (
  -- PROBABILIDAD FINAL = producto de componentes
  prob_espacial *

  `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_temporal_generica`(
    tiempo_ok_segundos,
    dias_visita,
    SAFE_DIVIDE(tiempo_ok_segundos, tiempo_ok_segundos + tiempo_no_ok_segundos),
    tiempo_min_valido,
    tiempo_max_valido,
    tiempo_optimo_min,
    tiempo_optimo_max,
    dias_minimo,
    dias_maximo,
    ratio_minimo,
    ratio_optimo
  ) *

  `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_patron_generico`(
    IFNULL(stddev_hora_minima, 999),
    IFNULL(stddev_hora_maxima, 999),
    dif_horas_promedio,
    dias_visita,
    llega_antes_abrir,
    sale_despues_cerrar,
    IFNULL(pct_llega_antes, 0),
    IFNULL(pct_sale_despues, 0),
    stddev_trabajador_max,
    stddev_visitante_min,
    dif_horas_trabajador_min,
    pct_fuera_horario_max,
    dias_maximo
  )
);


-- ============================================================================
-- PARTE 5: APLICACIÓN DEL MODELO - EJEMPLO CON VOLVO
-- ============================================================================
-- NOTA: Cambiar WHERE poc = '...' para aplicar a otra campaña

-- Paso 1: Obtener configuración del POC
CREATE OR REPLACE TEMP TABLE CONFIG_POC AS
SELECT *
FROM `mo-advertising-sta.ADVERTISING_TEST.CONFIG_MODELO_PARAMETRIZADA`
WHERE tipo_poc = 'CONCESIONARIO';  -- CAMBIAR SEGÚN POC


-- Paso 2: Crear tabla agregada con estadísticas por usuario
CREATE OR REPLACE TEMP TABLE USUARIOS_AGREGADOS_GEN AS
SELECT
  v.msisdn,
  v.id_ubicacion,
  v.poc,
  c.tipo_poc,

  -- Estadísticas temporales
  AVG(v.tiempo_total_ok_dia) as tiempo_ok_promedio,
  AVG(v.tiempo_total_no_ok_dia) as tiempo_no_ok_promedio,
  AVG(v.dif_horas) as dif_horas_promedio,
  COUNT(DISTINCT v.fecha) as dias_visita,

  -- Estadísticas espaciales
  AVG(v.PROBABILIDAD_VISITA_OK) as prob_espacial_promedio,

  -- Estadísticas de patrón
  STDDEV(v.hora_minima) as stddev_hora_minima,
  STDDEV(v.hora_maxima) as stddev_hora_maxima,
  AVG(v.hora_minima) as hora_minima_promedio,
  AVG(v.hora_maxima) as hora_maxima_promedio,

  -- Flags fuera de horario (usando parámetros)
  MAX(CASE WHEN v.hora_minima < c.hora_apertura THEN TRUE ELSE FALSE END) as llega_antes_abrir_alguna_vez,
  MAX(CASE WHEN v.hora_maxima > c.hora_cierre THEN TRUE ELSE FALSE END) as sale_despues_cerrar_alguna_vez,
  100.0 * SUM(CASE WHEN v.hora_minima < c.hora_apertura THEN 1 ELSE 0 END) / COUNT(*) as pct_llega_antes,
  100.0 * SUM(CASE WHEN v.hora_maxima > c.hora_cierre THEN 1 ELSE 0 END) / COUNT(*) as pct_sale_despues,

  -- Traer todos los parámetros del POC
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
  c.umbral_dudoso

FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_UBICACION_GEO_TILES_CELIA_ISA_V2` v
CROSS JOIN CONFIG_POC c
WHERE v.poc = 'VOLVO_XC40-AON_ABR2026_4'  -- CAMBIAR SEGÚN CAMPAÑA
  AND v.PERIODO = 'CAMPAIGN'
  AND v.tiempo_total_ok_dia > 0
GROUP BY
  v.msisdn, v.id_ubicacion, v.poc, c.tipo_poc,
  c.tiempo_min_valido, c.tiempo_max_valido, c.tiempo_optimo_min, c.tiempo_optimo_max,
  c.dias_minimo, c.dias_maximo,
  c.ratio_minimo, c.ratio_optimo, c.stddev_trabajador_max, c.stddev_visitante_min,
  c.dif_horas_trabajador_min, c.pct_fuera_horario_max,
  c.umbral_muy_probable, c.umbral_probable, c.umbral_posible, c.umbral_dudoso;


-- Paso 3: Calcular probabilidades
CREATE OR REPLACE TABLE `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_GEN` AS
SELECT
  *,

  -- Ratio horario
  SAFE_DIVIDE(tiempo_ok_promedio, tiempo_ok_promedio + tiempo_no_ok_promedio) as ratio_horario,

  -- PROBABILIDAD FINAL (llamada única a función genérica)
  `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_visita_generica`(
    prob_espacial_promedio,
    CAST(tiempo_ok_promedio AS INT64),
    CAST(tiempo_no_ok_promedio AS INT64),
    dias_visita,
    stddev_hora_minima,
    stddev_hora_maxima,
    dif_horas_promedio,
    llega_antes_abrir_alguna_vez,
    sale_despues_cerrar_alguna_vez,
    pct_llega_antes,
    pct_sale_despues,
    -- Parámetros
    tiempo_min_valido,
    tiempo_max_valido,
    tiempo_optimo_min,
    tiempo_optimo_max,
    dias_minimo,
    dias_maximo,
    ratio_minimo,
    ratio_optimo,
    stddev_trabajador_max,
    stddev_visitante_min,
    dif_horas_trabajador_min,
    pct_fuera_horario_max
  ) as prob_visita_final,

  -- Componentes individuales
  `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_temporal_generica`(
    CAST(tiempo_ok_promedio AS INT64),
    dias_visita,
    SAFE_DIVIDE(tiempo_ok_promedio, tiempo_ok_promedio + tiempo_no_ok_promedio),
    tiempo_min_valido,
    tiempo_max_valido,
    tiempo_optimo_min,
    tiempo_optimo_max,
    dias_minimo,
    dias_maximo,
    ratio_minimo,
    ratio_optimo
  ) as prob_temporal,

  `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_patron_generico`(
    IFNULL(stddev_hora_minima, 999),
    IFNULL(stddev_hora_maxima, 999),
    dif_horas_promedio,
    dias_visita,
    llega_antes_abrir_alguna_vez,
    sale_despues_cerrar_alguna_vez,
    pct_llega_antes,
    pct_sale_despues,
    stddev_trabajador_max,
    stddev_visitante_min,
    dif_horas_trabajador_min,
    pct_fuera_horario_max,
    dias_maximo
  ) as factor_patron

FROM USUARIOS_AGREGADOS_GEN;


-- Paso 4: Clasificar usuarios (usando umbrales parametrizados)
CREATE OR REPLACE TABLE `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_GEN` AS
SELECT
  *,

  -- Clasificación por umbrales parametrizados
  CASE
    WHEN prob_visita_final >= umbral_muy_probable THEN 'VISITA_MUY_PROBABLE'
    WHEN prob_visita_final >= umbral_probable THEN 'VISITA_PROBABLE'
    WHEN prob_visita_final >= umbral_posible THEN 'VISITA_POSIBLE'
    WHEN prob_visita_final >= umbral_dudoso THEN 'DUDOSO'
    ELSE 'DESCARTADO'
  END as clasificacion_final,

  -- ¿Sería válido con filtro basado en parámetros?
  CASE
    WHEN tiempo_ok_promedio BETWEEN tiempo_optimo_min AND tiempo_optimo_max
      AND tiempo_no_ok_promedio = 0
    THEN TRUE
    ELSE FALSE
  END as valido_filtro_actual,

  -- ¿Se recupera con el modelo?
  CASE
    WHEN tiempo_ok_promedio BETWEEN tiempo_optimo_min AND tiempo_optimo_max
      AND tiempo_no_ok_promedio > 0
      AND prob_visita_final >= umbral_probable
    THEN TRUE
    ELSE FALSE
  END as recuperado_con_modelo

FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_GEN`;


-- ============================================================================
-- PARTE 6: QUERIES DE VALIDACIÓN
-- ============================================================================

-- Query A: Resumen de clasificaciones
SELECT
  tipo_poc,
  clasificacion_final,
  COUNT(*) as n_usuarios,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(PARTITION BY tipo_poc), 2) as pct_usuarios,

  ROUND(AVG(prob_visita_final), 4) as prob_visita_promedio,
  ROUND(AVG(prob_espacial_promedio), 4) as prob_espacial_promedio,
  ROUND(AVG(prob_temporal), 4) as prob_temporal_promedio,
  ROUND(AVG(factor_patron), 4) as factor_patron_promedio,
  ROUND(AVG(ratio_horario), 3) as ratio_horario_promedio,
  ROUND(AVG(tiempo_ok_promedio / 60), 1) as tiempo_ok_min_promedio,
  ROUND(AVG(dias_visita), 1) as dias_promedio

FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_GEN`
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


-- Query B: Comparación filtro vs modelo
SELECT
  tipo_poc,
  'Válidos con filtro actual' as metodo,
  COUNT(*) as n_usuarios
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_GEN`
WHERE valido_filtro_actual = TRUE
GROUP BY tipo_poc

UNION ALL

SELECT
  tipo_poc,
  'Válidos con modelo (prob >= umbral_probable)' as metodo,
  COUNT(*) as n_usuarios
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_GEN`
WHERE prob_visita_final >= umbral_probable
GROUP BY tipo_poc

UNION ALL

SELECT
  tipo_poc,
  'Recuperados con modelo' as metodo,
  COUNT(*) as n_usuarios
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_GEN`
WHERE recuperado_con_modelo = TRUE
GROUP BY tipo_poc

ORDER BY tipo_poc, metodo;


-- ============================================================================
-- FIN DEL MODELO GENÉRICO
-- ============================================================================

/*
============================================================================
CÓMO USAR ESTE MODELO PARA UNA NUEVA CAMPAÑA
============================================================================

OPCIÓN 1: Si ya existe el tipo_poc en la configuración
--------------------------------------------------------
1. Cambiar línea 454: WHERE tipo_poc = 'TU_TIPO'
2. Cambiar línea 515: WHERE v.poc = 'TU_CAMPAÑA'
3. Ejecutar

OPCIÓN 2: Si necesitas un nuevo tipo_poc
-----------------------------------------
1. Añadir nuevo STRUCT en CONFIG_MODELO_PARAMETRIZADA (Parte 1)
   con todos los parámetros ajustados para tu caso
2. Seguir Opción 1

EJEMPLO: Para Burger King (FANTA_GAMING)
-----------------------------------------
-- Ya está configurado 'RESTAURANTE' en la tabla
-- Solo cambiar:
WHERE tipo_poc = 'RESTAURANTE'
WHERE v.poc = 'FANTA_GAMING_JUN2026_CON_EXTERIOR'

VENTAJAS:
✅ NO necesitas crear nuevas funciones UDF
✅ NO necesitas duplicar código
✅ Solo ajustas parámetros
✅ Mantienes todo centralizado
✅ Fácil de escalar a 10, 20, 100 POCs diferentes

*/
