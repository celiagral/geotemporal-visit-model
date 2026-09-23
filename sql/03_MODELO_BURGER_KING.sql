-- ============================================================================
-- MODELO PROBABILÍSTICO DE ESTIMACIÓN DE VISITAS
-- Versión: 3.3 - BURGER KING (FANTA GAMING)
-- ============================================================================
--
-- POC: FANTA_GAMING_JUN2026_CON_EXTERIOR
-- Tipo: RESTAURANTE (Burger King)
-- Horario típico: 11:00 - 23:00 (algunos 24h)
--
-- DIFERENCIAS vs CONCESIONARIO:
-- ✅ Más flexible con ratio_horario (gente come fuera de horario)
-- ✅ Horarios de apertura/cierre diferentes (11-23h en vez de 10-20h)
-- ✅ Visitas más cortas típicas (15-45 min vs 30-90 min)
-- ✅ Frecuencia media más común (la gente va más seguido a comer)
--
-- ============================================================================

-- ============================================================================
-- PARTE 1: TABLA DE CONFIGURACIÓN POR TIPO DE POC
-- ============================================================================

CREATE OR REPLACE TABLE `mo-advertising-sta.ADVERTISING_TEST.CONFIG_MODELO_VISITAS_BK` AS
SELECT * FROM UNNEST([
  -- BURGER KING / RESTAURANTES COMIDA RÁPIDA
  STRUCT(
    'RESTAURANTE' as tipo_poc,
    'Burger King - Restaurante comida rápida' as descripcion,
    0.7 as umbral_ratio_minimo,
    0.14 as umbral_prob_minimo,
    1.2 as umbral_stddev_trabajador,
    'Intermedio. Visitas cortas frecuentes. Algunos vecinos y trabajadores.' as notas
  )
]);


-- ============================================================================
-- PARTE 2: FUNCIÓN UDF - PROBABILIDAD TEMPORAL
-- ============================================================================

CREATE OR REPLACE FUNCTION `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_temporal_bk`(
  tiempo_ok_segundos INT64,
  dias_visita INT64,
  ratio_horario FLOAT64,
  tipo_poc STRING
)
RETURNS FLOAT64
AS (
  -- Factor base por duración (AJUSTADO PARA RESTAURANTE)
  (CASE
    -- Muy corto (< 10 min) - poco probable (salvo takeaway rápido)
    WHEN tiempo_ok_segundos < 600 THEN 0.3

    -- Corto (10-20 min) - válido (comida rápida)
    WHEN tiempo_ok_segundos < 1200 THEN 0.7

    -- Duración típica: 20-45 min - probabilidad alta
    WHEN tiempo_ok_segundos < 2700 THEN 1.0

    -- Duración media: 45-90 min - probabilidad alta (cena tranquila)
    WHEN tiempo_ok_segundos < 5400 THEN 0.9

    -- Largo: 90-120 min - empieza a ser sospechoso
    WHEN tiempo_ok_segundos < 7200 THEN 0.6

    -- Muy largo: 2-3h - probable trabajador
    WHEN tiempo_ok_segundos < 10800 THEN 0.3

    -- Más de 3h - muy probable trabajador
    ELSE 0.1
  END)

  *

  -- Factor por frecuencia (AJUSTADO PARA RESTAURANTE)
  (CASE
    -- 1 día - visitante ocasional, alta probabilidad
    WHEN dias_visita = 1 THEN 1.0

    -- 2-4 días - visitante regular (gente come fuera varias veces/semana)
    WHEN dias_visita BETWEEN 2 AND 4 THEN 0.85

    -- 5-7 días - visitante muy frecuente o trabajador cercano
    WHEN dias_visita BETWEEN 5 AND 7 THEN 0.5

    -- 8-12 días - probable trabajador o vecino muy frecuente
    WHEN dias_visita BETWEEN 8 AND 12 THEN 0.25

    -- 13+ días - muy probable trabajador
    ELSE 0.1
  END)

  *

  -- Factor por ratio de horario (FLEXIBLE PARA RESTAURANTE)
  (CASE tipo_poc
    WHEN 'RESTAURANTE' THEN
      CASE
        WHEN ratio_horario >= 0.9 THEN 1.0
        WHEN ratio_horario >= 0.8 THEN 0.95
        WHEN ratio_horario >= 0.7 THEN 0.8
        WHEN ratio_horario >= 0.6 THEN 0.5   -- Más flexible
        WHEN ratio_horario >= 0.5 THEN 0.3   -- Aún aceptable
        ELSE 0.2
      END

    -- DEFAULT: Usar configuración de RESTAURANTE
    ELSE
      CASE
        WHEN ratio_horario >= 0.9 THEN 1.0
        WHEN ratio_horario >= 0.8 THEN 0.95
        WHEN ratio_horario >= 0.7 THEN 0.8
        WHEN ratio_horario >= 0.6 THEN 0.5
        ELSE 0.2
      END
  END)
);


-- ============================================================================
-- PARTE 3: FUNCIÓN UDF - FACTOR DE PATRÓN HORARIO
-- ============================================================================

CREATE OR REPLACE FUNCTION `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_patron_horario_bk`(
  stddev_hora_minima FLOAT64,
  stddev_hora_maxima FLOAT64,
  dif_horas_promedio FLOAT64,
  dias_visita INT64,
  llega_antes_abrir BOOL,
  sale_despues_cerrar BOOL,
  pct_llega_antes FLOAT64,
  pct_sale_despues FLOAT64
)
RETURNS FLOAT64
AS (
  CASE
    -- CASO 1: Patrón laboral MUY claro
    -- Horarios super consistentes + jornadas largas + alta frecuencia
    WHEN dias_visita >= 8
      AND stddev_hora_minima < 1.0
      AND stddev_hora_maxima < 1.0
      AND dif_horas_promedio >= 6
      THEN 0.05  -- 95% de penalización

    -- CASO 2: Patrón laboral claro
    -- Horarios muy consistentes + jornadas largas + frecuencia alta
    WHEN dias_visita >= 6
      AND stddev_hora_minima < 1.5
      AND stddev_hora_maxima < 1.5
      AND dif_horas_promedio >= 6
      THEN 0.1  -- 90% de penalización

    -- CASO 3: Probable trabajador
    -- Horarios consistentes + frecuencia alta o jornadas largas
    WHEN (dias_visita >= 6 AND stddev_hora_minima < 2 AND stddev_hora_maxima < 2)
      OR (dias_visita >= 5 AND dif_horas_promedio >= 7)
      THEN 0.3  -- 70% de penalización

    -- CASO 4: Llega antes/sale después FRECUENTEMENTE
    -- Más del 60% de los días fuera de horario (más permisivo que concesionario)
    WHEN dias_visita >= 4
      AND (pct_llega_antes > 60 OR pct_sale_despues > 60)
      THEN 0.4  -- 60% de penalización

    -- CASO 5: Llega antes o sale después alguna vez (más permisivo)
    WHEN dias_visita >= 4
      AND (llega_antes_abrir OR sale_despues_cerrar)
      THEN 0.6  -- 40% de penalización

    -- CASO 6: Algo de consistencia (más permisivo con restaurantes)
    WHEN stddev_hora_minima < 3
      AND stddev_hora_maxima < 3
      AND dias_visita >= 3
      THEN 0.75  -- 25% de penalización

    -- CASO 7: Horarios variables (SIN penalización)
    WHEN stddev_hora_minima >= 3
      OR stddev_hora_maxima >= 3
      OR dias_visita <= 2
      THEN 1.0  -- Sin penalización

    -- CASO DEFAULT: Intermedio
    ELSE 0.85  -- 15% de penalización
  END
);


-- ============================================================================
-- PARTE 4: FUNCIÓN UDF - PROBABILIDAD FINAL DE VISITA
-- ============================================================================

CREATE OR REPLACE FUNCTION `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_visita_bk`(
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
  pct_llega_antes FLOAT64,
  pct_sale_despues FLOAT64,

  -- Configuración
  tipo_poc STRING
)
RETURNS FLOAT64
AS (
  -- PROBABILIDAD FINAL = producto de componentes
  prob_espacial *

  -- Componente: Probabilidad temporal (adaptado para restaurante)
  `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_temporal_bk`(
    tiempo_ok_segundos,
    dias_visita,
    SAFE_DIVIDE(tiempo_ok_segundos, tiempo_ok_segundos + tiempo_no_ok_segundos),
    tipo_poc
  ) *

  -- Componente: Factor de patrón horario (adaptado para restaurante)
  `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_patron_horario_bk`(
    IFNULL(stddev_hora_minima, 999),
    IFNULL(stddev_hora_maxima, 999),
    dif_horas_promedio,
    dias_visita,
    llega_antes_abrir,
    sale_despues_cerrar,
    IFNULL(pct_llega_antes, 0),
    IFNULL(pct_sale_despues, 0)
  )
);


-- ============================================================================
-- PARTE 5: APLICACIÓN DEL MODELO A DATOS BURGER KING
-- ============================================================================

-- Paso 1: Crear tabla con variables agregadas por usuario-ubicación
CREATE OR REPLACE TEMP TABLE USUARIOS_AGREGADOS_BK AS
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

  -- Flags: horario Burger King típico 11:00-23:00
  MAX(CASE WHEN hora_minima < 11 THEN TRUE ELSE FALSE END) as llega_antes_abrir_alguna_vez,
  MAX(CASE WHEN hora_maxima > 23 THEN TRUE ELSE FALSE END) as sale_despues_cerrar_alguna_vez,
  100.0 * SUM(CASE WHEN hora_minima < 11 THEN 1 ELSE 0 END) / COUNT(*) as pct_llega_antes,
  100.0 * SUM(CASE WHEN hora_maxima > 23 THEN 1 ELSE 0 END) / COUNT(*) as pct_sale_despues,

  -- Tipo POC
  'RESTAURANTE' as tipo_poc

FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_UBICACION_GEO_TILES_CELIA_ISA_V2`
WHERE poc = 'FANTA_GAMING_JUN2026_CON_EXTERIOR'
  AND PERIODO = 'CAMPAIGN'
  AND tiempo_total_ok_dia > 0
GROUP BY msisdn, id_ubicacion, poc;


-- Paso 2: Aplicar modelo y calcular probabilidad de visita
CREATE OR REPLACE TABLE `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_BK` AS
SELECT
  *,

  -- Calcular ratio
  SAFE_DIVIDE(tiempo_ok_promedio, tiempo_ok_promedio + tiempo_no_ok_promedio) as ratio_horario,

  -- Calcular probabilidad de visita
  `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_visita_bk`(
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
    tipo_poc
  ) as prob_visita_final,

  -- Componentes del modelo (para análisis)
  `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_temporal_bk`(
    CAST(tiempo_ok_promedio AS INT64),
    dias_visita,
    SAFE_DIVIDE(tiempo_ok_promedio, tiempo_ok_promedio + tiempo_no_ok_promedio),
    tipo_poc
  ) as prob_temporal,

  `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_patron_horario_bk`(
    IFNULL(stddev_hora_minima, 999),
    IFNULL(stddev_hora_maxima, 999),
    dif_horas_promedio,
    dias_visita,
    llega_antes_abrir_alguna_vez,
    sale_despues_cerrar_alguna_vez,
    pct_llega_antes,
    pct_sale_despues
  ) as factor_patron

FROM USUARIOS_AGREGADOS_BK;


-- Paso 3: Clasificar usuarios según probabilidad
CREATE OR REPLACE TABLE `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_BK` AS
SELECT
  *,

  -- Clasificación por probabilidad final (AJUSTADA PARA RESTAURANTE)
  CASE
    WHEN prob_visita_final >= 0.18 THEN 'VISITA_MUY_PROBABLE'
    WHEN prob_visita_final >= 0.12 THEN 'VISITA_PROBABLE'
    WHEN prob_visita_final >= 0.08 THEN 'VISITA_POSIBLE'
    WHEN prob_visita_final >= 0.04 THEN 'DUDOSO'
    ELSE 'DESCARTADO'
  END as clasificacion_final,

  -- ¿Sería válido con filtro actual? (10-60 min típico para restaurante + sin tiempo_no_ok)
  CASE
    WHEN tiempo_ok_promedio BETWEEN 600 AND 3600
      AND tiempo_no_ok_promedio = 0
    THEN TRUE
    ELSE FALSE
  END as valido_filtro_actual,

  -- ¿Se recupera con el modelo?
  CASE
    WHEN tiempo_ok_promedio BETWEEN 600 AND 3600
      AND tiempo_no_ok_promedio > 0
      AND prob_visita_final >= 0.12
    THEN TRUE
    ELSE FALSE
  END as recuperado_con_modelo

FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CON_PROBABILIDAD_BK`;


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
  ROUND(AVG(dias_visita), 1) as dias_promedio,
  ROUND(AVG(stddev_hora_minima), 2) as stddev_hora_min_promedio

FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_BK`
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
  'Válidos con filtro actual (10-60 min + sin NO_OK)' as metodo,
  SUM(CASE WHEN valido_filtro_actual THEN 1 ELSE 0 END) as n_usuarios
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_BK`

UNION ALL

SELECT
  'Válidos con modelo (prob >= 0.12)' as metodo,
  SUM(CASE WHEN prob_visita_final >= 0.12 THEN 1 ELSE 0 END) as n_usuarios
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_BK`

UNION ALL

SELECT
  'Recuperados con modelo' as metodo,
  SUM(CASE WHEN recuperado_con_modelo THEN 1 ELSE 0 END) as n_usuarios
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_BK`

UNION ALL

SELECT
  'Incremento (%)' as metodo,
  CAST(ROUND(100.0 * SUM(CASE WHEN recuperado_con_modelo THEN 1 ELSE 0 END) /
    NULLIF(SUM(CASE WHEN valido_filtro_actual THEN 1 ELSE 0 END), 0), 1) AS INT64) as n_usuarios
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_BK`;


-- Query C: Top 100 usuarios MUY_PROBABLE para validación manual
SELECT
  msisdn,
  dias_visita,
  ROUND(tiempo_ok_promedio / 60, 1) as tiempo_ok_min_promedio,
  ROUND(tiempo_no_ok_promedio / 60, 1) as tiempo_no_ok_min_promedio,
  ROUND(ratio_horario, 3) as ratio_horario,
  ROUND(hora_minima_promedio, 1) as hora_min_promedio,
  ROUND(hora_maxima_promedio, 1) as hora_max_promedio,
  ROUND(dif_horas_promedio, 1) as dif_horas_promedio,
  ROUND(stddev_hora_minima, 2) as stddev_hora_min,
  ROUND(stddev_hora_maxima, 2) as stddev_hora_max,
  ROUND(pct_llega_antes, 1) as pct_llega_antes,
  ROUND(pct_sale_despues, 1) as pct_sale_despues,
  ROUND(prob_espacial_promedio, 4) as prob_espacial,
  ROUND(prob_temporal, 4) as prob_temporal,
  ROUND(factor_patron, 4) as factor_patron,
  ROUND(prob_visita_final, 4) as prob_visita_final,
  valido_filtro_actual,
  recuperado_con_modelo
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_BK`
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
  ROUND(dif_horas_promedio, 1) as dif_horas_promedio,
  ROUND(stddev_hora_minima, 2) as stddev_hora_min,
  ROUND(pct_llega_antes, 1) as pct_llega_antes,
  ROUND(pct_sale_despues, 1) as pct_sale_despues,
  ROUND(factor_patron, 4) as factor_patron,
  ROUND(prob_visita_final, 4) as prob_visita_final,
  clasificacion_final
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_BK`
WHERE recuperado_con_modelo = TRUE
ORDER BY prob_visita_final DESC
LIMIT 100;


-- Query E: Análisis por frecuencia de visita
SELECT
  CASE
    WHEN dias_visita = 1 THEN '1 día (ocasional)'
    WHEN dias_visita BETWEEN 2 AND 4 THEN '2-4 días (regular)'
    WHEN dias_visita BETWEEN 5 AND 7 THEN '5-7 días (frecuente)'
    WHEN dias_visita BETWEEN 8 AND 12 THEN '8-12 días (muy frecuente)'
    ELSE '13+ días (posible trabajador)'
  END as bucket_frecuencia,

  COUNT(*) as n_usuarios,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) as pct_usuarios,

  -- % de usuarios válidos en este bucket
  ROUND(100.0 * SUM(CASE WHEN clasificacion_final IN ('VISITA_MUY_PROBABLE', 'VISITA_PROBABLE') THEN 1 ELSE 0 END) / COUNT(*), 1) as pct_validos,

  ROUND(AVG(prob_visita_final), 4) as prob_promedio,
  ROUND(AVG(tiempo_ok_promedio / 60), 1) as tiempo_ok_min_promedio,
  ROUND(AVG(stddev_hora_minima), 2) as stddev_hora_min_promedio

FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_BK`
GROUP BY bucket_frecuencia
ORDER BY
  CASE
    WHEN dias_visita = 1 THEN 1
    WHEN dias_visita BETWEEN 2 AND 4 THEN 2
    WHEN dias_visita BETWEEN 5 AND 7 THEN 3
    WHEN dias_visita BETWEEN 8 AND 12 THEN 4
    ELSE 5
  END;


-- ============================================================================
-- FIN DEL MODELO BURGER KING
-- ============================================================================

-- ============================================================================
-- NOTAS DE IMPLEMENTACIÓN
-- ============================================================================
/*

DIFERENCIAS CLAVE vs MODELO VOLVO:

1. HORARIOS:
   - Volvo: 10:00-20:00
   - Burger King: 11:00-23:00
   - Algunos BK son 24h → ajustar si es necesario

2. TIEMPOS DE VISITA:
   - Volvo: 30-90 min típico
   - Burger King: 10-45 min típico

3. FRECUENCIA:
   - Volvo: 1-3 días más común (comprar coche es ocasional)
   - Burger King: 2-7 días más común (gente come fuera varias veces/semana)

4. RATIO:
   - Volvo: MUY estricto (0.8+ para ser válido)
   - Burger King: Más flexible (0.6-0.7 aceptable)

5. UMBRALES DE CLASIFICACIÓN:
   - Volvo: 0.20 / 0.15 / 0.10 / 0.05
   - Burger King: 0.18 / 0.12 / 0.08 / 0.04 (ligeramente más bajos)

VALIDACIÓN RECOMENDADA:
1. Ejecutar este modelo
2. Revisar Query A - distribución de clasificaciones
3. Ejecutar 07_ANALISIS_UMBRALES.sql adaptado para BK
4. Ajustar umbrales según resultados

*/
