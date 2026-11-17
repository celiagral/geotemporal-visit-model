-- ============================================================================
-- SCRIPT DE LIMPIEZA - MODELO V2
-- ============================================================================
--
-- Este script borra TODAS las tablas y funciones creadas por:
-- - 04_MODELO_MEJORADO_V2.sql
--
-- ⚠️ ADVERTENCIA: Esta operación NO es reversible
--
-- Úsalo cuando:
-- - Quieres re-ejecutar el modelo desde cero
-- - Estás testeando y quieres limpiar
-- - Hay conflictos con ejecuciones anteriores
-- - Vas a migrar a una nueva versión
--
-- ============================================================================

-- Solicitar confirmación (comentar para ejecutar sin confirmación)
-- IMPORTANTE: BigQuery ejecutará este script inmediatamente
-- Si no estás seguro, NO ejecutes este archivo


-- ============================================================================
-- PASO 1: Borrar Tablas de Configuración
-- ============================================================================

DROP TABLE IF EXISTS `mo-advertising-sta.ADVERTISING_TEST.PERFILES_NEGOCIO_BASE`;
DROP TABLE IF EXISTS `mo-advertising-sta.ADVERTISING_TEST.CONFIG_POC_V2`;
DROP TABLE IF EXISTS `mo-advertising-sta.ADVERTISING_TEST.CONFIG_CALCULADA_V2`;

SELECT
  'Tablas de configuración eliminadas' as paso_1,
  CURRENT_TIMESTAMP() as timestamp;


-- ============================================================================
-- PASO 2: Borrar Tablas de Resultados
-- ============================================================================

DROP TABLE IF EXISTS `mo-advertising-sta.ADVERTISING_TEST.VISITAS_FINALES_V2`;

SELECT
  'Tablas de resultados eliminadas' as paso_2,
  CURRENT_TIMESTAMP() as timestamp;


-- ============================================================================
-- PASO 3: Borrar Funciones UDF
-- ============================================================================

DROP FUNCTION IF EXISTS `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_temporal_dia_v2`;
DROP FUNCTION IF EXISTS `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_dia_v2`;
DROP FUNCTION IF EXISTS `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_frecuencia_v2`;
DROP FUNCTION IF EXISTS `mo-advertising-sta.ADVERTISING_TEST.calcular_factor_patron_agregado_v2`;
DROP FUNCTION IF EXISTS `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_final_v2`;

SELECT
  'Funciones UDF eliminadas' as paso_3,
  CURRENT_TIMESTAMP() as timestamp;


-- ============================================================================
-- PASO 4: Borrar Tablas Temporales (si existen)
-- ============================================================================
-- Normalmente las TEMP TABLES se borran automáticamente al final de sesión
-- pero por si acaso:

DROP TABLE IF EXISTS validacion_config;
DROP TABLE IF EXISTS CONFIG_POC_ACTIVA;
DROP TABLE IF EXISTS DIAS_PASS1;
DROP TABLE IF EXISTS DIAS_CLASIFICADOS_PASS1;
DROP TABLE IF EXISTS PATRON_LIMPIO;

SELECT
  'Tablas temporales eliminadas' as paso_4,
  CURRENT_TIMESTAMP() as timestamp;


-- ============================================================================
-- PASO 5: Verificación Final
-- ============================================================================

-- Listar tablas que aún existen (debería estar vacío)
SELECT
  table_name,
  table_type,
  creation_time
FROM `mo-advertising-sta.ADVERTISING_TEST.INFORMATION_SCHEMA.TABLES`
WHERE table_name IN (
  'PERFILES_NEGOCIO_BASE',
  'CONFIG_POC_V2',
  'CONFIG_CALCULADA_V2',
  'VISITAS_FINALES_V2'
)
ORDER BY table_name;

-- Si la query anterior devuelve 0 filas → ✅ Limpieza exitosa


-- Listar funciones que aún existen (debería estar vacío)
SELECT
  routine_name,
  routine_type,
  creation_time
FROM `mo-advertising-sta.ADVERTISING_TEST.INFORMATION_SCHEMA.ROUTINES`
WHERE routine_name LIKE '%_v2'
ORDER BY routine_name;

-- Si la query anterior devuelve 0 filas → ✅ Limpieza exitosa


-- ============================================================================
-- RESUMEN FINAL
-- ============================================================================

SELECT
  '✅ LIMPIEZA COMPLETADA' as status,
  CURRENT_TIMESTAMP() as timestamp,
  'Modelo V2 completamente eliminado del dataset' as mensaje,
  'Puedes ejecutar 04_MODELO_MEJORADO_V2.sql nuevamente desde cero' as siguiente_paso;


-- ============================================================================
-- NOTAS ADICIONALES
-- ============================================================================

/*
TABLAS ELIMINADAS:
  - PERFILES_NEGOCIO_BASE
  - CONFIG_POC_V2
  - CONFIG_CALCULADA_V2
  - VISITAS_FINALES_V2

FUNCIONES ELIMINADAS:
  - calcular_factor_temporal_dia_v2
  - calcular_factor_dia_v2
  - calcular_factor_frecuencia_v2
  - calcular_factor_patron_agregado_v2
  - calcular_prob_final_v2

TEMP TABLES ELIMINADAS:
  - validacion_config
  - CONFIG_POC_ACTIVA
  - DIAS_PASS1
  - DIAS_CLASIFICADOS_PASS1
  - PATRON_LIMPIO

TABLAS QUE NO SE TOCAN (datos originales):
  ✅ VISITAS_UBICACION_GEO_TILES_CELIA_ISA_V2 (datos fuente)
  ✅ Cualquier tabla del modelo anterior (V1)

Si necesitas restaurar:
  - Re-ejecuta 04_MODELO_MEJORADO_V2.sql
  - O restaura desde backup si tienes
*/
