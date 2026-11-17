# 🎯 Guía de Versiones del Modelo

## 📊 ¿Qué versión usar?

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  ¿Qué tan cómodo te sientes con SQL/configuraciones?          │
│                                                                 │
│  😰 No mucho          →  MODELO SIMPLE V2.1 ✅                 │
│  😊 Moderado          →  MODELO SIMPLE V2.1 ✅                 │
│  🤓 Muy cómodo        →  MODELO MEJORADO V2.0                  │
│  🧙 Experto + Python  →  MODELO V2.0 + CALIBRACIÓN AUTO       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📂 Archivos Disponibles

### **RECOMENDADO: Modelo Simple V2.1**
📁 `sql/06_MODELO_SIMPLE_V2.sql`  
📁 `sql/07_HELPER_CALCULO_PARAMETROS.sql` (opcional)

**Cuándo usar**: La mayoría de casos  
**Complejidad**: ⭐⭐ Baja-Media  
**Tiempo setup**: 30 minutos  

---

### **Avanzado: Modelo Mejorado V2.0**
📁 `sql/04_MODELO_MEJORADO_V2.sql`

**Cuándo usar**: Tienes 10+ tipos de POC, necesitas máxima flexibilidad  
**Complejidad**: ⭐⭐⭐⭐ Alta  
**Tiempo setup**: 2-3 horas  

---

### **Experto: Calibración Automática**
📁 `sql/05_CALIBRACION_AUTOMATICA.sql`  
📁 `notebooks/analisis_distribuciones.py`

**Cuándo usar**: Tienes muchos POCs, quieres automatizar todo  
**Complejidad**: ⭐⭐⭐⭐⭐ Muy Alta  
**Tiempo setup**: 1 semana  
**Requiere**: Python, conocimientos estadística

---

## 🔍 Comparación Detallada

### **Modelo Simple V2.1** (RECOMENDADO)

#### Estructura
```
CONFIG_SIMPLE (1 tabla)
├── tipo_poc
├── hora_apertura, hora_cierre
├── tiempo_min, tiempo_optimo_min, tiempo_optimo_max, tiempo_max
├── dias_optimo_min, dias_optimo_max, dias_max
├── ratio_minimo, ratio_optimo
├── stddev_max_trabajador, dif_horas_min_trabajador, pct_fuera_max
├── umbrales (muy_probable, probable, posible)
└── pesos (espacial, temporal, patron)
```

#### ✅ Ventajas
- **Simple**: 1 tabla, parámetros directos
- **Transparente**: Ves exactamente qué valor tienes configurado
- **Fácil ajustar**: UPDATE de 1 línea
- **Mantiene lo crítico**: 2-pass + pesos correctos
- **Helper opcional**: Script calcula sugerencias por ti

#### ❌ Desventajas
- Ajustar cada POC individualmente (pero es rápido)
- No tiene jerarquía de perfiles (pero no la necesitas)

#### 📝 Ejemplo de Uso
```sql
-- 1. Ver config actual
SELECT * FROM CONFIG_SIMPLE WHERE tipo_poc = 'SUPERMERCADO';

-- 2. Ajustar un parámetro
UPDATE CONFIG_SIMPLE
SET tiempo_optimo_max = 4200  -- Cambiar a 70 min
WHERE tipo_poc = 'SUPERMERCADO';

-- 3. Añadir nuevo POC (copiar/pegar + ajustar)
INSERT INTO CONFIG_SIMPLE VALUES (
  'MI_POC', 'v2.1', CURRENT_TIMESTAMP(),
  9.0, 21.0,  -- horarios
  600, 1200, 3600, 7200,  -- tiempos
  1, 4, 12,  -- frecuencia
  0.70, 0.85,  -- ratios
  1.3, 6.0, 55.0,  -- detección trabajadores
  0.18, 0.12, 0.08,  -- umbrales
  0.30, 0.40, 0.30,  -- pesos
  'Notas'
);
```

#### 🤖 Auto-cálculo Opcional
```sql
-- Ejecutar helper
-- Ver 07_HELPER_CALCULO_PARAMETROS.sql

-- Te da sugerencias como:
tiempo_min = 450 (7.5 min)
tiempo_optimo_min = 720 (12 min)
tiempo_optimo_max = 2400 (40 min)
tiempo_max = 4800 (80 min)

-- Copias manualmente a CONFIG_SIMPLE
```

---

### **Modelo Mejorado V2.0** (Avanzado)

#### Estructura
```
PERFILES_NEGOCIO_BASE (3 perfiles)
├── COMPRA_PLANIFICADA
├── COMPRA_RUTINARIA
└── OCIO

CONFIG_POC_V2 (config específica)
├── tipo_poc
├── perfil_base (hereda de arriba)
├── ajuste_tiempo (multiplicador)
└── ajuste_frecuencia (multiplicador)

CONFIG_CALCULADA_V2 (derivada automáticamente)
└── Todos los parámetros finales
```

#### ✅ Ventajas
- **DRY**: Reutiliza perfiles base
- **Escalable**: Fácil añadir 100 POCs
- **Consistente**: Parámetros derivados garantizan coherencia
- **Flexible**: Override granular cuando necesario

#### ❌ Desventajas
- **Complejo**: 3 tablas, derivaciones
- **Menos transparente**: ¿De dónde salió este valor?
- **Difícil debuggear**: Cambias perfil base → afecta 10 POCs
- **Curva de aprendizaje**: Requiere entender jerarquía

#### 📝 Ejemplo de Uso
```sql
-- 1. Añadir POC (hereda de perfil)
INSERT INTO CONFIG_POC_V2 VALUES (
  'MI_POC',
  'COMPRA_RUTINARIA',  -- Hereda tiempo_base, frecuencia_base, etc.
  'v2.0',
  CURRENT_TIMESTAMP(),
  9.0, 21.0,  -- Solo horarios específicos
  1.2,  -- ajuste_tiempo (20% más largo que base)
  1.0,  -- ajuste_frecuencia (sin cambio)
  -- ... resto de STRUCTs
);

-- 2. Re-generar config calculada
CREATE OR REPLACE TABLE CONFIG_CALCULADA_V2 AS
SELECT ... -- Derivación automática

-- 3. Ver parámetros finales
SELECT * FROM CONFIG_CALCULADA_V2 WHERE tipo_poc = 'MI_POC';
```

#### ⚠️ Cuándo Usar
- Tienes 10+ tipos de POC
- Muchos POCs similares (ej: 5 tipos de supermercados)
- Equipo técnico fuerte
- Necesitas consistencia automática

---

### **Calibración Automática** (Experto)

#### Qué Hace
1. **Analiza distribuciones** de tus datos
2. **Ajusta modelos** probabilísticos (Log-Normal, Gamma, etc.)
3. **Calcula parámetros** óptimos automáticamente
4. **Optimiza pesos** con ground truth o proxy metrics

#### ✅ Ventajas
- **Automático**: Casi sin intervención manual
- **Estadísticamente robusto**: Fundamento matemático
- **Escalable**: Funciona con 100s de POCs
- **Optimizado**: Pesos maximizan métrica objetivo

#### ❌ Desventajas
- **Complejo**: Requiere Python, scipy, sklearn
- **Tiempo**: Setup inicial 1 semana
- **Black box**: Difícil explicar por qué eligió X
- **Requiere datos**: Mínimo 100-200 usuarios por POC

#### 📝 Ejemplo de Uso
```bash
# 1. Ejecutar análisis
python notebooks/analisis_distribuciones.py --poc SUPERMERCADO

# 2. Ver gráficos generados
# distribucion_tiempo_SUPERMERCADO.png
# distribucion_frecuencia_SUPERMERCADO.png

# 3. Parámetros auto-calculados en JSON
# config_SUPERMERCADO.json

# 4. Subir a BigQuery
bq load CONFIG_SIMPLE config_SUPERMERCADO.json
```

#### ⚠️ Cuándo Usar
- Tienes 20+ tipos de POC
- Aparecen POCs nuevos constantemente
- Tienes equipo con Python/Data Science
- Quieres automatización completa

---

## 🚀 Migración entre Versiones

### De Modelo Anterior → Simple V2.1

```sql
-- 1. Limpiar anterior (OPCIONAL)
-- Ver CLEANUP_MODELO_V2.sql

-- 2. Mapear parámetros manualmente
-- Tu CONFIG_MODELO_PARAMETRIZADA antigua:
tiempo_min_valido = 900
tiempo_optimo_min = 1800
tiempo_optimo_max = 5400
tiempo_max_valido = 10800

-- Se mapea 1:1 a CONFIG_SIMPLE:
tiempo_min = 900
tiempo_optimo_min = 1800
tiempo_optimo_max = 5400
tiempo_max = 10800

-- 3. Insertar en CONFIG_SIMPLE
INSERT INTO CONFIG_SIMPLE VALUES (...);
```

### De Simple V2.1 → Mejorado V2.0

```sql
-- 1. Identificar qué perfil base
-- Si tiempo_base ~1800s y dias_base ~2 → COMPRA_RUTINARIA

-- 2. Calcular ajustes
-- ajuste_tiempo = tu_tiempo_optimo_min / perfil_tiempo_base
-- ajuste_tiempo = 1800 / 1800 = 1.0

-- 3. Insertar en CONFIG_POC_V2
INSERT INTO CONFIG_POC_V2 VALUES (
  'MI_POC',
  'COMPRA_RUTINARIA',  -- Perfil base identificado
  ...
  1.0,  -- ajuste_tiempo calculado
  ...
);
```

### De Mejorado V2.0 → Simple V2.1

```sql
-- 1. Leer CONFIG_CALCULADA_V2 (parámetros derivados)
SELECT * FROM CONFIG_CALCULADA_V2 WHERE tipo_poc = 'MI_POC';

-- 2. Copiar valores directamente a CONFIG_SIMPLE
INSERT INTO CONFIG_SIMPLE VALUES (
  'MI_POC',
  'v2.1',
  CURRENT_TIMESTAMP(),
  -- Copiar valores de CONFIG_CALCULADA_V2
  hora_apertura,
  hora_cierre,
  tiempo_min_valido,  -- → tiempo_min
  tiempo_optimo_min,
  tiempo_optimo_max,
  tiempo_max_valido,  -- → tiempo_max
  ...
);
```

---

## 💡 Casos de Uso Reales

### Caso 1: Startup con 3 tipos de POC
**Recomendación**: Modelo Simple V2.1  
**Por qué**: Rápido setup, fácil ajustar

```sql
-- CONFIG_SIMPLE con 3 rows:
-- - SUPERMERCADO
-- - RESTAURANTE
-- - BANCO

-- Total tiempo setup: 1 hora
-- Ajustes posteriores: 5 minutos cada uno
```

---

### Caso 2: Empresa mediana con 15 tipos de POC
**Recomendación**: Modelo Simple V2.1 + Helper  
**Por qué**: Simple funciona bien, helper acelera setup

```sql
-- Workflow:
FOR EACH poc IN [poc1, poc2, ..., poc15]:
  1. Ejecutar 07_HELPER_CALCULO_PARAMETROS.sql
  2. Copiar valores sugeridos a CONFIG_SIMPLE
  3. Ajustar manualmente lo que no tenga sentido

-- Total tiempo: 3-4 horas (15 POCs × 15 min cada uno)
```

---

### Caso 3: Corporación con 50+ tipos de POC
**Recomendación**: Mejorado V2.0 O Calibración Auto  
**Por qué**: Necesitas escalabilidad y consistencia

```sql
-- Opción A: Mejorado V2.0 (si equipo técnico fuerte)
-- 3 perfiles base cubren 80% de POCs
-- Solo ajustas horarios + multiplicadores

-- Opción B: Calibración Auto (si tienes Data Science team)
-- Script automático genera configs
-- Ejecutas mensualmente para recalibrar
```

---

### Caso 4: POC Especial con Requisitos Únicos
**Recomendación**: Modelo Simple V2.1  
**Por qué**: Override total, no herencias que estorben

```sql
-- Ejemplo: Gasolinera 24/7 con trabajadores atípicos
INSERT INTO CONFIG_SIMPLE VALUES (
  'GASOLINERA',
  'v2.1',
  CURRENT_TIMESTAMP(),
  0.0, 24.0,  -- 24/7
  240, 600, 900, 3600,  -- Tiempos muy cortos
  1, 2, 20,  -- dias_max alto (turnos)
  0.30, 0.60,  -- Ratios permisivos
  0.3, 10.0, 100.0,  -- Trabajadores difíciles detectar
  0.10, 0.06, 0.03,  -- Umbrales bajos
  0.15, 0.25, 0.60,  -- TODO el peso en patrón
  'Gasolinera: caso especial'
);

-- Con jerarquía (V2.0) sería más difícil
```

---

## ❓ FAQ

**P: ¿Puedo empezar con Simple y luego migrar a Mejorado?**  
R: Sí, pero probablemente no necesites. Simple funciona bien hasta 20-30 POCs.

**P: ¿El Simple tiene las mismas mejoras que el Mejorado?**  
R: SÍ. Ambos tienen:
- ✅ Modelo 2-pass (elimina data leakage)
- ✅ Pesos correctos (promedio ponderado)
- ✅ Validación automática

Solo difieren en la **estructura de configuración**.

**P: ¿Cuánto tarda ajustar un POC nuevo con Simple?**  
R:
- Con helper: 10 minutos (ejecutar script + copiar valores)
- Manual: 15-20 minutos (si conoces el negocio)
- Primera vez: 30 minutos (aprender la estructura)

**P: ¿Puedo usar Calibración Auto con Modelo Simple?**  
R: SÍ. El helper (07_HELPER_CALCULO_PARAMETROS.sql) es justamente eso - cálculo automático simplificado. Si quieres la versión full Python, también puedes generar JSONs y cargarlos a CONFIG_SIMPLE.

**P: ¿Qué hago si tengo un POC que no cabe en ningún perfil?**  
R: Usa Modelo Simple. Esa es su ventaja - no estás forzado a elegir un perfil.

---

## 🎯 Recomendación Final

**90% de casos → Modelo Simple V2.1**

Es:
- Suficientemente potente (tiene todas las mejoras críticas)
- Fácil de entender
- Rápido de ajustar
- Transparente (ves todos los valores)

Solo usa las versiones más complejas si:
- Tienes 20+ POCs (Mejorado V2.0)
- Tienes equipo Data Science (Calibración Auto)
- Necesitas automatización total

**Cuando tengas dudas → Simple V2.1 ✅**

---

**Última actualización**: 2026-11-04  
**Versión de guía**: 1.0
