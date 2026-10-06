# Comparación: Modelo Agregado vs Por Día

**Versión**: 4.1  
**Fecha**: 2026-10-02

---

## 🎯 Dos enfoques del modelo genérico

Ambos modelos son **parametrizados** (funcionan para cualquier POC), pero difieren en la **granularidad** de evaluación:

| Modelo | Archivo | Granularidad | Filas |
|--------|---------|--------------|-------|
| **AGREGADO** | `03_MODELO_GENERICO.sql` | Usuario-ubicación | 1 fila por usuario |
| **POR DÍA** | `03_MODELO_GENERICO_POR_DIA.sql` | Día-usuario-ubicación | N filas por usuario |

---

## 📊 Modelo Agregado

### Qué hace

```
Usuario A visita 5 días → 1 FILA
- Promedio tiempo_ok: 45 min
- Promedio ratio: 0.85
- Stddev hora: 3.5h
- Días total: 5
→ Probabilidad: 0.18 → VISITA_PROBABLE
```

### Características

✅ **Ventajas**:
- Simple de interpretar: "¿es visitante o trabajador?"
- Menos filas → más rápido
- Más estricto con trabajadores
- Mejor para conteo de usuarios únicos

⚠️ **Desventajas**:
- Pierde granularidad: no sabes qué días específicos fueron válidos
- Un usuario con 1 día malo + 9 días buenos puede ser descartado

### Cuándo usar

- ✅ Objetivo: **conteo de usuarios válidos**
- ✅ Pregunta: "¿Cuántas personas visitaron el POC?"
- ✅ Solo necesitas clasificar usuarios (no días)
- ✅ Quieres ser conservador (evitar trabajadores)

---

## 📅 Modelo Por Día

### Qué hace

```
Usuario A visita 5 días → 5 FILAS

Día 1: tiempo_ok 30 min, ratio 0.9 → prob 0.25 → MUY_PROBABLE ✅
Día 2: tiempo_ok 60 min, ratio 0.85 → prob 0.22 → MUY_PROBABLE ✅
Día 3: tiempo_ok 480 min, ratio 0.4 → prob 0.05 → DESCARTADO ❌
Día 4: tiempo_ok 45 min, ratio 0.88 → prob 0.20 → MUY_PROBABLE ✅
Día 5: tiempo_ok 40 min, ratio 0.92 → prob 0.23 → MUY_PROBABLE ✅

Resultado: 4 días válidos, 1 día malo
Patrón agregado detecta: stddev=2.5h, 5 días → visitante regular
```

### Características

✅ **Ventajas**:
- Granularidad por día: sabes qué días fueron válidos
- No pierdes visitas válidas ocasionales
- Combina lo mejor: día-a-día + patrón agregado
- Puedes filtrar por % de días válidos

⚠️ **Desventajas**:
- Más filas → más lento de ejecutar
- Podría inflar conteos si no filtras bien
- Más complejo de interpretar

### Cuándo usar

- ✅ Objetivo: **conteo de visitas/impactos válidos**
- ✅ Pregunta: "¿Cuántas visitas válidas hubo al POC?"
- ✅ Necesitas saber días específicos
- ✅ Quieres flexibilidad: "usuarios con ≥50% días válidos"

---

## 🔄 Diferencias técnicas

### Cálculo de componentes

| Componente | **AGREGADO** | **POR DÍA** |
|------------|--------------|-------------|
| **tiempo_ok** | Promedio de todos los días | Cada día individual |
| **ratio_horario** | Promedio de todos los días | Cada día individual |
| **dif_horas** | Promedio de todos los días | Cada día individual |
| **stddev_hora** | De todos los días | De todos los días (igual) |
| **dias_visita** | Total de días | Total de días (igual) |
| **pct_fuera_horario** | De todos los días | De todos los días (igual) |

### Funciones UDF

**AGREGADO**:
```sql
calcular_prob_temporal_generica()     -- Usa promedio tiempo_ok
calcular_factor_patron_generico()     -- Usa patrón agregado
calcular_factor_frecuencia_param()    -- Usa días totales
```

**POR DÍA**:
```sql
calcular_prob_temporal_dia_param()         -- Usa tiempo_ok DEL DÍA
calcular_factor_dia_param()                -- Evalúa EL DÍA
calcular_factor_frecuencia_param()         -- Usa días totales (igual)
calcular_factor_patron_agregado_param()    -- Usa patrón agregado (igual)
```

---

## 📈 Ejemplo comparativo

### Datos de entrada

```
Usuario: 12345
Ubicación: Volvo ABC
Periodo: 10 días

Día 1: 45 min, ratio 0.90
Día 2: 50 min, ratio 0.85
Día 3: 480 min, ratio 0.40  ← DÍA MALO (trabajó?)
Día 4: 40 min, ratio 0.92
Día 5: 42 min, ratio 0.88
Día 6: 60 min, ratio 0.80
Día 7: 480 min, ratio 0.38  ← DÍA MALO
Día 8: 38 min, ratio 0.95
Día 9: 55 min, ratio 0.82
Día 10: 48 min, ratio 0.87

Stddev hora_min: 2.8h (variable)
```

### Modelo AGREGADO

```
Promedio tiempo_ok: 134 min
Promedio ratio: 0.777
Stddev hora: 2.8h
Días total: 10

Evaluación:
- prob_temporal: 0.15 (tiempo promedio alto)
- factor_patron: 0.3 (10 días = frecuente)
- ratio: 0.5 (ratio promedio bajo)

→ prob_final: 0.023
→ DESCARTADO ❌

RESULTADO: 0 usuarios válidos
```

### Modelo POR DÍA

```
Día 1: prob 0.22 → MUY_PROBABLE ✅
Día 2: prob 0.20 → MUY_PROBABLE ✅
Día 3: prob 0.04 → DESCARTADO ❌
Día 4: prob 0.24 → MUY_PROBABLE ✅
Día 5: prob 0.21 → MUY_PROBABLE ✅
Día 6: prob 0.18 → PROBABLE ✅
Día 7: prob 0.03 → DESCARTADO ❌
Día 8: prob 0.25 → MUY_PROBABLE ✅
Día 9: prob 0.19 → PROBABLE ✅
Día 10: prob 0.22 → MUY_PROBABLE ✅

8/10 días válidos (80%)
Stddev hora: 2.8h → visitante (no trabajador)

RESULTADO: 8 visitas válidas
O: 1 usuario con 80% días válidos
```

---

## ⚖️ ¿Cuál usar?

### Usa MODELO AGREGADO si:

- ✅ Tu objetivo es **conteo de usuarios únicos**
- ✅ Quieres ser **conservador** (evitar trabajadores)
- ✅ Pregunta: "¿Cuántas **personas diferentes** visitaron?"
- ✅ No necesitas saber días específicos
- ✅ Prefieres **velocidad** de ejecución
- ✅ Más fácil de explicar a stakeholders

**Casos de uso**:
- Reporting de usuarios únicos por campaña
- Validación de reach (alcance)
- Comparación entre POCs (usuarios por POC)

---

### Usa MODELO POR DÍA si:

- ✅ Tu objetivo es **conteo de visitas/impactos**
- ✅ Quieres ser **flexible** (recuperar visitas válidas)
- ✅ Pregunta: "¿Cuántas **visitas válidas** hubo?"
- ✅ Necesitas días específicos (ej: enviar mensaje día siguiente)
- ✅ Quieres aplicar filtros: "usuarios con ≥X% días válidos"
- ✅ Análisis por día de semana

**Casos de uso**:
- Activación/retargeting (enviar mensaje después de visita)
- Análisis de patrones por día de semana
- Conteo de impactos publicitarios
- Detección de visitas ocasionales entre trabajadores

---

## 🎯 Flujo de decisión

```
┌─────────────────────────────────┐
│ ¿Qué quieres medir?             │
└────────┬────────────────────────┘
         │
    ┌────┴────┐
    │         │
USUARIOS    VISITAS
    │         │
    ▼         ▼
AGREGADO   POR DÍA
```

**Pregunta clave**: ¿Importa **quién** visitó o **cuándo** visitó?

- **Quién** (usuarios únicos) → **AGREGADO**
- **Cuándo** (visitas por día) → **POR DÍA**

---

## 💰 Consideraciones de performance

| Aspecto | **AGREGADO** | **POR DÍA** |
|---------|--------------|-------------|
| **Filas generadas** | ~1-2M | ~10-20M (10x más) |
| **Tiempo ejecución** | ~2-3 min | ~5-8 min |
| **Costo BigQuery** | Menor | Mayor (más datos procesados) |
| **Complejidad** | Baja | Media |

**Recomendación**:
- Desarrollo/pruebas: usa **AGREGADO** (más rápido)
- Producción (si necesitas días): usa **POR DÍA**
- Reporting ejecutivo: usa **AGREGADO** (más simple)

---

## 🔀 Estrategia híbrida

Puedes usar **ambos** para diferentes propósitos:

### Paso 1: Modelo POR DÍA → Detectar visitas
```sql
-- Ejecutar 03_MODELO_GENERICO_POR_DIA.sql
-- Identificar días válidos
```

### Paso 2: Filtrar usuarios por % días válidos
```sql
-- Usuarios con ≥50% días válidos
SELECT msisdn
FROM (
  SELECT 
    msisdn,
    100.0 * SUM(CASE WHEN prob_visita_dia >= 0.15 THEN 1 ELSE 0 END) / COUNT(*) as pct_dias_validos
  FROM VISITAS_CLASIFICADAS_GEN_DIA
  GROUP BY msisdn
)
WHERE pct_dias_validos >= 50;
```

### Paso 3: Validar con modelo AGREGADO
```sql
-- Ejecutar 03_MODELO_GENERICO.sql
-- Verificar que estos mismos usuarios salen válidos
```

**Ventaja**: 
- Por día detecta visitas
- Agregado valida que no sean trabajadores
- Mejor de ambos mundos

---

## 📝 Resumen

| Criterio | **AGREGADO** | **POR DÍA** |
|----------|--------------|-------------|
| **Granularidad** | Usuario | Día |
| **Filas** | Pocas | Muchas |
| **Velocidad** | Rápido | Lento |
| **Conservador** | Sí | No |
| **Flexibilidad** | Baja | Alta |
| **Objetivo** | Usuarios únicos | Visitas/impactos |
| **Complejidad** | Baja | Media |
| **Cuándo** | Default | Casos específicos |

**Recomendación general**: 
- **Empieza con AGREGADO** (más simple)
- **Cambia a POR DÍA** solo si necesitas granularidad por día

---

**Versión**: 1.0  
**Última actualización**: 2026-10-02  
**Autor**: Equipo de Analítica - Modelo de Visitas
