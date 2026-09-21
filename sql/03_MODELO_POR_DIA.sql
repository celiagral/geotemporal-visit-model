-- ============================================================================
-- MODELO PROBABILÍSTICO DE ESTIMACIÓN DE VISITAS
-- Versión: 3.2 - HÍBRIDO: POR DÍA + PATRÓN AGREGADO DEL USUARIO
-- ============================================================================
--
-- ENFOQUE HÍBRIDO (lo mejor de dos enfoques):
--
-- 1. EVALÚA CADA VISITA POR DÍA:
--    - tiempo_ok y ratio_horario del día específico
--    - dif_horas del día
--    - Si llega antes/sale después ese día
--
-- 2. ANALIZA EL PATRÓN AGREGADO DEL USUARIO:
--    - stddev_hora_minima/maxima (¿llega/sale siempre a la misma hora?)
--    - dif_horas_promedio (¿cuántas horas está en promedio?)
--    - dias_visita_total (frecuencia total)
--    - pct_llega_antes/sale_despues (% de días fuera de horario)
--
-- FÓRMULA:
--   P(visita válida) = P(espacial) ×
--                      P(temporal_dia) ×
--                      F(patrón_dia) ×
--                      F(frecuencia) ×
--                      F(patrón_usuario)
--
-- VENTAJAS:
-- ✅ Evalúa cada día independientemente (no se pierden visitas válidas ocasionales)
-- ✅ Detecta trabajadores por patrón agregado (horarios consistentes + alta frec)
-- ✅ Combina señales del día individual + comportamiento histórico del usuario
-- ✅ Más robusto contra falsos positivos (trabajadores) y falsos negativos (visitantes)
--
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
-- PARTE 2: FUNCIÓN UDF - PROBABILIDAD TEMPORAL (por día)
-- ============================================================================

CREATE OR REPLACE FUNCTION `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_temporal_dia`(
  tiempo_ok_segundos INT64,
  ratio_horario FLOAT64,
  tipo_poc STRING
)
RETURNS FLOAT64
AS (
  -- Factor base por duración (tiempo_ok del día)
  (CASE
    WHEN tiempo_ok_segundos < 900 THEN 0.2        -- < 15 min
    WHEN tiempo_ok_segundos < 1800 THEN 0.5       -- 15-30 min
    WHEN tiempo_ok_segundos < 3600 THEN 1.0       -- 30-60 min (ideal)
    WHEN tiempo_ok_segundos < 5400 THEN 0.95      -- 60-90 min
    WHEN tiempo_ok_segundos < 7200 THEN 0.7       -- 90-120 min
    WHEN tiempo_ok_segundos < 10800 THEN 0.4      -- 2-3h
    ELSE 0.15                                      -- > 3h
  END)

  *

  -- Factor por ratio de horario (ajustado por tipo_poc)
  (CASE tipo_poc
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

    WHEN 'SUPERMERCADO' THEN
      CASE
        WHEN ratio_horario >= 0.9 THEN 1.0
        WHEN ratio_horario >= 0.7 THEN 0.95
        WHEN ratio_horario >= 0.5 THEN 0.85
        WHEN ratio_horario >= 0.3 THEN 0.6
        ELSE 0.3
      END

    WHEN 'RESTAURANTE' THEN
      CASE
        WHEN ratio_horario >= 0.9 THEN 1.0
        WHEN ratio_horario >= 0.8 THEN 0.95
        WHEN ratio_horario >= 0.7 THEN 0.8
        WHEN ratio_horario >= 0.6 THEN 0.5
        ELSE 0.2
      END

    WHEN 'CENTRO_COMERCIAL' THEN
      CASE
        WHEN ratio_horario >= 0.9 THEN 1.0
        WHEN ratio_horario >= 0.7 THEN 0.9
        WHEN ratio_horario >= 0.6 THEN 0.75
        WHEN ratio_horario >= 0.5 THEN 0.5
        ELSE 0.25
      END

    WHEN 'BANCO' THEN
      CASE
        WHEN ratio_horario >= 0.95 THEN 1.0
        WHEN ratio_horario >= 0.9 THEN 0.95
        WHEN ratio_horario >= 0.8 THEN 0.8
        WHEN ratio_horario >= 0.75 THEN 0.6
        ELSE 0.2
      END

    ELSE  -- DEFAULT
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
-- PARTE 3A: FUNCIÓN UDF - FACTOR DE PATRÓN DEL DÍA
-- ============================================================================
-- Para un día individual, evaluamos:
-- - Duración de la jornada (dif_horas)
-- - Si llega antes/sale después del horario

CREATE OR REPLACE FUNCTION `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_patron_dia`(
  dif_horas FLOAT64,
  llega_antes_abrir BOOL,
  sale_despues_cerrar BOOL
)
RETURNS FLOAT64
AS (
  CASE
    -- CASO 1: Jornada MUY larga (> 8h) + fuera de horario
    WHEN dif_horas >= 8 AND (llega_antes_abrir OR sale_despues_cerrar)
      THEN 0.05  -- 95% penalización

    -- CASO 2: Jornada larga (7-8h)
    WHEN dif_horas >= 7
      THEN 0.2  -- 80% penalización

    -- CASO 3: Jornada media-larga (5-7h) + fuera de horario
    WHEN dif_horas >= 5 AND (llega_antes_abrir OR sale_despues_cerrar)
      THEN 0.4  -- 60% penalización

    -- CASO 4: Jornada media-larga (5-7h) dentro de horario
    WHEN dif_horas >= 5
      THEN 0.7  -- 30% penalización

    -- CASO 5: Llega antes o sale después (jornada corta)
    WHEN llega_antes_abrir OR sale_despues_cerrar
      THEN 0.8  -- 20% penalización

    -- CASO 6: Jornada normal (< 5h) dentro de horario
    ELSE 1.0  -- Sin penalización
  END
);


-- ============================================================================
-- PARTE 3B: FUNCIÓN UDF - FACTOR DE PATRÓN AGREGADO DEL USUARIO
-- ============================================================================
-- Evalúa el comportamiento del usuario a lo largo de TODOS sus días:
-- - Variabilidad horaria (stddev): ¿llega/sale siempre a la misma hora?
-- - Duración promedio de jornadas
-- - Frecuencia de llegadas/salidas fuera de horario

CREATE OR REPLACE FUNCTION `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_patron_usuario`(
  stddev_hora_minima FLOAT64,
  stddev_hora_maxima FLOAT64,
  dif_horas_promedio FLOAT64,
  dias_visita_total INT64,
  pct_llega_antes FLOAT64,    -- % de días que llega antes de abrir
  pct_sale_despues FLOAT64     -- % de días que sale después de cerrar
)
RETURNS FLOAT64
AS (
  CASE
    -- CASO 1: Patrón laboral MUY claro
    -- Horarios super consistentes + jornadas largas + alta frecuencia
    WHEN dias_visita_total >= 5
      AND stddev_hora_minima < 1.0
      AND stddev_hora_maxima < 1.0
      AND dif_horas_promedio >= 7
      THEN 0.05  -- 95% penalización

    -- CASO 2: Patrón laboral claro
    -- Horarios muy consistentes + jornadas largas + frecuencia alta
    WHEN dias_visita_total >= 4
      AND stddev_hora_minima < 1.5
      AND stddev_hora_maxima < 1.5
      AND dif_horas_promedio >= 7
      THEN 0.1  -- 90% penalización

    -- CASO 3: Probable trabajador
    -- Horarios consistentes + frecuencia alta o jornadas largas
    WHEN (dias_visita_total >= 4 AND stddev_hora_minima < 2 AND stddev_hora_maxima < 2)
      OR (dias_visita_total >= 3 AND dif_horas_promedio >= 8)
      THEN 0.3  -- 70% penalización

    -- CASO 4: Llega antes/sale después frecuentemente
    -- Más del 50% de los días fuera de horario
    WHEN dias_visita_total >= 3
      AND (pct_llega_antes > 0.5 OR pct_sale_despues > 0.5)
      THEN 0.5  -- 50% penalización

    -- CASO 5: Algo de consistencia horaria
    WHEN stddev_hora_minima < 3
      AND stddev_hora_maxima < 3
      AND dias_visita_total >= 2
      THEN 0.7  -- 30% penalización

    -- CASO 6: Horarios variables (visitante típico)
    WHEN stddev_hora_minima >= 3
      OR stddev_hora_maxima >= 3
      OR dias_visita_total = 1
      THEN 1.0  -- Sin penalización

    -- CASO DEFAULT
    ELSE 0.8  -- 20% penalización
  END
);


-- ============================================================================
-- PARTE 4: FUNCIÓN UDF - FACTOR DE FRECUENCIA (del usuario en la ubicación)
-- ============================================================================
-- Este factor penaliza usuarios que visitan MUCHOS días (posibles trabajadores)
-- Se calcula a nivel de usuario-ubicación, no por día

CREATE OR REPLACE FUNCTION `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_frecuencia`(
  dias_visita_total INT64  -- Total de días que el usuario visitó esa ubicación
)
RETURNS FLOAT64
AS (
  CASE
    WHEN dias_visita_total = 1 THEN 1.0           -- 1 día: visitante ocasional
    WHEN dias_visita_total BETWEEN 2 AND 3 THEN 0.9   -- 2-3 días: visitante regular
    WHEN dias_visita_total BETWEEN 4 AND 5 THEN 0.6   -- 4-5 días: frecuente
    WHEN dias_visita_total BETWEEN 6 AND 9 THEN 0.3   -- 6-9 días: muy frecuente
    ELSE 0.1                                      -- 10+ días: probable trabajador
  END
);


-- ============================================================================
-- PARTE 5: FUNCIÓN UDF - PROBABILIDAD FINAL DE VISITA (por día + patrón usuario)
-- ============================================================================

CREATE OR REPLACE FUNCTION `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_visita_dia`(
  -- Espacial
  prob_espacial FLOAT64,

  -- Temporal del día
  tiempo_ok_segundos INT64,
  tiempo_no_ok_segundos INT64,
  dif_horas FLOAT64,

  -- Flags del día
  llega_antes_abrir BOOL,
  sale_despues_cerrar BOOL,

  -- Patrón agregado del usuario
  stddev_hora_minima FLOAT64,
  stddev_hora_maxima FLOAT64,
  dif_horas_promedio FLOAT64,
  dias_visita_total INT64,
  pct_llega_antes FLOAT64,
  pct_sale_despues FLOAT64,

  -- Configuración
  tipo_poc STRING
)
RETURNS FLOAT64
AS (
  -- PROBABILIDAD FINAL = producto de 5 componentes
  prob_espacial *

  -- 1. Probabilidad temporal (tiempo + ratio del día)
  `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_temporal_dia`(
    tiempo_ok_segundos,
    SAFE_DIVIDE(tiempo_ok_segundos, tiempo_ok_segundos + tiempo_no_ok_segundos),
    tipo_poc
  ) *

  -- 2. Factor de patrón del día específico
  `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_patron_dia`(
    dif_horas,
    llega_antes_abrir,
    sale_despues_cerrar
  ) *

  -- 3. Factor de frecuencia del usuario
  `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_frecuencia`(
    dias_visita_total
  ) *

  -- 4. Factor de patrón agregado del usuario
  `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_patron_usuario`(
    IFNULL(stddev_hora_minima, 999),  -- NULL si solo 1 día
    IFNULL(stddev_hora_maxima, 999),
    dif_horas_promedio,
    dias_visita_total,
    pct_llega_antes,
    pct_sale_despues
  )
);


-- ============================================================================
-- PARTE 6: APLICACIÓN DEL MODELO A DATOS VOLVO (POR DÍA + PATRÓN USUARIO)
-- ============================================================================

-- Paso 1: Calcular estadísticas agregadas por usuario-ubicación
CREATE OR REPLACE TEMP TABLE PATRON_USUARIOS AS
SELECT
  msisdn,
  id_ubicacion,

  -- Frecuencia
  COUNT(DISTINCT fecha) as dias_visita_total,

  -- Variabilidad horaria (patrón agregado)
  STDDEV(hora_minima) as stddev_hora_minima,
  STDDEV(hora_maxima) as stddev_hora_maxima,

  -- Promedios
  AVG(dif_horas) as dif_horas_promedio,
  AVG(hora_minima) as hora_minima_promedio,
  AVG(hora_maxima) as hora_maxima_promedio,

  -- Porcentaje de días que llega/sale fuera de horario (VOLVO: 10-20h)
  100.0 * SUM(CASE WHEN hora_minima < 10 THEN 1 ELSE 0 END) / COUNT(*) as pct_llega_antes,
  100.0 * SUM(CASE WHEN hora_maxima > 20 THEN 1 ELSE 0 END) / COUNT(*) as pct_sale_despues

FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_UBICACION_GEO_TILES_CELIA_ISA_V2`
WHERE poc = 'VOLVO_XC40-AON_ABR2026_4'
  AND PERIODO = 'CAMPAIGN'
  AND tiempo_total_ok_dia > 0
GROUP BY msisdn, id_ubicacion;


-- Paso 2: Crear tabla con cada visita (día) evaluada
CREATE OR REPLACE TABLE `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_VOLVO_POR_DIA` AS
SELECT
  v.msisdn,
  v.id_ubicacion,
  v.fecha,
  v.DIA_SEMANA,
  v.poc,

  -- Variables del día
  v.tiempo_total_ok_dia,
  v.tiempo_total_no_ok_dia,
  v.dif_horas,
  v.hora_minima,
  v.hora_maxima,
  v.PROBABILIDAD_VISITA_OK as prob_espacial,

  -- Patrón agregado del usuario
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
  CASE WHEN v.hora_minima < 10 THEN TRUE ELSE FALSE END as llega_antes_abrir,
  CASE WHEN v.hora_maxima > 20 THEN TRUE ELSE FALSE END as sale_despues_cerrar,

  -- Tipo POC
  'CONCESIONARIO' as tipo_poc,

  -- PROBABILIDAD DE VISITA (del día + patrón usuario)
  `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_visita_dia`(
    v.PROBABILIDAD_VISITA_OK,
    v.tiempo_total_ok_dia,
    v.tiempo_total_no_ok_dia,
    v.dif_horas,
    CASE WHEN v.hora_minima < 10 THEN TRUE ELSE FALSE END,
    CASE WHEN v.hora_maxima > 20 THEN TRUE ELSE FALSE END,
    p.stddev_hora_minima,
    p.stddev_hora_maxima,
    p.dif_horas_promedio,
    p.dias_visita_total,
    p.pct_llega_antes,
    p.pct_sale_despues,
    'CONCESIONARIO'
  ) as prob_visita_dia,

  -- Componentes individuales (para análisis)
  `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_temporal_dia`(
    v.tiempo_total_ok_dia,
    SAFE_DIVIDE(v.tiempo_total_ok_dia, v.tiempo_total_ok_dia + v.tiempo_total_no_ok_dia),
    'CONCESIONARIO'
  ) as prob_temporal,

  `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_patron_dia`(
    v.dif_horas,
    CASE WHEN v.hora_minima < 10 THEN TRUE ELSE FALSE END,
    CASE WHEN v.hora_maxima > 20 THEN TRUE ELSE FALSE END
  ) as factor_patron_dia,

  `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_frecuencia`(
    p.dias_visita_total
  ) as factor_frecuencia,

  `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_patron_usuario`(
    IFNULL(p.stddev_hora_minima, 999),
    IFNULL(p.stddev_hora_maxima, 999),
    p.dif_horas_promedio,
    p.dias_visita_total,
    p.pct_llega_antes,
    p.pct_sale_despues
  ) as factor_patron_usuario

FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_UBICACION_GEO_TILES_CELIA_ISA_V2` v
INNER JOIN PATRON_USUARIOS p
  ON v.msisdn = p.msisdn
  AND v.id_ubicacion = p.id_ubicacion
WHERE v.poc = 'VOLVO_XC40-AON_ABR2026_4'
  AND v.PERIODO = 'CAMPAIGN'
  AND v.tiempo_total_ok_dia > 0;


-- Paso 3: Clasificar visitas según probabilidad
CREATE OR REPLACE TABLE `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_VOLVO_POR_DIA` AS
SELECT
  *,

  -- Clasificación por probabilidad final
  CASE
    WHEN prob_visita_dia >= 0.20 THEN 'VISITA_MUY_PROBABLE'
    WHEN prob_visita_dia >= 0.15 THEN 'VISITA_PROBABLE'
    WHEN prob_visita_dia >= 0.10 THEN 'VISITA_POSIBLE'
    WHEN prob_visita_dia >= 0.05 THEN 'DUDOSO'
    ELSE 'DESCARTADO'
  END as clasificacion_final,

  -- ¿Sería válido con filtro actual? (30-90 min + sin tiempo_no_ok)
  CASE
    WHEN tiempo_total_ok_dia BETWEEN 1800 AND 5400
      AND tiempo_total_no_ok_dia = 0
    THEN TRUE
    ELSE FALSE
  END as valido_filtro_actual,

  -- ¿Se recupera con el modelo?
  CASE
    WHEN tiempo_total_ok_dia BETWEEN 1800 AND 5400
      AND tiempo_total_no_ok_dia > 0
      AND prob_visita_dia >= 0.15
    THEN TRUE
    ELSE FALSE
  END as recuperado_con_modelo

FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_VOLVO_POR_DIA`;


-- ============================================================================
-- PARTE 7: QUERIES DE VALIDACIÓN (POR DÍA)
-- ============================================================================

-- Query A: Resumen de clasificaciones (por visita/día)
SELECT
  clasificacion_final,
  COUNT(*) as n_visitas,
  COUNT(DISTINCT msisdn) as n_usuarios_unicos,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) as pct_visitas,

  -- Promedios de probabilidad y componentes
  ROUND(AVG(prob_visita_dia), 4) as prob_visita_promedio,
  ROUND(AVG(prob_espacial), 4) as prob_espacial_promedio,
  ROUND(AVG(prob_temporal), 4) as prob_temporal_promedio,
  ROUND(AVG(factor_patron_dia), 4) as factor_patron_dia_promedio,
  ROUND(AVG(factor_frecuencia), 4) as factor_frecuencia_promedio,
  ROUND(AVG(factor_patron_usuario), 4) as factor_patron_usuario_promedio,

  -- Promedios de variables del día
  ROUND(AVG(ratio_horario), 3) as ratio_horario_promedio,
  ROUND(AVG(tiempo_total_ok_dia / 60), 1) as tiempo_ok_min_promedio,
  ROUND(AVG(dif_horas), 1) as dif_horas_promedio,

  -- Promedios de patrón agregado del usuario
  ROUND(AVG(dias_visita_total), 1) as dias_totales_promedio,
  ROUND(AVG(stddev_hora_minima), 2) as stddev_hora_min_promedio,
  ROUND(AVG(stddev_hora_maxima), 2) as stddev_hora_max_promedio,
  ROUND(AVG(pct_llega_antes), 1) as pct_llega_antes_promedio,
  ROUND(AVG(pct_sale_despues), 1) as pct_sale_despues_promedio

FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_VOLVO_POR_DIA`
GROUP BY clasificacion_final
ORDER BY
  CASE clasificacion_final
    WHEN 'VISITA_MUY_PROBABLE' THEN 1
    WHEN 'VISITA_PROBABLE' THEN 2
    WHEN 'VISITA_POSIBLE' THEN 3
    WHEN 'DUDOSO' THEN 4
    WHEN 'DESCARTADO' THEN 5
  END;


-- Query B: Comparación filtro actual vs modelo (por visitas)
SELECT
  'Visitas válidas con filtro actual (30-90 min + sin NO_OK)' as metodo,
  COUNT(*) as n_visitas,
  COUNT(DISTINCT msisdn) as n_usuarios_unicos
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_VOLVO_POR_DIA`
WHERE valido_filtro_actual = TRUE

UNION ALL

SELECT
  'Visitas válidas con modelo (prob >= 0.15)' as metodo,
  COUNT(*) as n_visitas,
  COUNT(DISTINCT msisdn) as n_usuarios_unicos
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_VOLVO_POR_DIA`
WHERE prob_visita_dia >= 0.15

UNION ALL

SELECT
  'Visitas recuperadas con modelo' as metodo,
  COUNT(*) as n_visitas,
  COUNT(DISTINCT msisdn) as n_usuarios_unicos
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_VOLVO_POR_DIA`
WHERE recuperado_con_modelo = TRUE;


-- Query C: Top 100 visitas MUY_PROBABLE para validación
SELECT
  msisdn,
  fecha,
  ROUND(tiempo_total_ok_dia / 60, 1) as tiempo_ok_min,
  ROUND(tiempo_total_no_ok_dia / 60, 1) as tiempo_no_ok_min,
  ROUND(ratio_horario, 3) as ratio_horario,
  ROUND(hora_minima, 1) as hora_min,
  ROUND(hora_maxima, 1) as hora_max,
  ROUND(dif_horas, 1) as dif_horas,
  dias_visita_total,
  ROUND(stddev_hora_minima, 2) as stddev_hora_min,
  ROUND(stddev_hora_maxima, 2) as stddev_hora_max,
  ROUND(prob_espacial, 4) as prob_espacial,
  ROUND(prob_temporal, 4) as prob_temporal,
  ROUND(factor_patron_dia, 4) as factor_patron_dia,
  ROUND(factor_frecuencia, 4) as factor_frecuencia,
  ROUND(factor_patron_usuario, 4) as factor_patron_usuario,
  ROUND(prob_visita_dia, 4) as prob_visita_final,
  valido_filtro_actual,
  recuperado_con_modelo
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_VOLVO_POR_DIA`
WHERE clasificacion_final = 'VISITA_MUY_PROBABLE'
ORDER BY prob_visita_dia DESC
LIMIT 100;


-- Query D: Análisis por día de semana
SELECT
  DIA_SEMANA,
  COUNT(*) as n_visitas,
  COUNT(DISTINCT msisdn) as n_usuarios,

  SUM(CASE WHEN clasificacion_final IN ('VISITA_MUY_PROBABLE', 'VISITA_PROBABLE') THEN 1 ELSE 0 END) as n_visitas_validas,
  ROUND(100.0 * SUM(CASE WHEN clasificacion_final IN ('VISITA_MUY_PROBABLE', 'VISITA_PROBABLE') THEN 1 ELSE 0 END) / COUNT(*), 2) as pct_validas,

  ROUND(AVG(prob_visita_dia), 4) as prob_promedio,
  ROUND(AVG(tiempo_total_ok_dia / 60), 1) as tiempo_ok_min_promedio

FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_VOLVO_POR_DIA`
GROUP BY DIA_SEMANA
ORDER BY
  CASE DIA_SEMANA
    WHEN 'MONDAY' THEN 1
    WHEN 'TUESDAY' THEN 2
    WHEN 'WEDNESDAY' THEN 3
    WHEN 'THURSDAY' THEN 4
    WHEN 'FRIDAY' THEN 5
    WHEN 'SATURDAY' THEN 6
    WHEN 'SUNDAY' THEN 7
  END;


-- ============================================================================
-- FIN DEL MODELO POR DÍA
-- ============================================================================
