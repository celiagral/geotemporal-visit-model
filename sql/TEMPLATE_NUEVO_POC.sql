-- ============================================================================
-- TEMPLATE: AÑADIR NUEVO TIPO DE POC
-- ============================================================================
-- Usa este template para añadir un nuevo tipo de POC a la configuración
-- ============================================================================

-- PASO 1: Rellenar los parámetros abajo
-- PASO 2: Ejecutar este script para insertar en CONFIG_MODELO_PARAMETRIZADA
-- PASO 3: Usar 03_MODELO_GENERICO.sql con tu nuevo tipo_poc

-- ============================================================================
-- CONFIGURACIÓN - RELLENAR AQUÍ
-- ============================================================================

-- NOTA: Cambiar estos valores según tu caso específico
-- Para ejemplos y guía, ver docs/08_GUIA_MODELO_GENERICO.md

INSERT INTO `mo-advertising-sta.ADVERTISING_TEST.CONFIG_MODELO_PARAMETRIZADA`
VALUES (
  -- =========================================================================
  -- IDENTIFICACIÓN
  -- =========================================================================
  'NOMBRE_TU_POC',                       -- tipo_poc (ej: 'GASOLINERA', 'FARMACIA', 'GYM')
  'Descripción del tipo de POC',         -- descripcion

  -- =========================================================================
  -- HORARIOS (en formato 24h decimal)
  -- =========================================================================
  10.0,                                  -- hora_apertura (ej: 9.0 = 9:00, 9.5 = 9:30)
  20.0,                                  -- hora_cierre

  -- =========================================================================
  -- TIEMPOS DE VISITA (en segundos)
  -- =========================================================================
  -- Pregúntate: ¿Cuánto tiempo está un visitante típico?

  900,                                   -- tiempo_min_valido (< esto es muy corto, ej: 900s = 15 min)
  10800,                                 -- tiempo_max_valido (> esto es muy largo, ej: 10800s = 3h)
  1800,                                  -- tiempo_optimo_min (inicio rango típico, ej: 1800s = 30 min)
  5400,                                  -- tiempo_optimo_max (fin rango típico, ej: 5400s = 90 min)

  -- Ejemplos comunes:
  -- - Banco: 600, 3600, 900, 2400 (10 min - 1h, óptimo 15-40 min)
  -- - Restaurante: 600, 5400, 1200, 2700 (10 min - 90 min, óptimo 20-45 min)
  -- - Supermercado: 600, 7200, 1200, 3600 (10 min - 2h, óptimo 20-60 min)
  -- - Concesionario: 900, 10800, 1800, 5400 (15 min - 3h, óptimo 30-90 min)

  -- =========================================================================
  -- FRECUENCIA (días) - Rango completo con óptimo (igual que tiempo)
  -- =========================================================================
  -- min_valido < optimo_min <= optimo_max < max_valido
  -- Funciona igual que tiempo: rango óptimo (1.0) y rangos de transición

  0,                                     -- dias_min_valido (< esto = ruido, 0 días)
  12,                                    -- dias_max_valido (> esto = trabajador claro)
  1,                                     -- dias_optimo_min (inicio rango óptimo)
  5,                                     -- dias_optimo_max (fin rango óptimo)

  -- Ejemplos comunes:
  -- - Concesionario: 0, 12, 1, 5 (visitante ideal: 1-5 días)
  -- - Supermercado: 0, 18, 1, 8 (visitante frecuente: 1-8 días)
  -- - Restaurante: 0, 14, 1, 6 (visitante frecuente: 1-6 días)
  -- - Gym: 0, 22, 1, 12 (visitante MUY frecuente: 1-12 días)
  -- - Banco: 0, 9, 1, 4 (visitante ocasional: 1-4 días)

  -- =========================================================================
  -- RATIOS (0.0 - 1.0)
  -- =========================================================================
  -- ratio = tiempo_ok / (tiempo_ok + tiempo_no_ok)
  -- Pregúntate: ¿Qué tan estricto debo ser con tiempo fuera de horario?

  0.80,                                  -- ratio_minimo (mínimo aceptable)
  0.90,                                  -- ratio_optimo (ideal)

  -- Ejemplos comunes:
  -- - Estricto (concesionario, banco): 0.80, 0.90
  -- - Flexible (supermercado, vecinos frecuentes): 0.50, 0.80
  -- - Intermedio (restaurante, centro comercial): 0.70, 0.85

  -- =========================================================================
  -- PATRÓN HORARIO
  -- =========================================================================
  -- Para detectar trabajadores vs visitantes

  1.5,                                   -- stddev_trabajador_max (trabajador tiene stddev < esto)
  3.0,                                   -- stddev_visitante_min (visitante tiene stddev ≥ esto)
  6.0,                                   -- dif_horas_trabajador_min (trabajador promedia ≥ esto)
  50.0,                                  -- pct_fuera_horario_max (> esto % días fuera = trabajador)

  -- Valores típicos (rara vez necesitas cambiar):
  -- - stddev_trabajador_max: 1.0 - 1.5h (trabajadores llegan a la misma hora)
  -- - stddev_visitante_min: 3.0 - 4.0h (visitantes varían mucho)
  -- - dif_horas_trabajador_min: 5.0 - 7.0h (jornada laboral)
  -- - pct_fuera_horario_max: 50 - 60% (trabajadores llegan antes/salen después)

  -- =========================================================================
  -- UMBRALES DE CLASIFICACIÓN
  -- =========================================================================
  -- Ajustar después de ejecutar 07_ANALISIS_UMBRALES.sql

  0.20,                                  -- umbral_muy_probable (≥ esto = muy confiable)
  0.15,                                  -- umbral_probable (≥ esto = bastante confiable)
  0.10,                                  -- umbral_posible (≥ esto = posible)
  0.05,                                  -- umbral_dudoso (≥ esto = dudoso, < esto = descartado)

  -- Umbrales iniciales sugeridos (ajustar con datos reales):
  -- - Estricto: 0.20, 0.15, 0.10, 0.05
  -- - Flexible: 0.18, 0.12, 0.08, 0.04
  -- - Intermedio: 0.18, 0.13, 0.08, 0.04

  -- =========================================================================
  -- PESOS (para ajustar importancia de componentes)
  -- =========================================================================
  -- Ver docs/10_GUIA_PESOS.md para detalles completos
  -- peso < 1.0 = suaviza (reduce impacto negativo de valores bajos)
  -- peso = 1.0 = sin cambio (multiplicación normal)
  -- peso > 1.0 = acentúa (penaliza más valores bajos)

  0.5,                                   -- peso_espacial (recomendado: 0.5 para la mayoría de POCs)
  1.0,                                   -- peso_temporal (recomendado: mantener en 1.0)
  1.0,                                   -- peso_patron (0.9-1.0 según tipo de POC)

  -- Ajustes típicos:
  -- - prob_espacial te baja mucho la probabilidad → peso_espacial = 0.3-0.5
  -- - Muchos vecinos frecuentes → peso_patron = 0.9
  -- - POC muy estricto → peso_patron = 1.0-1.2

  -- =========================================================================
  -- NOTAS (documentación)
  -- =========================================================================
  'Añade aquí notas sobre por qué elegiste estos parámetros'
);

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

-- Después de ejecutar el INSERT, verifica que se añadió correctamente:

SELECT *
FROM `mo-advertising-sta.ADVERTISING_TEST.CONFIG_MODELO_PARAMETRIZADA`
WHERE tipo_poc = 'NOMBRE_TU_POC';

-- ============================================================================
-- SIGUIENTE PASO
-- ============================================================================

/*
1. ✅ Has añadido la configuración

2. Ahora ejecutar 03_MODELO_GENERICO.sql:
   - Cambiar línea 454: WHERE tipo_poc = 'NOMBRE_TU_POC'
   - Cambiar línea 515: WHERE v.poc = 'TU_CAMPAÑA_REAL'
   - Ejecutar

3. Validar resultados:
   - Query A: ver distribución de clasificaciones
   - ¿Cuántos MUY_PROBABLE salieron?
   - ¿Las características son razonables?

4. Ajustar umbrales:
   - Ejecutar 07_ANALISIS_UMBRALES.sql
   - Ajustar umbrales en esta tabla con UPDATE si es necesario

5. Re-ejecutar 03_MODELO_GENERICO.sql con umbrales ajustados

*/

-- ============================================================================
-- EJEMPLOS COMPLETOS
-- ============================================================================

/*
-- EJEMPLO 1: GASOLINERA
-- ---------------------
INSERT INTO CONFIG_MODELO_PARAMETRIZADA VALUES (
  'GASOLINERA', 'Gasolineras',
  0.0, 24.0,                              -- 24h
  300, 3600, 600, 1200,                   -- 5-60 min, óptimo 10-20 min
  0, 18, 1, 8,                            -- Frecuencia: 0-18 días, óptimo 1-8
  0.60, 0.85,                             -- Flexible
  1.3, 3.0, 6.0, 55.0,                    -- Patrón intermedio
  0.18, 0.12, 0.08, 0.04,                 -- Umbrales flexibles
  0.5, 1.0, 0.95,                         -- Pesos
  'Flexible. Visitas muy cortas. 24h.'
);

-- EJEMPLO 2: FARMACIA
-- -------------------
INSERT INTO CONFIG_MODELO_PARAMETRIZADA VALUES (
  'FARMACIA', 'Farmacias y parafarmacias',
  9.0, 21.0,                              -- 9-21h
  300, 3600, 600, 1800,                   -- 5-60 min, óptimo 10-30 min
  0, 14, 1, 6,                            -- Frecuencia: 0-14 días, óptimo 1-6
  0.70, 0.90,                             -- Intermedio
  1.3, 3.0, 6.0, 55.0,                    -- Patrón intermedio
  0.18, 0.12, 0.08, 0.04,                 -- Umbrales intermedios
  0.5, 1.0, 0.95,                         -- Pesos
  'Intermedio. Visitas cortas. Algunos vecinos frecuentes.'
);

-- EJEMPLO 3: GYM
-- --------------
INSERT INTO CONFIG_MODELO_PARAMETRIZADA VALUES (
  'GYM', 'Gimnasios y centros deportivos',
  6.0, 23.0,                              -- 6-23h (horario amplio)
  1800, 10800, 3600, 7200,                -- 30 min - 3h, óptimo 1-2h
  0, 22, 1, 12,                           -- Frecuencia: 0-22 días, óptimo 1-12 (alta frecuencia normal)
  0.70, 0.85,                             -- Intermedio
  1.2, 3.0, 6.0, 55.0,                    -- Patrón intermedio
  0.16, 0.10, 0.06, 0.03,                 -- Umbrales más bajos (alta frecuencia normal)
  0.5, 1.0, 0.9,                          -- Pesos (patrón ligeramente reducido por alta frecuencia normal)
  'Flexible. Alta frecuencia es normal. Jornadas largas aceptables.'
);

*/
