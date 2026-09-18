-- ============================================================================
-- MODELO PROBABILÍSTICO DE ESTIMACIÓN DE VISITAS
-- Versión: 3.0 COMPLETA
-- Incorpora: tiempo_ok, tiempo_no_ok, hora_min, hora_max, frecuencia, patrón
-- ============================================================================

-- ============================================================================
-- PARTE 1: TABLA DE CONFIGURACIÓN POR TIPO DE POC
-- ============================================================================

CREATE OR REPLACE TABLE `mo-advertising-sta.ADVERTISING_TEST.CONFIG_MODELO_VISITAS` AS
SELECT * FROM UNNEST([
  -- CONCESIONARIOS (Volvo, Mercedes, BMW, etc.)
  STRUCT(
    'CONCESIONARIO' as tipo_poc,
    'Concesionarios de vehículos' as descripcion,
    0.8 as umbral_ratio_minimo,
    0.15 as umbral_prob_minimo,
    1.5 as umbral_stddev_trabajador,
    'Estricto con ratio. Nadie vive al lado de un concesionario.' as notas
  ),

  -- SUPERMERCADOS (Mercadona, Lidl, etc.)
  STRUCT(
    'SUPERMERCADO' as tipo_poc,
    'Supermercados y tiendas de alimentación' as descripcion,
    0.5 as umbral_ratio_minimo,
    0.12 as umbral_prob_minimo,
    1.0 as umbral_stddev_trabajador,
    'Flexible con ratio. La gente vive cerca y visita a horas variables.' as notas
  ),

  -- RESTAURANTES
  STRUCT(
    'RESTAURANTE' as tipo_poc,
    'Restaurantes y cafeterías' as descripcion,
    0.7 as umbral_ratio_minimo,
    0.14 as umbral_prob_minimo,
    1.2 as umbral_stddev_trabajador,
    'Intermedio. Algunos vecinos, pero menos frecuente.' as notas
  ),

  -- CENTROS COMERCIALES
  STRUCT(
    'CENTRO_COMERCIAL' as tipo_poc,
    'Centros comerciales' as descripcion,
    0.6 as umbral_ratio_minimo,
    0.13 as umbral_prob_minimo,
    1.3 as umbral_stddev_trabajador,
    'Flexible. Muchos trabajadores pero también visitantes frecuentes.' as notas
  ),

  -- BANCOS
  STRUCT(
    'BANCO' as tipo_poc,
    'Oficinas bancarias' as descripcion,
    0.75 as umbral_ratio_minimo,
    0.15 as umbral_prob_minimo,
    1.5 as umbral_stddev_trabajador,
    'Estricto. Visitas cortas y en horario.' as notas
  )
]);


-- ============================================================================
-- PARTE 2: FUNCIÓN UDF - PROBABILIDAD TEMPORAL
-- ============================================================================

CREATE OR REPLACE FUNCTION `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_temporal`(
  tiempo_ok_segundos INT64,
  dias_visita INT64,
  ratio_horario FLOAT64,
  tipo_poc STRING
)
RETURNS FLOAT64
AS (
  -- Factor base por duración (tiempo_ok)
  (CASE
    -- Muy corto (< 15 min) - poco probable
    WHEN tiempo_ok_segundos < 900 THEN 0.2

    -- Corto pero válido (15-30 min) - probabilidad baja-media
    WHEN tiempo_ok_segundos < 1800 THEN 0.5

    -- Duración ideal: 30-60 min - probabilidad alta
    WHEN tiempo_ok_segundos < 3600 THEN 1.0

    -- Duración buena: 60-90 min - probabilidad alta
    WHEN tiempo_ok_segundos < 5400 THEN 0.95

    -- Duración media: 90-120 min - empieza a ser sospechoso
    WHEN tiempo_ok_segundos < 7200 THEN 0.7

    -- Largo: 2-3h - probable trabajador o visita muy larga
    WHEN tiempo_ok_segundos < 10800 THEN 0.4

    -- Muy largo: > 3h - muy probable trabajador
    ELSE 0.15
  END)

  *

  -- Factor por frecuencia (dias_visita)
  (CASE
    -- 1 día - visitante ocasional, alta probabilidad
    WHEN dias_visita = 1 THEN 1.0

    -- 2-3 días - visitante regular, buena probabilidad
    WHEN dias_visita BETWEEN 2 AND 3 THEN 0.9

    -- 4-5 días - visitante frecuente o trabajador, probabilidad media
    WHEN dias_visita BETWEEN 4 AND 5 THEN 0.6

    -- 6-9 días - probable trabajador, probabilidad baja
    WHEN dias_visita BETWEEN 6 AND 9 THEN 0.3

    -- 10+ días - muy probable trabajador
    ELSE 0.1
  END)

  *

  -- Factor por ratio de horario (ajustado por tipo_poc)
  (CASE tipo_poc
    -- CONCESIONARIO: Estricto
    WHEN 'CONCESIONARIO' THEN
      CASE
        WHEN ratio_horario >= 0.95 THEN 1.0
        WHEN ratio_horario >= 0.9 THEN 0.95
        WHEN ratio_horario >= 0.8 THEN 0.85
        WHEN ratio_horario >= 0.7 THEN 0.6
        WHEN ratio_horario >= 0.6 THEN 0.4
        WHEN ratio_horario >= 0.5 THEN 0.2
        ELSE 0.1
      END

    -- SUPERMERCADO: Flexible
    WHEN 'SUPERMERCADO' THEN
      CASE
        WHEN ratio_horario >= 0.9 THEN 1.0
        WHEN ratio_horario >= 0.7 THEN 0.95
        WHEN ratio_horario >= 0.5 THEN 0.85  -- Más flexible
        WHEN ratio_horario >= 0.3 THEN 0.6   -- Aún válido (vive cerca)
        ELSE 0.3
      END

    -- RESTAURANTE: Intermedio
    WHEN 'RESTAURANTE' THEN
      CASE
        WHEN ratio_horario >= 0.9 THEN 1.0
        WHEN ratio_horario >= 0.8 THEN 0.95
        WHEN ratio_horario >= 0.7 THEN 0.8
        WHEN ratio_horario >= 0.6 THEN 0.5
        ELSE 0.2
      END

    -- CENTRO_COMERCIAL: Intermedio-flexible
    WHEN 'CENTRO_COMERCIAL' THEN
      CASE
        WHEN ratio_horario >= 0.9 THEN 1.0
        WHEN ratio_horario >= 0.7 THEN 0.9
        WHEN ratio_horario >= 0.6 THEN 0.75
        WHEN ratio_horario >= 0.5 THEN 0.5
        ELSE 0.25
      END

    -- BANCO: Estricto
    WHEN 'BANCO' THEN
      CASE
        WHEN ratio_horario >= 0.95 THEN 1.0
        WHEN ratio_horario >= 0.9 THEN 0.95
        WHEN ratio_horario >= 0.8 THEN 0.8
        WHEN ratio_horario >= 0.75 THEN 0.6
        ELSE 0.2
      END

    -- DEFAULT: Usar configuración de CONCESIONARIO
    ELSE
      CASE
        WHEN ratio_horario >= 0.95 THEN 1.0
        WHEN ratio_horario >= 0.9 THEN 0.95
        WHEN ratio_horario >= 0.8 THEN 0.85
        WHEN ratio_horario >= 0.7 THEN 0.6
        ELSE 0.3
      END
  END)
);


-- ============================================================================
-- PARTE 3: FUNCIÓN UDF - FACTOR DE PATRÓN HORARIO
-- ============================================================================

CREATE OR REPLACE FUNCTION `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_patron_horario`(
  stddev_hora_minima FLOAT64,
  stddev_hora_maxima FLOAT64,
  dif_horas_promedio FLOAT64,
  dias_visita INT64,
  llega_antes_abrir BOOL,
  sale_despues_cerrar BOOL
)
RETURNS FLOAT64
AS (
  CASE
    -- CASO 1: Patrón laboral MUY claro (penalización FUERTE)
    -- Horarios super consistentes + jornadas largas + alta frecuencia
    WHEN dias_visita >= 5
      AND stddev_hora_minima < 1.0
      AND stddev_hora_maxima < 1.0
      AND dif_horas_promedio >= 7
      THEN 0.05  -- 95% de penalización

    -- CASO 2: Patrón laboral claro (penalización MUY FUERTE)
    -- Horarios muy consistentes + jornadas largas + frecuencia alta
    WHEN dias_visita >= 4
      AND stddev_hora_minima < 1.5
      AND stddev_hora_maxima < 1.5
      AND dif_horas_promedio >= 7
      THEN 0.1  -- 90% de penalización

    -- CASO 3: Probable trabajador (penalización FUERTE)
    -- Horarios consistentes + frecuencia alta o media-alta con jornadas largas
    WHEN (dias_visita >= 4 AND stddev_hora_minima < 2 AND stddev_hora_maxima < 2)
      OR (dias_visita >= 3 AND dif_horas_promedio >= 8)
      THEN 0.3  -- 70% de penalización

    -- CASO 4: Llega antes o sale después frecuentemente (penalización MEDIA)
    -- Solo si es frecuencia alta o media
    WHEN dias_visita >= 3
      AND (llega_antes_abrir OR sale_despues_cerrar)
      THEN 0.5  -- 50% de penalización

    -- CASO 5: Algo de consistencia (penalización LEVE)
    -- Horarios algo consistentes pero no tanto como trabajador
    WHEN stddev_hora_minima < 3
      AND stddev_hora_maxima < 3
      AND dias_visita >= 2
      THEN 0.7  -- 30% de penalización

    -- CASO 6: Horarios variables (SIN penalización)
    -- Patrón de visitante claro
    WHEN stddev_hora_minima >= 3
      OR stddev_hora_maxima >= 3
      OR dias_visita = 1
      THEN 1.0  -- Sin penalización

    -- CASO DEFAULT: Intermedio
    ELSE 0.8  -- 20% de penalización
  END
);


-- ============================================================================
-- PARTE 4: FUNCIÓN UDF - PROBABILIDAD FINAL DE VISITA
-- ============================================================================

CREATE OR REPLACE FUNCTION `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_visita`(
  -- Variables básicas
  prob_espacial FLOAT64,
  tiempo_ok_segundos INT64,
  tiempo_no_ok_segundos INT64,
  dias_visita INT64,

  -- Variables de patrón horario
  stddev_hora_minima FLOAT64,
  stddev_hora_maxima FLOAT64,
  dif_horas_promedio FLOAT64,
  llega_antes_abrir BOOL,
  sale_despues_cerrar BOOL,

  -- Configuración
  tipo_poc STRING
)
RETURNS FLOAT64
AS (
  -- Cálculo de ratio_horario
  LET ratio_horario = SAFE_DIVIDE(
    tiempo_ok_segundos,
    tiempo_ok_segundos + tiempo_no_ok_segundos
  );

  -- Cálculo de probabilidad temporal
  LET prob_temporal = `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_temporal`(
    tiempo_ok_segundos,
    dias_visita,
    ratio_horario,
    tipo_poc
  );

  -- Cálculo de factor de patrón horario
  LET factor_patron = `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_patron_horario`(
    IFNULL(stddev_hora_minima, 999),  -- Si NULL → sin patrón (1 solo día)
    IFNULL(stddev_hora_maxima, 999),
    dif_horas_promedio,
    dias_visita,
    llega_antes_abrir,
    sale_despues_cerrar
  );

  -- PROBABILIDAD FINAL
  prob_espacial * prob_temporal * factor_patron
);


-- ============================================================================
-- PARTE 5: APLICACIÓN DEL MODELO A DATOS VOLVO
-- ============================================================================

-- Paso 1: Crear tabla con variables agregadas por usuario-ubicación
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
  MAX(CASE WHEN hora_minima < 10 THEN TRUE ELSE FALSE END) as llega_antes_abrir_alguna_vez,
  MAX(CASE WHEN hora_maxima > 20 THEN TRUE ELSE FALSE END) as sale_despues_cerrar_alguna_vez,

  -- Tipo POC (asumimos CONCESIONARIO para Volvo)
  'CONCESIONARIO' as tipo_poc

FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_UBICACION_GEO_TILES_CELIA_ISA_V2`
WHERE poc = 'VOLVO_XC40-AON_ABR2026_4'
  AND PERIODO = 'CAMPAIGN'
  AND tiempo_total_ok_dia > 0
GROUP BY msisdn, id_ubicacion, poc;


-- Paso 2: Aplicar modelo y calcular probabilidad de visita
CREATE OR REPLACE TABLE `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_VOLVO` AS
SELECT
  *,

  -- Calcular ratio
  SAFE_DIVIDE(tiempo_ok_promedio, tiempo_ok_promedio + tiempo_no_ok_promedio) as ratio_horario,

  -- Calcular probabilidad de visita
  `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_visita`(
    prob_espacial_promedio,
    CAST(tiempo_ok_promedio AS INT64),
    CAST(tiempo_no_ok_promedio AS INT64),
    dias_visita,
    stddev_hora_minima,
    stddev_hora_maxima,
    dif_horas_promedio,
    llega_antes_abrir_alguna_vez,
    sale_despues_cerrar_alguna_vez,
    tipo_poc
  ) as prob_visita_final,

  -- Componentes del modelo (para análisis)
  `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_temporal`(
    CAST(tiempo_ok_promedio AS INT64),
    dias_visita,
    SAFE_DIVIDE(tiempo_ok_promedio, tiempo_ok_promedio + tiempo_no_ok_promedio),
    tipo_poc
  ) as prob_temporal,

  `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_patron_horario`(
    IFNULL(stddev_hora_minima, 999),
    IFNULL(stddev_hora_maxima, 999),
    dif_horas_promedio,
    dias_visita,
    llega_antes_abrir_alguna_vez,
    sale_despues_cerrar_alguna_vez
  ) as factor_patron

FROM USUARIOS_AGREGADOS;


-- Paso 3: Clasificar usuarios según probabilidad
CREATE OR REPLACE TABLE `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_VOLVO` AS
SELECT
  *,

  -- Clasificación por probabilidad final
  CASE
    WHEN prob_visita_final >= 0.20 THEN 'VISITA_MUY_PROBABLE'
    WHEN prob_visita_final >= 0.15 THEN 'VISITA_PROBABLE'
    WHEN prob_visita_final >= 0.10 THEN 'VISITA_POSIBLE'
    WHEN prob_visita_final >= 0.05 THEN 'DUDOSO'
    ELSE 'DESCARTADO'
  END as clasificacion_final,

  -- ¿Sería válido con filtro actual? (30-90 min + sin tiempo_no_ok)
  CASE
    WHEN tiempo_ok_promedio BETWEEN 1800 AND 5400
      AND tiempo_no_ok_promedio = 0
    THEN TRUE
    ELSE FALSE
  END as valido_filtro_actual,

  -- ¿Se recupera con el modelo?
  CASE
    WHEN tiempo_ok_promedio BETWEEN 1800 AND 5400
      AND tiempo_no_ok_promedio > 0
      AND prob_visita_final >= 0.15
    THEN TRUE
    ELSE FALSE
  END as recuperado_con_modelo

FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_VOLVO`;


-- ============================================================================
-- PARTE 6: QUERIES DE VALIDACIÓN
-- ============================================================================

-- Query A: Resumen de clasificaciones
SELECT
  clasificacion_final,
  COUNT(*) as n_usuarios,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) as pct_usuarios,

  -- Promedios
  ROUND(AVG(prob_visita_final), 4) as prob_visita_promedio,
  ROUND(AVG(prob_espacial_promedio), 4) as prob_espacial_promedio,
  ROUND(AVG(prob_temporal), 4) as prob_temporal_promedio,
  ROUND(AVG(factor_patron), 4) as factor_patron_promedio,
  ROUND(AVG(ratio_horario), 3) as ratio_horario_promedio,
  ROUND(AVG(tiempo_ok_promedio / 60), 1) as tiempo_ok_min_promedio,
  ROUND(AVG(dias_visita), 1) as dias_promedio

FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_VOLVO`
GROUP BY clasificacion_final
ORDER BY
  CASE clasificacion_final
    WHEN 'VISITA_MUY_PROBABLE' THEN 1
    WHEN 'VISITA_PROBABLE' THEN 2
    WHEN 'VISITA_POSIBLE' THEN 3
    WHEN 'DUDOSO' THEN 4
    WHEN 'DESCARTADO' THEN 5
  END;


-- Query B: Comparación filtro actual vs modelo
SELECT
  'Válidos con filtro actual (30-90 min + sin NO_OK)' as metodo,
  SUM(CASE WHEN valido_filtro_actual THEN 1 ELSE 0 END) as n_usuarios
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_VOLVO`

UNION ALL

SELECT
  'Válidos con modelo (prob >= 0.15)' as metodo,
  SUM(CASE WHEN prob_visita_final >= 0.15 THEN 1 ELSE 0 END) as n_usuarios
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_VOLVO`

UNION ALL

SELECT
  'Recuperados con modelo' as metodo,
  SUM(CASE WHEN recuperado_con_modelo THEN 1 ELSE 0 END) as n_usuarios
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_VOLVO`

UNION ALL

SELECT
  'Incremento (%)' as metodo,
  CAST(ROUND(100.0 * SUM(CASE WHEN recuperado_con_modelo THEN 1 ELSE 0 END) /
    NULLIF(SUM(CASE WHEN valido_filtro_actual THEN 1 ELSE 0 END), 0), 1) AS INT64) as n_usuarios
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_VOLVO`;


-- Query C: Top 100 usuarios MUY_PROBABLE para validación manual
SELECT
  msisdn,
  dias_visita,
  ROUND(tiempo_ok_promedio / 60, 1) as tiempo_ok_min_promedio,
  ROUND(tiempo_no_ok_promedio / 60, 1) as tiempo_no_ok_min_promedio,
  ROUND(ratio_horario, 3) as ratio_horario,
  ROUND(hora_minima_promedio, 1) as hora_min_promedio,
  ROUND(hora_maxima_promedio, 1) as hora_max_promedio,
  ROUND(stddev_hora_minima, 2) as stddev_hora_min,
  ROUND(stddev_hora_maxima, 2) as stddev_hora_max,
  ROUND(prob_espacial_promedio, 4) as prob_espacial,
  ROUND(prob_temporal, 4) as prob_temporal,
  ROUND(factor_patron, 4) as factor_patron,
  ROUND(prob_visita_final, 4) as prob_visita_final,
  valido_filtro_actual,
  recuperado_con_modelo
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_VOLVO`
WHERE clasificacion_final = 'VISITA_MUY_PROBABLE'
ORDER BY prob_visita_final DESC
LIMIT 100;


-- Query D: Usuarios recuperados para validación
SELECT
  msisdn,
  dias_visita,
  ROUND(tiempo_ok_promedio / 60, 1) as tiempo_ok_min_promedio,
  ROUND(tiempo_no_ok_promedio / 60, 1) as tiempo_no_ok_min_promedio,
  ROUND(ratio_horario, 3) as ratio_horario,
  ROUND(stddev_hora_minima, 2) as stddev_hora_min,
  ROUND(prob_visita_final, 4) as prob_visita_final,
  clasificacion_final
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_VOLVO`
WHERE recuperado_con_modelo = TRUE
ORDER BY prob_visita_final DESC
LIMIT 100;


-- ============================================================================
-- FIN DEL MODELO
-- ============================================================================
