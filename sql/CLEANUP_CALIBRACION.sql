-- ============================================================================
-- SCRIPT DE LIMPIEZA - CALIBRACIÓN AUTOMÁTICA
-- ============================================================================
--
-- Este script borra TODAS las tablas creadas por:
-- - 05_CALIBRACION_AUTOMATICA.sql
--
-- ⚠️ ADVERTENCIA: Esta operación NO es reversible
--
-- ============================================================================


-- ============================================================================
-- PASO 1: Borrar Tablas de Estadísticas Base
-- ============================================================================

DROP TABLE IF EXISTS `mo-advertising-sta.ADVERTISING_TEST.ESTADISTICAS_BASE_POC`;
DROP TABLE IF EXISTS `mo-advertising-sta.ADVERTISING_TEST.PARAMETROS_AUTOMATICOS`;

SELECT
  'Tablas de estadísticas base eliminadas' as paso_1,
  CURRENT_TIMESTAMP() as timestamp;


-- ============================================================================
-- PASO 2: Borrar Tablas de Análisis de Distribuciones
-- ============================================================================

DROP TABLE IF EXISTS `mo-advertising-sta.ADVERTISING_TEST.ANALISIS_DISTRIBUCIONES`;
DROP TABLE IF EXISTS `mo-advertising-sta.ADVERTISING_TEST.PARAMETROS_LOGNORMAL`;

SELECT
  'Tablas de análisis de distribuciones eliminadas' as paso_2,
  CURRENT_TIMESTAMP() as timestamp;


-- ============================================================================
-- PASO 3: Borrar Tablas de Clustering
-- ============================================================================

DROP TABLE IF EXISTS `mo-advertising-sta.ADVERTISING_TEST.FEATURES_CLUSTERING`;
DROP TABLE IF EXISTS `mo-advertising-sta.ADVERTISING_TEST.POC_CLUSTERS`;
DROP MODEL IF EXISTS `mo-advertising-sta.ADVERTISING_TEST.modelo_kmeans`;

SELECT
  'Tablas de clustering eliminadas' as paso_3,
  CURRENT_TIMESTAMP() as timestamp;


-- ============================================================================
-- PASO 4: Borrar Tablas Híbridas
-- ============================================================================

DROP TABLE IF EXISTS `mo-advertising-sta.ADVERTISING_TEST.PARAMETROS_HIBRIDOS`;

SELECT
  'Tablas híbridas eliminadas' as paso_4,
  CURRENT_TIMESTAMP() as timestamp;


-- ============================================================================
-- PASO 5: Borrar Tablas de Ground Truth (si existen)
-- ============================================================================

DROP TABLE IF EXISTS `mo-advertising-sta.ADVERTISING_TEST.GROUND_TRUTH`;

SELECT
  'Tablas de ground truth eliminadas' as paso_5,
  CURRENT_TIMESTAMP() as timestamp;


-- ============================================================================
-- PASO 6: Verificación Final
-- ============================================================================

SELECT
  table_name,
  table_type,
  creation_time
FROM `mo-advertising-sta.ADVERTISING_TEST.INFORMATION_SCHEMA.TABLES`
WHERE table_name IN (
  'ESTADISTICAS_BASE_POC',
  'PARAMETROS_AUTOMATICOS',
  'ANALISIS_DISTRIBUCIONES',
  'PARAMETROS_LOGNORMAL',
  'FEATURES_CLUSTERING',
  'POC_CLUSTERS',
  'PARAMETROS_HIBRIDOS',
  'GROUND_TRUTH'
)
ORDER BY table_name;

-- Si la query anterior devuelve 0 filas → ✅ Limpieza exitosa


-- ============================================================================
-- RESUMEN FINAL
-- ============================================================================

SELECT
  '✅ LIMPIEZA COMPLETADA' as status,
  CURRENT_TIMESTAMP() as timestamp,
  'Tablas de calibración automática eliminadas' as mensaje,
  'Puedes ejecutar 05_CALIBRACION_AUTOMATICA.sql nuevamente' as siguiente_paso;


-- ============================================================================
-- NOTAS
-- ============================================================================

/*
TABLAS ELIMINADAS:
  - ESTADISTICAS_BASE_POC
  - PARAMETROS_AUTOMATICOS
  - ANALISIS_DISTRIBUCIONES
  - PARAMETROS_LOGNORMAL
  - FEATURES_CLUSTERING
  - POC_CLUSTERS
  - PARAMETROS_HIBRIDOS
  - GROUND_TRUTH

MODELOS ELIMINADOS:
  - modelo_kmeans (BigQuery ML)

TABLAS QUE NO SE TOCAN:
  ✅ CONFIG_POC_V2 (configuración del modelo V2)
  ✅ VISITAS_UBICACION_GEO_TILES_CELIA_ISA_V2 (datos fuente)
*/
