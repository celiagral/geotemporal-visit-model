# 📊 Modelo Mejorado V2 - Guía de Mejoras

## 🎯 Resumen Ejecutivo

El modelo V2 corrige **5 problemas críticos** del modelo anterior:

| Problema | Modelo Anterior | Modelo V2 |
|----------|----------------|-----------|
| **Data Leakage** | Estadísticas incluyen días "malos" | 2-pass: estadísticas solo de días buenos |
| **Pesos** | `POWER(prob, 0.5)` matemáticamente incorrecto | Promedio ponderado normalizado |
| **Parámetros** | 23 parámetros planos por POC | 3 perfiles base + ajustes específicos |
| **Validación** | Manual, propensa a errores | Automática con alertas |
| **Trazabilidad** | Sin versionado | config_version + fecha_actualizacion |

---

## 🔴 Problema 1: Data Leakage (EL MÁS CRÍTICO)

### ❌ Modelo Anterior
```sql
-- Calcula estadísticas sobre TODOS los días
CREATE TEMP TABLE PATRON_USUARIOS AS
SELECT
  msisdn,
  STDDEV(hora_minima) as stddev_hora_minima,  -- Incluye días de trabajadores!
  COUNT(DISTINCT fecha) as dias_visita_total   -- Cuenta días malos también!
FROM visitas
GROUP BY msisdn
```

**Ejemplo del problema:**
- Usuario A: 1 visita real + 14 días trabajando
- `dias_visita_total = 15` → clasificado como trabajador
- `stddev_hora_minima = 0.5` → patrón fijo
- **Resultado: descarta su visita real por contaminar las estadísticas con días laborales**

### ✅ Modelo V2 (2-PASS)

```sql
-- PASS 1: Clasificar días con info solo del día
CREATE TEMP TABLE DIAS_PASS1 AS
SELECT *, 
  CASE WHEN (factor_temporal * factor_dia) >= 0.4 THEN 'VALIDO' 
  ELSE 'DESCARTADO' END as clasificacion_pass1
FROM dias;

-- ESTADÍSTICAS LIMPIAS (solo días válidos)
CREATE TEMP TABLE PATRON_LIMPIO AS
SELECT
  msisdn,
  STDDEV(hora_minima) as stddev_hora_minima,  -- ✅ Solo días VALIDOS
  COUNT(DISTINCT fecha) as dias_visita_total
FROM DIAS_PASS1
WHERE clasificacion_pass1 = 'VALIDO'  -- ✅ CLAVE
GROUP BY msisdn;

-- PASS 2: Re-evaluar con patrón limpio
```

**Ejemplo corregido:**
- Usuario A: 1 visita real + 14 días trabajando
- Pass 1: visita real → `VALIDO`, días trabajando → `DESCARTADO`
- Estadísticas limpias: `dias_visita_total = 1`, `stddev = NULL` (solo 1 día)
- Pass 2: clasificado como visitante ocasional ✅

---

## 🟡 Problema 2: Uso Incorrecto de Pesos

### ❌ Modelo Anterior
```sql
POWER(prob_espacial, 0.5) *    -- Raíz cuadrada (!?)
POWER(prob_temporal, 1.0) *    -- Sin cambio
POWER(prob_patron, 1.0)        -- Sin cambio
```

**Problema matemático:**
- `peso = 0.5` → raíz cuadrada → NO es "reducir importancia"
- Ejemplo: `POWER(0.04, 0.5) = 0.2` (sube 5x) vs `POWER(0.64, 0.5) = 0.8` (baja)
- El resultado NO está garantizado en [0, 1]
- No es interpretable como "importancia"

### ✅ Modelo V2 (Promedio Ponderado)

```sql
CREATE FUNCTION calcular_prob_final_v2(
  prob_espacial FLOAT64,
  prob_temporal FLOAT64,
  prob_patron FLOAT64,
  peso_espacial FLOAT64,  -- Suma = 1.0
  peso_temporal FLOAT64,
  peso_patron FLOAT64
)
RETURNS FLOAT64
AS (
  (peso_espacial * prob_espacial) + 
  (peso_temporal * prob_temporal) + 
  (peso_patron * prob_patron)
  -- Resultado garantizado en [0,1] si todas las probs están en [0,1]
);
```

**Ejemplo:**
- Componentes: `espacial=0.8, temporal=0.6, patron=0.4`
- Pesos: `0.30, 0.40, 0.30` (suman 1.0)
- Resultado: `0.30*0.8 + 0.40*0.6 + 0.30*0.4 = 0.24 + 0.24 + 0.12 = 0.60` ✅

**Interpretación clara:**
- `peso = 0.30` → contribuye 30% a la probabilidad final
- `peso = 0.40` → contribuye 40% (más importante)

---

## 🟠 Problema 3: Complejidad de Configuración

### ❌ Modelo Anterior
```sql
CREATE TABLE CONFIG AS SELECT * FROM UNNEST([
  STRUCT(
    'CONCESIONARIO' as tipo_poc,
    900 as tiempo_min_valido,        -- 23 parámetros...
    10800 as tiempo_max_valido,      -- todos independientes
    1800 as tiempo_optimo_min,       -- propensos a inconsistencias
    5400 as tiempo_optimo_max,
    1 as dias_minimo,
    9 as dias_maximo,
    -- ... 17 más
  ),
  STRUCT(
    'SUPERMERCADO' as tipo_poc,
    600 as tiempo_min_valido,        -- Repetir todo otra vez
    7200 as tiempo_max_valido,       -- ¿Inconsistencias?
    -- ...
  )
]);
```

**Problemas:**
- Sin validación: ¿`tiempo_min < tiempo_optimo_min`?
- Duplicación: cada POC repite toda la lógica
- Difícil ajustar: cambiar "riesgo trabajadores" requiere tocar 5+ parámetros

### ✅ Modelo V2 (Jerarquía + Derivación)

```sql
-- PASO 1: 3 Perfiles Base
CREATE TABLE PERFILES_BASE AS SELECT * FROM UNNEST([
  STRUCT(
    'COMPRA_PLANIFICADA' as perfil,
    3600 as tiempo_base_segundos,      -- 1 valor base
    0.25 as tolerancia_min,            -- Factores multiplicativos
    3.0 as tolerancia_max,
    'LOW' as riesgo_trabajadores       -- Categoría simple
  ),
  -- Solo 3 perfiles en vez de 5+ POCs
]);

-- PASO 2: POCs heredan + ajustan
CREATE TABLE CONFIG_POC AS SELECT * FROM UNNEST([
  STRUCT(
    'CONCESIONARIO' as tipo_poc,
    'COMPRA_PLANIFICADA' as perfil_base,  -- Hereda
    1.0 as ajuste_tiempo,                 -- Multiplicador simple
    10.0 as hora_apertura                 -- Solo overrides
  )
]);

-- PASO 3: Derivar parámetros automáticamente
CREATE TABLE CONFIG_CALCULADA AS
SELECT
  c.tipo_poc,
  -- Derivar tiempo_min_valido
  CAST(p.tiempo_base * c.ajuste_tiempo * p.tolerancia_min AS INT64) 
    as tiempo_min_valido,
  -- Derivar tiempo_max_valido
  CAST(p.tiempo_base * c.ajuste_tiempo * p.tolerancia_max AS INT64) 
    as tiempo_max_valido,
  -- etc...
FROM CONFIG_POC c
JOIN PERFILES_BASE p ON c.perfil_base = p.perfil;
```

**Ventajas:**
- Consistencia garantizada (derivación automática)
- DRY: lógica compartida en perfiles base
- Fácil ajustar: cambiar `riesgo_trabajadores` en perfil afecta todos sus POCs

---

## 🟢 Problema 4: Sin Validación

### ❌ Modelo Anterior
- Si metes `tiempo_min = 5000, tiempo_max = 1000` → el modelo ejecuta sin error
- Resultados incorrectos, difícil de debuggear

### ✅ Modelo V2
```sql
CREATE TEMP TABLE validacion AS
SELECT
  tipo_poc,
  tiempo_min_valido < tiempo_optimo_min as check_1,
  tiempo_optimo_min < tiempo_optimo_max as check_2,
  tiempo_optimo_max < tiempo_max_valido as check_3,
  -- ... más validaciones
FROM CONFIG_CALCULADA;

-- Mostrar errores
SELECT tipo_poc,
  CASE 
    WHEN NOT check_1 THEN 'ERROR: tiempo_min >= tiempo_optimo_min'
    WHEN NOT check_2 THEN 'ERROR: tiempo_optimo_min >= tiempo_optimo_max'
    -- ...
    ELSE '✅ OK'
  END as estado
FROM validacion;
```

**Output:**
```
CONCESIONARIO     ✅ OK
SUPERMERCADO      ✅ OK
RESTAURANTE       ERROR: dias_optimo_max >= dias_max
```

---

## 📈 Problema 5: Sin Trazabilidad

### ❌ Modelo Anterior
- Ejecutas el modelo hoy con parámetros X → resultados A
- Cambias parámetros la semana que viene
- ¿Cómo sabes qué resultados vinieron de qué configuración?

### ✅ Modelo V2
```sql
CREATE TABLE CONFIG_POC AS SELECT * FROM UNNEST([
  STRUCT(
    'CONCESIONARIO' as tipo_poc,
    'v2.0' as config_version,               -- ✅ Versión
    CURRENT_TIMESTAMP() as fecha_actualizacion,  -- ✅ Timestamp
    -- ... resto
  )
]);

-- Los resultados incluyen config_version
CREATE TABLE RESULTADOS AS
SELECT v.*, c.config_version
FROM visitas v
JOIN CONFIG c USING(tipo_poc);
```

**Uso:**
```sql
-- ¿Qué configuración generó estos resultados?
SELECT DISTINCT config_version, fecha_actualizacion
FROM RESULTADOS
WHERE fecha_resultado = '2026-10-20';

-- Comparar versiones
SELECT config_version, AVG(prob_final)
FROM RESULTADOS
GROUP BY config_version;
```

---

## 🔄 Migración del Modelo Anterior → V2

### Checklist de Migración

1. **Copiar configuración actual**
   ```sql
   -- Documenta tus parámetros actuales
   SELECT * FROM CONFIG_MODELO_PARAMETRIZADA;
   ```

2. **Mapear a perfiles base**
   - ¿Tu POC es compra planificada, rutinaria u ocio?
   - Ajusta `ajuste_tiempo` y `ajuste_frecuencia`

3. **Ejecutar validación**
   - Si falla, ajusta los parámetros

4. **Comparar resultados (A/B test)**
   ```sql
   -- Modelo anterior
   SELECT COUNT(*) FROM VISITAS_CLASIFICADAS_GEN
   WHERE clasificacion_final = 'VISITA_PROBABLE';
   
   -- Modelo V2
   SELECT COUNT(*) FROM VISITAS_FINALES_V2
   WHERE clasificacion_final = 'VISITA_PROBABLE';
   ```

5. **Validar manualmente sample**
   - Top 100 usuarios de cada modelo
   - ¿Cuál tiene más sentido?

---

## 📊 Resultados Esperados

### Impacto del Modelo 2-Pass

**Escenario típico (Supermercado):**
- Modelo anterior: 1000 usuarios
  - 300 clasificados como trabajadores (descartados)
  - 700 visitantes válidos
  - **Pero:** 50 de los "trabajadores" tenían 1-2 visitas reales contaminadas

- Modelo V2: 1000 usuarios
  - Pass 1: 800 días válidos (filtra trabajadores)
  - Estadísticas limpias: sin contaminación
  - Pass 2: 750 visitantes válidos
  - **Recupera:** ~50 visitantes reales que antes se perdían

### Calibración de Pesos

**Recomendaciones por perfil:**

| Perfil | Espacial | Temporal | Patrón | Razón |
|--------|----------|----------|---------|-------|
| COMPRA_PLANIFICADA | 0.30 | 0.45 | 0.25 | Tiempo crítico (visitas largas) |
| COMPRA_RUTINARIA | 0.25 | 0.35 | 0.40 | Patrón crítico (detectar trabajadores) |
| OCIO | 0.30 | 0.40 | 0.30 | Balanceado |

---

## ⚠️ Limitaciones Conocidas

1. **Pass 1 threshold (0.4)**
   - Hardcoded en línea 759
   - Podría ser parámetro por POC
   - Muy bajo → incluye ruido en estadísticas
   - Muy alto → pierde visitas válidas

2. **Stddev con 1 día**
   - Si usuario tiene solo 1 día válido → `stddev = NULL`
   - Se trata como `stddev = 999` (visitante)
   - Correcto, pero podría ser más explícito

3. **No considera festivos/fines de semana**
   - Un trabajador podría visitar en fin de semana
   - Feature futura: `DIA_SEMANA`, `ES_FESTIVO`

---

## 🚀 Próximos Pasos

### Corto plazo (1-2 semanas)
- [ ] Ejecutar modelo V2 en paralelo con anterior
- [ ] Comparar resultados en 3-5 POCs diferentes
- [ ] Validar manualmente top 100 de cada uno
- [ ] Decidir migración completa

### Medio plazo (1 mes)
- [ ] Parametrizar threshold de Pass 1 por POC
- [ ] Añadir features temporales (día semana, festivos)
- [ ] Dashboard de monitoreo (distribución probabilidades)
- [ ] Calibración de umbrales con ground truth

### Largo plazo (2-3 meses)
- [ ] Recopilar ground truth (labels manuales)
- [ ] Piloto de modelo ML para 1 tipo de POC
- [ ] A/B test: parametrizado vs ML
- [ ] Automated retraining pipeline

---

## 📝 FAQs

**Q: ¿Por qué no directamente ML?**  
A: El modelo parametrizado es interpretable, auditable y funciona sin labels. ML necesita ground truth y es una caja negra. Para <10 tipos de POC, parametrizado es mejor.

**Q: ¿El modelo 2-pass es más lento?**  
A: Sí, ~30% más lento (dos escaneos de datos). Pero la calidad mejora significativamente. Si el tiempo es crítico, podemos optimizar con particionamiento.

**Q: ¿Puedo usar solo algunas mejoras?**  
A: Sí, son independientes:
- Solo 2-pass: mayor impacto, usa modelo anterior + añade Pass 1
- Solo pesos: cambio rápido, 10 líneas de código
- Solo jerarquía: útil si tienes 5+ tipos de POC

**Q: ¿Cómo ajusto los pesos?**  
A: Empieza con los recomendados arriba. Si tienes ground truth:
1. Calcula AUC con diferentes pesos
2. Grid search sobre peso_espacial, peso_temporal, peso_patron
3. Elige combinación con mejor AUC

**Q: ¿Qué hago si la validación falla?**  
A: Revisa el mensaje de error. Común:
- `tiempo_optimo_min >= tiempo_optimo_max`: ajusta `tolerancia_tiempo_optimo`
- `pesos no suman 1.0`: revisa decimales en STRUCT pesos

---

## 📧 Contacto y Soporte

Para preguntas o issues:
1. Revisa este README
2. Consulta comentarios en `04_MODELO_MEJORADO_V2.sql`
3. Ejecuta queries de validación (Parte 7 del script)
4. Si persiste el problema, documenta:
   - Tipo de POC
   - Configuración usada
   - Error exacto o resultado inesperado
