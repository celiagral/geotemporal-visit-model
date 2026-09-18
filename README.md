# Modelo Probabilístico de Estimación de Visitas

**POC**: VOLVO_XC40-AON_ABR2026_4  
**Fecha inicio**: 2026-09-17  
**Objetivo**: Estimar probabilidad de visita real a ubicación basado en señales temporales y espaciales

---

## 📋 Archivos del Proyecto

### 📖 Documentación
1. **[README.md](README.md)** - Este archivo (punto de inicio)
2. **[01_VARIABLES.md](01_VARIABLES.md)** - Descripción completa de variables disponibles
3. **[04_IMPLEMENTACION.md](04_IMPLEMENTACION.md)** - Guía de implementación y uso

### 💻 Código SQL
4. **[02_QUERIES_ANALISIS.sql](02_QUERIES_ANALISIS.sql)** - Queries exploratorias y análisis de datos
5. **[03_MODELO.sql](03_MODELO.sql)** - Modelo probabilístico final con función UDF

### 📊 Datos
6. **[querys.xlsx](querys.xlsx)** - Resultados de queries (cuando estén ejecutadas)

---

## 🎯 Modelo Propuesto

### Fórmula General

```
P(visita_real) = P(espacial) × P(temporal) × P(patron_horario)
```

### Componentes

**P(espacial)**: Ya calculada en tabla base
- Variable: `PROBABILIDAD_VISITA_OK`
- Usa método complementario con tiles geográficos

**P(temporal)**: Basada en tiempo y frecuencia
- Variables: `tiempo_total_ok_dia`, `dias_msisdn_ubicacion_PERIODO`
- Lógica: Visitas cortas (30-90 min) + baja frecuencia (1-4 días) = visitante

**P(patron_horario)**: Distingue visitantes de trabajadores
- Variables: `hora_minima`, `hora_maxima`, `tiempo_total_no_ok_dia`
- Lógica: Horarios variables + ratio alto = visitante

---

## 🚀 Inicio Rápido

### Paso 1: Entender Variables
Lee **[01_VARIABLES.md](01_VARIABLES.md)** para comprender todas las variables disponibles.

### Paso 2: Análisis Exploratorio
Ejecuta queries de **[02_QUERIES_ANALISIS.sql](02_QUERIES_ANALISIS.sql)** para explorar los datos:
- Distribución de tiempos
- Distribución de frecuencias
- Patrones horarios
- Impacto de `tiempo_no_ok`

### Paso 3: Implementar Modelo
Ejecuta **[03_MODELO.sql](03_MODELO.sql)** para crear función UDF y aplicar el modelo.

### Paso 4: Validar
Sigue guía en **[04_IMPLEMENTACION.md](04_IMPLEMENTACION.md)** para validar resultados.

---

## 📊 Variables Clave

| Variable | Descripción | Uso en Modelo |
|----------|-------------|---------------|
| `tiempo_total_ok_dia` | Tiempo en horario válido (seg) | P(temporal) - duración |
| `tiempo_total_no_ok_dia` | Tiempo fuera de horario (seg) | P(patron) - ratio |
| `hora_minima` | Hora llegada (decimal) | P(patron) - variabilidad |
| `hora_maxima` | Hora salida (decimal) | P(patron) - variabilidad |
| `dias_msisdn_ubicacion_PERIODO` | Días de visita | P(temporal) - frecuencia |
| `PROBABILIDAD_VISITA_OK` | Probabilidad espacial | P(espacial) |

**Ver más**: [01_VARIABLES.md](01_VARIABLES.md)

---

## 🔑 Conceptos Clave

### 1. Ratio de Horario

```sql
ratio_horario = tiempo_total_ok_dia / (tiempo_total_ok_dia + tiempo_total_no_ok_dia)
```

**Interpretación**:
- ratio ≥ 0.9 → 90%+ en horario → Visitante claro ✅
- ratio 0.7-0.9 → 70-90% en horario → Visitante probable ✅
- ratio 0.5-0.7 → 50-70% en horario → Dudoso ⚠️
- ratio < 0.5 → <50% en horario → Trabajador probable ❌

### 2. Variabilidad Horaria

```sql
stddev_hora_minima = STDDEV(hora_minima) OVER (PARTITION BY msisdn, id_ubicacion)
```

**Interpretación**:
- stddev < 1.5h → Horarios muy consistentes → Trabajador ❌
- stddev 1.5-3h → Algo de variación → Revisar ⚠️
- stddev > 3h → Horarios aleatorios → Visitante ✅

### 3. Patrón Laboral

```sql
patron_laboral = (
  dif_horas >= 7 AND
  hora_minima BETWEEN 7 AND 10 AND
  hora_maxima BETWEEN 17 AND 20 AND
  dias >= 4
)
```

**Interpretación**:
- patron_laboral = TRUE → Muy probable trabajador ❌
- patron_laboral = FALSE → No es trabajador típico ✅

---

## 📈 Flujo de Trabajo

```
1. DATOS BASE
   └─> Tabla: VISITAS_UBICACION_GEO_TILES_CELIA_ISA_V2
       Variables: tiempo_ok, tiempo_no_ok, hora_min, hora_max, dias, prob_espacial

2. ANÁLISIS EXPLORATORIO
   └─> Queries: 02_QUERIES_ANALISIS.sql
       Output: Distribuciones, correlaciones, patrones

3. MODELO PROBABILÍSTICO
   └─> SQL: 03_MODELO.sql
       Output: Función UDF calcular_prob_visita()

4. APLICACIÓN
   └─> Query: SELECT *, calcular_prob_visita(...) as prob_visita FROM tabla
       Output: Tabla con probabilidades

5. CLASIFICACIÓN
   └─> Umbral: prob_visita >= 0.15 → Visita reportable
       Output: Usuarios válidos
```

---

## 🎯 Objetivos del Modelo

### Objetivo 1: Precisión
Distinguir con alta confianza:
- ✅ **Visitantes reales**: Clientes potenciales
- ❌ **Trabajadores**: Empleados del establecimiento
- ❌ **Vecinos**: Personas que viven cerca

### Objetivo 2: Recuperación
Recuperar usuarios actualmente descartados por filtros muy estrictos:
- Usuarios con `tiempo_no_ok > 0` pero ratio alto
- Usuarios con tiempo válido pero fuera de rango estricto 30-90 min

### Objetivo 3: Escalabilidad
Modelo parametrizable por tipo de POC:
- **CONCESIONARIO** (Volvo): Estricto con ratio, nadie vive cerca
- **SUPERMERCADO** (Mercadona): Flexible con ratio, la gente vive cerca
- **OTROS**: Configuración específica según contexto

---

## ⚙️ Parámetros del Modelo

### Por Tipo de POC

| Tipo POC | Umbral Ratio | Umbral Prob | Notas |
|----------|--------------|-------------|-------|
| CONCESIONARIO | ≥ 0.8 | ≥ 0.15 | Estricto con tiempo fuera de horario |
| SUPERMERCADO | ≥ 0.5 | ≥ 0.12 | Flexible, gente vive cerca |
| RESTAURANTE | ≥ 0.7 | ≥ 0.14 | Intermedio |
| CENTRO COMERCIAL | ≥ 0.6 | ≥ 0.13 | Intermedio-flexible |

**Ver más**: [04_IMPLEMENTACION.md](04_IMPLEMENTACION.md)

---

## 📊 Próximos Pasos

### Inmediato
- [ ] Leer [01_VARIABLES.md](01_VARIABLES.md)
- [ ] Ejecutar queries de [02_QUERIES_ANALISIS.sql](02_QUERIES_ANALISIS.sql)
- [ ] Revisar distribuciones y patrones

### Corto Plazo
- [ ] Implementar función UDF de [03_MODELO.sql](03_MODELO.sql)
- [ ] Aplicar modelo a datos VOLVO
- [ ] Validar resultados (muestra manual)

### Medio Plazo
- [ ] Comparar con datos de ventas reales
- [ ] Ajustar parámetros según validación
- [ ] Expandir a otras POCs

---

## 📞 Estructura de Archivos

```
modelo-geo-tiempo/
│
├── README.md                    ← Estás aquí
├── 01_VARIABLES.md             ← Documentación de variables
├── 02_QUERIES_ANALISIS.sql     ← Análisis exploratorio
├── 03_MODELO.sql               ← Modelo probabilístico
├── 04_IMPLEMENTACION.md        ← Guía de implementación
└── querys.xlsx                 ← Resultados (cuando los ejecutes)
```

---

**Próximo paso**: Lee [01_VARIABLES.md](01_VARIABLES.md) para entender las variables disponibles.
