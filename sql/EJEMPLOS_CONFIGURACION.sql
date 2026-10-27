-- ============================================================================
-- EJEMPLOS DE CONFIGURACIÓN - MODELO V2
-- ============================================================================
-- Casos de uso comunes y cómo configurarlos

-- ============================================================================
-- EJEMPLO 1: POC de Alta Frecuencia (Cafetería, Panadería)
-- ============================================================================
-- Características:
-- - Visitas muy frecuentes (casi diarias)
-- - Visitas cortas (5-20 min)
-- - ALTO riesgo de trabajadores (dependientes)
-- - Horarios amplios (7am-9pm)

INSERT INTO `mo-advertising-sta.ADVERTISING_TEST.CONFIG_POC_V2`
VALUES (
  'CAFETERIA',                      -- tipo_poc
  'COMPRA_RUTINARIA',               -- perfil_base (hereda de rutinaria)
  'v2.0',                           -- config_version
  CURRENT_TIMESTAMP(),              -- fecha_actualizacion

  7.0,                              -- hora_apertura
  21.0,                             -- hora_cierre

  0.5,                              -- ajuste_tiempo (50% más corto que base)
  2.0,                              -- ajuste_frecuencia (doble de frecuente)

  STRUCT(
    0.8 AS stddev_max,              -- Patrón muy fijo = trabajador
    3.0 AS stddev_visitante_min,
    6.0 AS dif_horas_min,
    70.0 AS pct_fuera_horario_max   -- Más permisivo (horarios amplios)
  ),

  STRUCT(
    0.40 AS minimo,                 -- Muy permisivo (vecinos van mucho)
    0.70 AS optimo
  ),

  STRUCT(
    0.15 AS muy_probable,           -- Umbrales más bajos
    0.10 AS probable,
    0.06 AS posible,
    0.03 AS dudoso
  ),

  STRUCT(
    0.20 AS espacial,               -- Poco peso espacial (vecinos)
    0.30 AS temporal,
    0.50 AS patron                  -- MUCHO peso en patrón (detectar trabajadores)
  ),

  'Cafeterías: visitas muy frecuentes y cortas, crítico detectar trabajadores'
);

-- Parámetros derivados esperados:
-- tiempo_base = 1800s (de COMPRA_RUTINARIA)
-- tiempo_base * ajuste_tiempo = 1800 * 0.5 = 900s (15 min)
-- tiempo_min = 900 * 0.3 = 270s (4.5 min)
-- tiempo_optimo_min = 900 * 0.6 = 540s (9 min)
-- tiempo_optimo_max = 900 * 2.0 = 1800s (30 min)
-- tiempo_max = 900 * 4.0 = 3600s (1 hora)


-- ============================================================================
-- EJEMPLO 2: POC de Baja Frecuencia (Joyería, Óptica)
-- ============================================================================
-- Características:
-- - Visitas muy infrecuentes (1-2 veces al año típico)
-- - Visitas largas (30-60 min)
-- - BAJO riesgo trabajadores
-- - Horarios comerciales normales

INSERT INTO `mo-advertising-sta.ADVERTISING_TEST.CONFIG_POC_V2`
VALUES (
  'JOYERIA',
  'COMPRA_PLANIFICADA',             -- Compra planificada
  'v2.0',
  CURRENT_TIMESTAMP(),

  10.0,                             -- hora_apertura
  20.0,                             -- hora_cierre

  1.0,                              -- ajuste_tiempo (usa base: 1 hora)
  0.3,                              -- ajuste_frecuencia (30% de base = muy infrecuente)

  STRUCT(
    2.0 AS stddev_max,              -- Más permisivo (horarios variables OK)
    4.0 AS stddev_visitante_min,
    7.0 AS dif_horas_min,
    40.0 AS pct_fuera_horario_max
  ),

  STRUCT(
    0.85 AS minimo,                 -- Muy estricto
    0.95 AS optimo
  ),

  STRUCT(
    0.25 AS muy_probable,           -- Umbrales altos
    0.18 AS probable,
    0.12 AS posible,
    0.06 AS dudoso
  ),

  STRUCT(
    0.35 AS espacial,
    0.50 AS temporal,               -- Peso alto en temporal (visita larga)
    0.15 AS patron                  -- Poco peso patrón (no hay trabajadores)
  ),

  'Joyerías: visitas muy infrecuentes, largas, bajo riesgo trabajadores'
);

-- Parámetros derivados:
-- frecuencia_base = 3 días (de COMPRA_PLANIFICADA)
-- frecuencia_base * ajuste = 3 * 0.3 = 0.9 ≈ 1 día óptimo
-- dias_max = 1 * 3.0 = 3 días


-- ============================================================================
-- EJEMPLO 3: POC con Horario Partido (Peluquería)
-- ============================================================================
-- Características:
-- - Horario partido: 10-14h y 17-21h
-- - Visitas medianas (30-90 min)
-- - Frecuencia media-baja (1 vez al mes)
-- - Riesgo medio de trabajadores

-- NOTA: El modelo actual no soporta horarios partidos nativamente
-- Solución: usar hora_apertura/cierre amplio + ajustar pct_fuera_horario_max

INSERT INTO `mo-advertising-sta.ADVERTISING_TEST.CONFIG_POC_V2`
VALUES (
  'PELUQUERIA',
  'OCIO',
  'v2.0',
  CURRENT_TIMESTAMP(),

  10.0,                             -- hora_apertura (primera apertura)
  21.0,                             -- hora_cierre (último cierre)

  1.2,                              -- ajuste_tiempo
  0.8,                              -- ajuste_frecuencia

  STRUCT(
    1.3 AS stddev_max,
    3.5 AS stddev_visitante_min,
    6.0 AS dif_horas_min,
    80.0 AS pct_fuera_horario_max   -- ⚠️ MUY permisivo (horario partido)
  ),

  STRUCT(
    0.60 AS minimo,
    0.85 AS optimo
  ),

  STRUCT(
    0.18 AS muy_probable,
    0.13 AS probable,
    0.08 AS posible,
    0.04 AS dudoso
  ),

  STRUCT(
    0.30 AS espacial,
    0.40 AS temporal,
    0.30 AS patron
  ),

  'Peluquerías: horario partido, ajustar pct_fuera_horario_max alto'
);

-- ⚠️ MEJORA FUTURA: Añadir soporte nativo de horarios partidos
-- Ejemplo:
-- horarios ARRAY<STRUCT<apertura FLOAT64, cierre FLOAT64>>
-- = [STRUCT(10.0, 14.0), STRUCT(17.0, 21.0)]


-- ============================================================================
-- EJEMPLO 4: POC con Muchos Trabajadores (Gasolinera)
-- ============================================================================
-- Características:
-- - 24/7 (siempre abierto)
-- - Visitas muy cortas (5-15 min)
-- - MUCHÍSIMOS trabajadores (turnos, camioneros)
-- - Difícil distinguir visitantes

INSERT INTO `mo-advertising-sta.ADVERTISING_TEST.CONFIG_POC_V2`
VALUES (
  'GASOLINERA',
  'COMPRA_RUTINARIA',
  'v2.0',
  CURRENT_TIMESTAMP(),

  0.0,                              -- hora_apertura (24h)
  24.0,                             -- hora_cierre (24h)

  0.4,                              -- ajuste_tiempo (muy corto: 12 min base)
  1.5,                              -- ajuste_frecuencia (frecuente)

  STRUCT(
    0.5 AS stddev_max,              -- ⚠️ Patrón MUY fijo = trabajador
    2.5 AS stddev_visitante_min,
    8.0 AS dif_horas_min,           -- Jornadas muy largas (turnos)
    100.0 AS pct_fuera_horario_max  -- No aplica (24h)
  ),

  STRUCT(
    0.30 AS minimo,                 -- Muy permisivo
    0.60 AS optimo
  ),

  STRUCT(
    0.12 AS muy_probable,           -- Umbrales muy bajos
    0.08 AS probable,
    0.05 AS posible,
    0.02 AS dudoso
  ),

  STRUCT(
    0.15 AS espacial,               -- Poco peso espacial (vecinos + carreteras)
    0.25 AS temporal,
    0.60 AS patron                  -- ⚠️ CRÍTICO: detectar trabajadores
  ),

  'Gasolineras: 24/7, alto riesgo trabajadores, patrón es crítico'
);

-- NOTA: Gasolineras son el caso más difícil
-- Considera usar umbral de Pass 1 más alto (0.5 en vez de 0.4)


-- ============================================================================
-- EJEMPLO 5: POC Estacional (Tienda de Navidad)
-- ============================================================================
-- Características:
-- - Solo abierto 2 meses al año
-- - Visitas medianas
-- - Trabajadores temporales (difíciles de distinguir)

-- ⚠️ PROBLEMA: El modelo actual no considera estacionalidad
-- Un trabajador temporal (2 meses) tiene menos días que uno permanente
-- Pero el patrón (stddev bajo) sigue siendo de trabajador

-- SOLUCIÓN TEMPORAL: Ajustar dias_max más bajo

INSERT INTO `mo-advertising-sta.ADVERTISING_TEST.CONFIG_POC_V2`
VALUES (
  'TIENDA_NAVIDAD',
  'OCIO',
  'v2.0',
  CURRENT_TIMESTAMP(),

  10.0,
  22.0,

  1.2,
  0.5,                              -- Menos frecuente (solo 2 meses)

  STRUCT(
    1.0 AS stddev_max,              -- ⚠️ Patrón fijo en 2 meses = trabajador
    3.0 AS stddev_visitante_min,
    6.0 AS dif_horas_min,
    50.0 AS pct_fuera_horario_max
  ),

  STRUCT(
    0.60 AS minimo,
    0.80 AS optimo
  ),

  STRUCT(
    0.16 AS muy_probable,
    0.11 AS probable,
    0.07 AS posible,
    0.03 AS dudoso
  ),

  STRUCT(
    0.30 AS espacial,
    0.40 AS temporal,
    0.30 AS patron
  ),

  'Tiendas estacionales: ajustar frecuencia baja, considerar periodo corto'
);

-- Parámetros derivados:
-- frecuencia_base = 4 días (OCIO)
-- frecuencia_base * ajuste = 4 * 0.5 = 2 días óptimo
-- dias_max = 2 * 4.0 = 8 días (en 2 meses)

-- ⚠️ MEJORA FUTURA: Añadir ventana temporal
-- Ejemplo: dias_max_por_mes = 4 (8 días / 2 meses)
-- Normalizar por duración de campaña


-- ============================================================================
-- EJEMPLO 6: Clonar Configuración Existente
-- ============================================================================
-- Caso: Quieres un POC casi igual a otro pero con pequeños cambios

-- Opción A: Copiar y modificar
INSERT INTO `mo-advertising-sta.ADVERTISING_TEST.CONFIG_POC_V2`
SELECT
  'BURGER_KING' as tipo_poc,        -- Nuevo nombre
  perfil_base,
  'v2.1' as config_version,         -- Nueva versión
  CURRENT_TIMESTAMP() as fecha_actualizacion,

  hora_apertura,
  23.0 as hora_cierre,              -- Cambiado: cierra 1h más tarde

  ajuste_tiempo,
  ajuste_frecuencia,
  patron_trabajador,
  ratio,
  umbrales,
  pesos,

  'Burger King: clonado de RESTAURANTE con horario extendido' as notas

FROM `mo-advertising-sta.ADVERTISING_TEST.CONFIG_POC_V2`
WHERE tipo_poc = 'RESTAURANTE';


-- ============================================================================
-- EJEMPLO 7: Ajustar Pesos Basándote en Resultados
-- ============================================================================
-- Caso: Ejecutaste el modelo y ves que prob_espacial es siempre baja
-- Quieres reducir su impacto en la probabilidad final

-- Paso 1: Analizar distribución actual
SELECT
  tipo_poc,
  ROUND(AVG(comp_espacial), 3) as avg_espacial,
  ROUND(AVG(comp_temporal), 3) as avg_temporal,
  ROUND(AVG(comp_patron), 3) as avg_patron,
  ROUND(STDDEV(comp_espacial), 3) as std_espacial,
  ROUND(STDDEV(comp_temporal), 3) as std_temporal,
  ROUND(STDDEV(comp_patron), 3) as std_patron
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_FINALES_V2`
GROUP BY tipo_poc;

-- Ejemplo de output:
-- SUPERMERCADO | avg_espacial=0.12 | avg_temporal=0.65 | avg_patron=0.45
--              | std_espacial=0.08 | std_temporal=0.20 | std_patron=0.25

-- Interpretación:
-- - prob_espacial muy baja y poco variable → casi todos están lejos
-- - prob_temporal alta → el tiempo de visita es bueno
-- - prob_patron media → detecta algunos trabajadores

-- Paso 2: Ajustar pesos
-- Si prob_espacial es ruido (todos bajos), reduce su peso

UPDATE `mo-advertising-sta.ADVERTISING_TEST.CONFIG_POC_V2`
SET
  pesos = STRUCT(
    0.15 AS espacial,               -- Reducido de 0.25
    0.40 AS temporal,               -- Igual
    0.45 AS patron                  -- Incrementado de 0.40
  ),
  config_version = 'v2.1',
  fecha_actualizacion = CURRENT_TIMESTAMP()
WHERE tipo_poc = 'SUPERMERCADO';

-- Paso 3: Recalcular CONFIG_CALCULADA
-- (Re-ejecutar PARTE 3 del modelo)


-- ============================================================================
-- EJEMPLO 8: Debugging - Por qué un usuario fue clasificado así
-- ============================================================================

-- Query para investigar un usuario específico
WITH desglose AS (
  SELECT
    msisdn,
    fecha,

    -- Componentes
    ROUND(comp_espacial, 3) as comp_espacial,
    ROUND(comp_temporal, 3) as comp_temporal,
    ROUND(comp_patron, 3) as comp_patron,

    -- Pesos
    ROUND(peso_espacial, 2) as peso_espacial,
    ROUND(peso_temporal, 2) as peso_temporal,
    ROUND(peso_patron, 2) as peso_patron,

    -- Contribuciones (componente * peso)
    ROUND(comp_espacial * peso_espacial, 3) as contrib_espacial,
    ROUND(comp_temporal * peso_temporal, 3) as contrib_temporal,
    ROUND(comp_patron * peso_patron, 3) as contrib_patron,

    -- Final
    ROUND(prob_visita_final, 3) as prob_final,
    clasificacion_final,

    -- Variables originales
    ROUND(tiempo_total_ok_dia / 60, 1) as tiempo_min,
    dias_visita_total,
    ROUND(stddev_hora_minima, 2) as stddev_hora_min

  FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_FINALES_V2`
  WHERE msisdn = '34612345678'  -- 🔧 Cambiar por MSISDN real
)
SELECT
  fecha,
  tiempo_min,
  dias_visita_total,
  stddev_hora_min,

  -- Componentes
  comp_espacial,
  comp_temporal,
  comp_patron,

  -- Contribuciones
  contrib_espacial,
  contrib_temporal,
  contrib_patron,

  -- Suma = prob_final
  ROUND(contrib_espacial + contrib_temporal + contrib_patron, 3) as suma_contribs,
  prob_final,

  clasificacion_final
FROM desglose
ORDER BY fecha;

-- Interpretación del output:
-- Si contrib_patron es negativa (baja) → detectado como trabajador
-- Si contrib_espacial es negativa → está lejos del POC
-- Si contrib_temporal es negativa → tiempo/ratio malo


-- ============================================================================
-- EJEMPLO 9: Calibrar Umbrales con Ground Truth
-- ============================================================================
-- Caso: Tienes 100 usuarios etiquetados manualmente

-- Paso 1: Crear tabla de ground truth
CREATE OR REPLACE TABLE `mo-advertising-sta.ADVERTISING_TEST.GROUND_TRUTH` AS
SELECT * FROM UNNEST([
  STRUCT('34612345678' as msisdn, TRUE as es_visita_real),
  STRUCT('34698765432' as msisdn, FALSE as es_visita_real),
  -- ... más labels
]);

-- Paso 2: Calcular métricas por umbral
WITH diferentes_umbrales AS (
  SELECT
    v.msisdn,
    v.prob_visita_final,
    gt.es_visita_real,

    -- Probar diferentes umbrales
    CASE WHEN v.prob_visita_final >= 0.05 THEN TRUE ELSE FALSE END as pred_0_05,
    CASE WHEN v.prob_visita_final >= 0.10 THEN TRUE ELSE FALSE END as pred_0_10,
    CASE WHEN v.prob_visita_final >= 0.15 THEN TRUE ELSE FALSE END as pred_0_15,
    CASE WHEN v.prob_visita_final >= 0.20 THEN TRUE ELSE FALSE END as pred_0_20

  FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_FINALES_V2` v
  INNER JOIN `mo-advertising-sta.ADVERTISING_TEST.GROUND_TRUTH` gt
    ON v.msisdn = gt.msisdn
)
SELECT
  'Umbral 0.05' as umbral,
  SUM(CASE WHEN pred_0_05 = es_visita_real THEN 1 ELSE 0 END) / COUNT(*) as accuracy,
  SUM(CASE WHEN pred_0_05 AND es_visita_real THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN es_visita_real THEN 1 ELSE 0 END), 0) as recall,
  SUM(CASE WHEN pred_0_05 AND es_visita_real THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN pred_0_05 THEN 1 ELSE 0 END), 0) as precision
FROM diferentes_umbrales

UNION ALL

SELECT
  'Umbral 0.10' as umbral,
  SUM(CASE WHEN pred_0_10 = es_visita_real THEN 1 ELSE 0 END) / COUNT(*),
  SUM(CASE WHEN pred_0_10 AND es_visita_real THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN es_visita_real THEN 1 ELSE 0 END), 0),
  SUM(CASE WHEN pred_0_10 AND es_visita_real THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN pred_0_10 THEN 1 ELSE 0 END), 0)
FROM diferentes_umbrales

-- (Repetir para 0.15, 0.20...)

ORDER BY umbral;

-- Paso 3: Elegir umbral óptimo
-- Balance precision/recall según tu caso de uso
-- - Alta precision → pocos falsos positivos (conservador)
-- - Alto recall → pocos falsos negativos (agresivo)


-- ============================================================================
-- EJEMPLO 10: Exportar Configuración para Documentación
-- ============================================================================

-- Query para generar tabla legible de configuración

SELECT
  tipo_poc,
  perfil_base,
  config_version,
  FORMAT_TIMESTAMP('%Y-%m-%d', fecha_actualizacion) as fecha_config,

  -- Horarios
  CONCAT(CAST(hora_apertura AS STRING), 'h - ', CAST(hora_cierre AS STRING), 'h') as horario,

  -- Tiempos (en minutos)
  CONCAT(
    CAST(ROUND(tiempo_min_valido / 60) AS STRING), '-',
    CAST(ROUND(tiempo_max_valido / 60) AS STRING), ' min (óptimo: ',
    CAST(ROUND(tiempo_optimo_min / 60) AS STRING), '-',
    CAST(ROUND(tiempo_optimo_max / 60) AS STRING), ' min)'
  ) as rango_tiempo,

  -- Frecuencia (en días)
  CONCAT(
    CAST(dias_min_valido AS STRING), '-',
    CAST(dias_max_valido AS STRING), ' días (óptimo: ',
    CAST(dias_optimo_min AS STRING), '-',
    CAST(dias_optimo_max AS STRING), ' días)'
  ) as rango_frecuencia,

  -- Pesos
  CONCAT(
    'E:', CAST(ROUND(peso_espacial, 2) AS STRING),
    ' T:', CAST(ROUND(peso_temporal, 2) AS STRING),
    ' P:', CAST(ROUND(peso_patron, 2) AS STRING)
  ) as pesos,

  -- Umbrales
  CONCAT(
    'MP:', CAST(ROUND(umbral_muy_probable, 2) AS STRING),
    ' P:', CAST(ROUND(umbral_probable, 2) AS STRING),
    ' Ps:', CAST(ROUND(umbral_posible, 2) AS STRING)
  ) as umbrales,

  riesgo_trabajadores,
  strictness,
  notas

FROM `mo-advertising-sta.ADVERTISING_TEST.CONFIG_CALCULADA_V2`
ORDER BY perfil_base, tipo_poc;

-- Output: Tabla lista para copiar a Excel/Docs
