# Guía de Implementación del Modelo

**Versión**: 3.0  
**Fecha**: 2026-09-17

---

## 🎯 Objetivo

Este documento explica cómo implementar y usar el modelo probabilístico de estimación de visitas.

---

## 📋 Prerequisitos

1. ✅ Acceso a BigQuery proyecto `mm-datamart-kd`
2. ✅ Tabla base: `VISITAS_UBICACION_GEO_TILES_CELIA_ISA_V2` disponible
3. ✅ Permisos para crear funciones UDF y tablas

---

## 🚀 Paso a Paso

### PASO 1: Análisis Exploratorio (1-2 horas)

**Objetivo**: Entender la distribución de datos y detectar patrones.

#### 1.1. Ejecutar queries de análisis
```bash
# Abrir 02_QUERIES_ANALISIS.sql en BigQuery
# Ejecutar queries 1-14 en orden
```

**Queries clave**:
- Query 3: Resumen general
- Query 4: Distribución por clasificación actual
- Query 9: Impacto del filtro tiempo_no_ok
- Query 13: Escenarios de recuperación

#### 1.2. Guardar resultados
- Exportar Query 4, 9 y 13 a Excel/CSV
- Analizar números:
  - ¿Cuántos usuarios válidos actuales?
  - ¿Cuántos perdidos por tiempo_no_ok?
  - ¿Cuánto podemos recuperar con ratio ≥ 0.8?

#### 1.3. Revisar patrones
- Query 8: ¿Hay usuarios con patrón laboral claro?
- Query 11: Ver top usuarios trabajadores potenciales
- Query 12: Ver top usuarios visitantes claros

**Output esperado**:
```
Usuarios válidos actuales: ~1.5M
Usuarios perdidos por NO_OK: ~3.4M (3.2x más!)
Recuperables con ratio ≥ 0.8: ~800K (+53%)
```

---

### PASO 2: Implementar Modelo en BigQuery (30 min)

**Objetivo**: Crear funciones UDF y aplicar modelo a datos.

#### 2.1. Crear tabla de configuración
```sql
-- Ejecutar PARTE 1 de 03_MODELO.sql
-- Crea: CONFIG_MODELO_VISITAS
```

Verifica:
```sql
SELECT * FROM `mo-advertising-sta.ADVERTISING_TEST.CONFIG_MODELO_VISITAS`;
```

Debes ver 5 tipos de POC: CONCESIONARIO, SUPERMERCADO, etc.

#### 2.2. Crear funciones UDF
```sql
-- Ejecutar PARTE 2 de 03_MODELO.sql
-- Crea: calcular_prob_temporal()

-- Ejecutar PARTE 3 de 03_MODELO.sql
-- Crea: calcular_factor_patron_horario()

-- Ejecutar PARTE 4 de 03_MODELO.sql
-- Crea: calcular_prob_visita()
```

Verifica:
```sql
-- Test de la función
SELECT
  `mo-advertising-sta.ADVERTISING_TEST.calcular_prob_visita`(
    0.12,     -- prob_espacial
    2700,     -- tiempo_ok: 45 min
    300,      -- tiempo_no_ok: 5 min
    2,        -- dias_visita
    4.5,      -- stddev_hora_minima (horarios variables)
    4.2,      -- stddev_hora_maxima
    1.5,      -- dif_horas_promedio
    FALSE,    -- llega_antes_abrir
    FALSE,    -- sale_despues_cerrar
    'CONCESIONARIO'
  ) as prob_visita;

-- Esperado: ~0.10 (10%)
```

#### 2.3. Aplicar modelo a datos VOLVO
```sql
-- Ejecutar PARTE 5 de 03_MODELO.sql
-- Crea 3 tablas:
-- 1. USUARIOS_AGREGADOS (temporal)
-- 2. VISITAS_CON_PROBABILIDAD_VOLVO
-- 3. VISITAS_CLASIFICADAS_VOLVO
```

**⏱️ Tiempo estimado**: 3-5 minutos de procesamiento

---

### PASO 3: Validación de Resultados (1 hora)

**Objetivo**: Verificar que el modelo funciona correctamente.

#### 3.1. Ejecutar queries de validación
```sql
-- Ejecutar PARTE 6 de 03_MODELO.sql
-- Query A: Resumen de clasificaciones
-- Query B: Comparación filtro actual vs modelo
-- Query C: Top 100 usuarios MUY_PROBABLE
-- Query D: Usuarios recuperados
```

#### 3.2. Validación automática

**Checks esperados**:

✅ **Check 1**: Distribución de clasificaciones
```
VISITA_MUY_PROBABLE: ~30-40% usuarios
VISITA_PROBABLE:     ~15-20%
VISITA_POSIBLE:      ~10-15%
DUDOSO:              ~5-10%
DESCARTADO:          ~20-30%
```

✅ **Check 2**: Comparación con filtro actual
```
Válidos actual:       ~1.5M
Válidos modelo:       ~2.3M
Recuperados:          ~800K
Incremento:           ~53%
```

✅ **Check 3**: Calidad de recuperados
```
Ratio promedio:       >= 0.80
Prob espacial:        >= 0.10
Tiempo OK:            30-90 min
Días promedio:        1-4
```

#### 3.3. Validación manual (muestra)

Exportar Query C o D (top 100 usuarios) y revisar manualmente:

**Criterios a validar**:
- [ ] Ratio horario alto (≥ 0.8)
- [ ] Horarios variables (stddev > 3) o baja frecuencia (1-2 días)
- [ ] Tiempo OK razonable (30-120 min)
- [ ] Prob espacial razonable (≥ 0.10)
- [ ] NO cumple patrón laboral (factor_patron > 0.5)

**Señales de trabajador** (revisar casos):
- Stddev hora < 1.5h + días ≥ 5 + dif_horas > 7h
- Factor patrón < 0.3

Si encuentras trabajadores en top 100, revisa umbrales de la UDF.

---

### PASO 4: Ajuste de Parámetros (si necesario)

**Objetivo**: Afinar el modelo según validación.

#### 4.1. Ajustar umbral de probabilidad mínima

Si hay **demasiados falsos positivos** (trabajadores clasificados como visitantes):
```sql
-- En Query B, cambiar umbral de 0.15 a 0.18 o 0.20
WHERE prob_visita_final >= 0.18  -- Más estricto
```

Si hay **demasiados falsos negativos** (visitantes clasificados como dudosos):
```sql
-- En Query B, cambiar umbral de 0.15 a 0.12
WHERE prob_visita_final >= 0.12  -- Más flexible
```

#### 4.2. Ajustar penalización por patrón laboral

Si el modelo NO detecta trabajadores claros:
```sql
-- En calcular_factor_patron_horario(), hacer más estricto:
-- CASO 1: Cambiar umbral de dias_visita >= 5 a >= 4
-- CASO 2: Cambiar stddev < 1.5 a < 2.0
```

Si el modelo descarta demasiados visitantes frecuentes:
```sql
-- En calcular_factor_patron_horario(), hacer más flexible:
-- CASO 2: Cambiar stddev < 1.5 a < 1.0
-- CASO 3: Añadir condición AND dif_horas_promedio >= 8
```

#### 4.3. Ajustar por tipo de POC

Para **CONCESIONARIO** (Volvo), si umbral ratio 0.8 es muy flexible:
```sql
-- En calcular_prob_temporal(), CONCESIONARIO:
WHEN ratio_horario >= 0.8 THEN 0.75  -- Era 0.85, ahora más estricto
```

Para **SUPERMERCADO**, si ratio 0.5 es muy estricto:
```sql
-- En calcular_prob_temporal(), SUPERMERCADO:
WHEN ratio_horario >= 0.4 THEN 0.85  -- Era 0.5, ahora más flexible
```

---

### PASO 5: Exportar Usuarios Finales

**Objetivo**: Generar lista de usuarios válidos para campaña.

#### 5.1. Query de usuarios reportables
```sql
-- Usuarios con alta probabilidad de visita
CREATE OR REPLACE TABLE `mo-advertising-sta.ADVERTISING_TEST.USUARIOS_REPORTABLES_VOLVO` AS
SELECT
  msisdn,
  id_ubicacion,
  dias_visita,
  ROUND(prob_visita_final, 4) as prob_visita,
  clasificacion_final,
  
  -- Métricas adicionales
  ROUND(tiempo_ok_promedio / 60, 1) as tiempo_ok_min,
  ROUND(ratio_horario, 3) as ratio,
  ROUND(prob_espacial_promedio, 4) as prob_espacial,
  
  -- Flags
  valido_filtro_actual,
  recuperado_con_modelo
  
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_VOLVO`
WHERE prob_visita_final >= 0.15  -- Umbral recomendado
  AND prob_espacial_promedio >= 0.10  -- Calidad espacial mínima
ORDER BY prob_visita_final DESC;
```

#### 5.2. Exportar a archivo
```sql
-- En BigQuery UI:
-- 1. Ejecutar query anterior
-- 2. EXPORT > CSV to Google Cloud Storage
-- 3. Descargar archivo
```

#### 5.3. Comparar con lista actual
```sql
-- Ver diferencia entre filtro actual y modelo
SELECT
  'Solo en filtro actual' as segmento,
  COUNT(*) as n_usuarios
FROM `mo-advertising-sta.ADVERTISING_TEST.USUARIOS_REPORTABLES_VOLVO`
WHERE valido_filtro_actual = TRUE
  AND recuperado_con_modelo = FALSE

UNION ALL

SELECT
  'Solo en modelo (recuperados)' as segmento,
  COUNT(*) as n_usuarios
FROM `mo-advertising-sta.ADVERTISING_TEST.USUARIOS_REPORTABLES_VOLVO`
WHERE recuperado_con_modelo = TRUE

UNION ALL

SELECT
  'En ambos' as segmento,
  COUNT(*) as n_usuarios
FROM `mo-advertising-sta.ADVERTISING_TEST.USUARIOS_REPORTABLES_VOLVO`
WHERE valido_filtro_actual = TRUE;
```

---

## 🔧 Aplicar a Otras POCs

### Para SUPERMERCADO (Mercadona, Lidl)

**Cambios necesarios**:

1. En PASO 2.3, cambiar:
```sql
'CONCESIONARIO' as tipo_poc
-- Por:
'SUPERMERCADO' as tipo_poc
```

2. Ajustar POC en WHERE:
```sql
WHERE poc = 'MERCADONA_XXXXXXXXX'
```

3. Cambiar horarios en flags (si aplica):
```sql
-- Mercadona típicamente: 9-21h
CASE WHEN hora_minima < 9 THEN TRUE ELSE FALSE END as llega_antes_abrir_alguna_vez,
CASE WHEN hora_maxima > 21 THEN TRUE ELSE FALSE END as sale_despues_cerrar_alguna_vez,
```

**Umbrales esperados para SUPERMERCADO**:
- Ratio mínimo: ≥ 0.5 (más flexible)
- Prob mínima: ≥ 0.12
- Recuperación esperada: +40-60% (menos que concesionario)

---

### Para RESTAURANTE

**Cambios**:
```sql
'RESTAURANTE' as tipo_poc
-- Horarios típicos: 12-16h, 20-24h
CASE WHEN hora_minima < 12 THEN TRUE ELSE FALSE END as llega_antes_abrir,
CASE WHEN hora_maxima > 24 THEN TRUE ELSE FALSE END as sale_despues_cerrar,
```

---

## 📊 Monitoreo Continuo

### Semana 1-2: Validación intensiva
- [ ] Comparar con ventas reales (si disponible)
- [ ] Muestrear 100 usuarios semanalmente
- [ ] Ajustar umbrales según feedback

### Mensual:
- [ ] Re-ejecutar análisis exploratorio
- [ ] Verificar distribuciones no han cambiado drásticamente
- [ ] Actualizar parámetros si es necesario

### Query de monitoreo
```sql
-- Ejecutar mensualmente
SELECT
  DATE_TRUNC(fecha, MONTH) as mes,
  COUNT(DISTINCT msisdn) as usuarios_reportables,
  ROUND(AVG(prob_visita_final), 4) as prob_promedio,
  ROUND(AVG(ratio_horario), 3) as ratio_promedio
FROM `mo-advertising-sta.ADVERTISING_TEST.VISITAS_CLASIFICADAS_VOLVO` v
JOIN `mo-advertising-sta.ADVERTISING_TEST.VISITAS_UBICACION_GEO_TILES_CELIA_ISA_V2` raw
  ON v.msisdn = raw.msisdn
WHERE v.prob_visita_final >= 0.15
GROUP BY 1
ORDER BY 1;
```

---

## ⚠️ Troubleshooting

### Error: "Function not found"
**Causa**: Funciones UDF no creadas o en dataset incorrecto  
**Solución**: Verificar que ejecutaste PARTE 2-4 de 03_MODELO.sql

### Error: "Table not found"
**Causa**: Tabla base no existe o nombre incorrecto  
**Solución**: Verificar nombre completo de tabla base en PARTE 5

### Resultados inesperados: Todos usuarios = DESCARTADO
**Causa**: Umbrales muy estrictos  
**Solución**: Revisar Query A, si prob_visita_final promedio < 0.10, reducir penalizaciones

### Resultados inesperados: Demasiados MUY_PROBABLE
**Causa**: Umbrales muy flexibles  
**Solución**: Aumentar penalización en calcular_factor_patron_horario()

### Valores NULL en stddev_hora_*
**Causa**: Usuarios con 1 solo día (stddev indefinido)  
**Solución**: Ya manejado con IFNULL(stddev, 999) en calcular_prob_visita()

---

## 📝 Checklist Final

### Pre-Producción
- [ ] Análisis exploratorio ejecutado y revisado
- [ ] Modelo implementado en BigQuery
- [ ] Validación automática OK (queries PARTE 6)
- [ ] Validación manual de muestra (100 usuarios)
- [ ] Parámetros ajustados según validación
- [ ] Tabla USUARIOS_REPORTABLES creada
- [ ] Comparación con filtro actual verificada
- [ ] Incremento de usuarios confirma expectativas (+40-60%)

### Producción
- [ ] Exportar lista final de usuarios
- [ ] Documentar umbrales finales usados
- [ ] Compartir resultados con equipo
- [ ] Configurar monitoreo mensual
- [ ] Planificar validación con datos de ventas (si disponible)

---

## 📞 Soporte

### Documentación relacionada
- Variables: [01_VARIABLES.md](01_VARIABLES.md)
- Análisis: [02_QUERIES_ANALISIS.sql](02_QUERIES_ANALISIS.sql)
- Modelo: [03_MODELO.sql](03_MODELO.sql)

### Preguntas frecuentes

**P: ¿Puedo cambiar el umbral de 0.15 a otro valor?**  
R: Sí, pero validar antes. 0.15 es conservador. Entre 0.12-0.18 es razonable.

**P: ¿Cómo sé si estoy recuperando trabajadores?**  
R: Revisar Query C: si top 100 tiene muchos con stddev < 1.5h + dias ≥ 5, posible problema.

**P: ¿El modelo funciona para cualquier POC?**  
R: Sí, pero ajustar `tipo_poc` y horarios. Cada tipo tiene umbrales diferentes.

**P: ¿Qué pasa si no tengo hora_minima/hora_maxima?**  
R: El modelo funciona igual, pero factor_patron será siempre 1.0 (sin penalización por patrón).

**P: ¿Puedo usar solo ratio sin patrón horario?**  
R: Sí, omitir PARTE 3 y usar solo calcular_prob_temporal(). Menos preciso pero más simple.

---

## ✅ Siguientes Pasos

1. **Inmediato**: Ejecutar PASO 1 (análisis exploratorio)
2. **Esta semana**: Ejecutar PASO 2-3 (implementar y validar)
3. **Próxima semana**: PASO 4-5 (ajustar y exportar)
4. **Recurrente**: Monitoreo mensual

---

**Versión del documento**: 3.0  
**Última actualización**: 2026-09-17  
**Autor**: Modelo de Estimación de Visitas - Equipo Analítica
