-- ============================================================================
-- LIMPIEZA - MODELO SIMPLE V2.1
-- ============================================================================
--
-- Borra todas las tablas y funciones creadas por:
-- - 06_MODELO_SIMPLE_V2.sql
--
-- ⚠️ ADVERTENCIA: NO es reversible
--
-- ============================================================================


-- ============================================================================
-- PASO 1: Borrar Tabla de Configuración
-- ============================================================================

DROP TABLE IF EXISTS `mo-advertising-sta.ADVERTISING_TEST.CONFIG_SIMPLE`;

SELECT '✅ Tabla de configuración eliminada' as paso_1;


-- ============================================================================
-- PASO 2: Borrar Tabla de Resultados
-- ============================================================================

DROP TABLE IF EXISTS `mo-advertising-sta.ADVERTISING_TEST.RESULTADOS_SIMPLE`;

SELECT '✅ Tabla de resultados eliminada' as paso_2;


-- ============================================================================
-- PASO 3: Borrar Funciones UDF
-- ============================================================================

DROP FUNCTION IF EXISTS `mo-advertising-sta.ADVERTISING_TEST.prob_temporal_dia`;
DROP FUNCTION IF EXISTS `mo-advertising-sta.ADVERTISING_TEST.factor_patron`;
DROP FUNCTION IF EXISTS `mo-advertising-sta.ADVERTISING_TEST.prob_final`;

SELECT '✅ Funciones UDF eliminadas' as paso_3;


-- ============================================================================
-- PASO 4: Borrar Tablas Temporales
-- ============================================================================

DROP TABLE IF EXISTS CONFIG_ACTIVA;
DROP TABLE IF EXISTS DIAS_PASS1;
DROP TABLE IF EXISTS DIAS_CLASIFICADOS_PASS1;
DROP TABLE IF EXISTS PATRON_LIMPIO;

SELECT '✅ Tablas temporales eliminadas' as paso_4;


-- ============================================================================
-- PASO 5: Verificación
-- ============================================================================

SELECT
  table_name,
  table_type,
  creation_time
FROM `mo-advertising-sta.ADVERTISING_TEST.INFORMATION_SCHEMA.TABLES`
WHERE table_name IN (
  'CONFIG_SIMPLE',
  'RESULTADOS_SIMPLE'
)
ORDER BY table_name;

-- Si devuelve 0 filas → ✅ Limpieza exitosa


SELECT
  routine_name,
  routine_type
FROM `mo-advertising-sta.ADVERTISING_TEST.INFORMATION_SCHEMA.ROUTINES`
WHERE routine_name IN (
  'prob_temporal_dia',
  'factor_patron',
  'prob_final'
)
ORDER BY routine_name;

-- Si devuelve 0 filas → ✅ Limpieza exitosa


-- ============================================================================
-- RESUMEN
-- ============================================================================

SELECT
  '✅ LIMPIEZA COMPLETADA' as status,
  CURRENT_TIMESTAMP() as timestamp,
  'Modelo Simple V2.1 eliminado' as mensaje,
  'Puedes ejecutar 06_MODELO_SIMPLE_V2.sql nuevamente' as siguiente_paso;


/*
TABLAS ELIMINADAS:
  - CONFIG_SIMPLE
  - RESULTADOS_SIMPLE

FUNCIONES ELIMINADAS:
  - prob_temporal_dia
  - factor_patron
  - prob_final

TEMP TABLES ELIMINADAS:
  - CONFIG_ACTIVA
  - DIAS_PASS1
  - DIAS_CLASIFICADOS_PASS1
  - PATRON_LIMPIO

DATOS INTACTOS:
  ✅ VISITAS_UBICACION_GEO_TILES_CELIA_ISA_V2
*/
