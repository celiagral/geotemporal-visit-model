# Variables Disponibles en el Modelo

**Tabla**: `VISITAS_UBICACION_GEO_TILES_CELIA_ISA_V2`  
**Proyecto**: mm-datamart-kd

---

## 📊 Catálogo de Variables

### 🔵 Variables de Identificación

| Variable | Tipo | Descripción |
|----------|------|-------------|
| `msisdn` | STRING | Identificador de usuario (anonimizado) |
| `id_ubicacion` | STRING | ID único de ubicación/POC |
| `poc` | STRING | Nombre de la campaña POC |
| `PERIODO` | STRING | Período ('CAMPAIGN' o 'BEFORE') |
| `fecha` | DATE | Fecha de la visita |
| `DIA_SEMANA` | STRING | Día de semana (MONDAY, TUESDAY, ...) |

---

## ⏱️ Variables Temporales Básicas

### 1. `tiempo_total_ok_dia` (CRÍTICO)
**Tipo**: INT64 (segundos)  
**Rango**: 0 - 86400  
**Descripción**: Tiempo total conectado en horario válido del establecimiento

**Ejemplo Volvo** (horario: 10-14h, 16-20h):
```
Usuario se conecta a tiles de Volvo:
- 11:00-11:45 (45 min) → EN horario
- 15:00-15:30 (30 min) → FUERA horario
- 17:00-18:00 (60 min) → EN horario

tiempo_total_ok_dia = (45 + 60) × 60 = 6,300 segundos
```

**Uso en modelo**: Duración de la visita, base para P(temporal)

### 2. `tiempo_total_no_ok_dia` (CRÍTICO)
**Tipo**: INT64 (segundos)  
**Rango**: 0 - 86400  
**Descripción**: Tiempo total conectado FUERA del horario válido

**Ejemplo continuación**:
```
tiempo_total_no_ok_dia = 30 × 60 = 1,800 segundos
```

**Uso en modelo**: Distinguir visitantes de trabajadores

### 3. `dif_horas`
**Tipo**: FLOAT64 (horas decimales)  
**Rango**: 0 - 24  
**Descripción**: Diferencia entre hora_maxima y hora_minima

**Ejemplo**:
```
hora_minima = 11.0 (11:00)
hora_maxima = 13.5 (13:30)
dif_horas = 2.5 horas
```

**Uso en modelo**: Duración de permanencia en el día

### 4. `num_horas`
**Tipo**: INT64  
**Rango**: 1 - 24  
**Descripción**: Número de horas distintas con conexiones

**Ejemplo**:
```
Conexiones en: 11:00-11:45, 13:15-13:30, 17:00-18:15
Horas tocadas: 11h, 13h, 17h, 18h
num_horas = 4
```

**Uso en modelo**: Continuidad de la visita

---

## 🕐 Variables de Horario (CRÍTICAS NUEVAS)

### 5. `hora_minima` (CRÍTICO)
**Tipo**: FLOAT64 (hora decimal)  
**Rango**: 0.0 - 23.99  
**Descripción**: Primera hora de conexión del día en la ubicación

**Formato**:
```
8.5  = 08:30
10.0 = 10:00
17.75 = 17:45
```

**Uso en modelo**: Detectar patrón de llegada consistente (trabajadores)

**Análisis por usuario**:
```sql
-- Variabilidad de hora de llegada
STDDEV(hora_minima) OVER (PARTITION BY msisdn, id_ubicacion)

Si stddev < 1.5h → Llega siempre a la misma hora → Trabajador probable
Si stddev > 3h → Llega a horas aleatorias → Visitante
```

### 6. `hora_maxima` (CRÍTICO)
**Tipo**: FLOAT64 (hora decimal)  
**Rango**: 0.0 - 23.99  
**Descripción**: Última hora de conexión del día en la ubicación

**Uso en modelo**: Detectar patrón de salida consistente (trabajadores)

**Análisis por usuario**:
```sql
-- Variabilidad de hora de salida
STDDEV(hora_maxima) OVER (PARTITION BY msisdn, id_ubicacion)

Si stddev < 1.5h → Sale siempre a la misma hora → Trabajador probable
Si stddev > 3h → Sale a horas aleatorias → Visitante
```

### 7. `HORARIO`
**Tipo**: STRING  
**Descripción**: Horario válido del establecimiento

**Formato**: Pares de horas separados por comas
```
Ejemplo Volvo: "10,14,16,20"
→ Abierto de 10-14h y de 16-20h
```

**Uso en modelo**: Definir qué es tiempo_ok vs tiempo_no_ok

---

## 📅 Variables de Frecuencia

### 8. `dias_msisdn_ubicacion_PERIODO`
**Tipo**: INT64  
**Rango**: 1 - 31 (según duración campaña)  
**Descripción**: Número de días distintos que el usuario visitó la ubicación

**Clasificación típica**:
```
1 día      → BAJA_FREC  (visitante ocasional)
2-4 días   → MEDIA_FREC (visitante regular)
5+ días    → ALTA_FREC  (visitante frecuente o trabajador)
```

**Uso en modelo**: Alta frecuencia + otros patrones → Posible trabajador

---

## 🌍 Variables Espaciales

### 9. `PROBABILIDAD_VISITA_OK`
**Tipo**: FLOAT64  
**Rango**: 0.0 - 1.0  
**Descripción**: Probabilidad de que el usuario esté en la ubicación dado que se conectó al sector

**Método de cálculo**: Complementario con tiles
```
P(ubicacion | sector) = 1 - Π(1 - p_tile_i) para todos tiles i
```

**Interpretación**:
```
> 0.8   → Muy alta confianza espacial
0.5-0.8 → Alta confianza
0.3-0.5 → Confianza media
0.1-0.3 → Confianza baja (pero válida)
< 0.1   → Muy baja confianza
```

**Uso en modelo**: Componente P(espacial) directamente

### 10. Otras variables espaciales
- `num_tiles_ubicacion`: Número de tiles de la ubicación
- `num_tiles_sector`: Número de tiles del sector
- `PROBABILIDAD_UBICACION`: Probabilidad individual promedio por tile

---

## 🔢 Variables Derivadas (A Calcular)

### D1. `ratio_horario` (CRÍTICO)
**Fórmula**:
```sql
ratio_horario = tiempo_total_ok_dia / (tiempo_total_ok_dia + tiempo_total_no_ok_dia)
```

**Rango**: 0.0 - 1.0

**Interpretación**:
```
1.00      → 100% en horario válido → Visitante claro
0.90-0.99 → 90-99% en horario → Visitante muy probable
0.80-0.89 → 80-89% en horario → Visitante probable
0.60-0.79 → 60-79% en horario → Dudoso
0.40-0.59 → 40-59% en horario → Probable trabajador/vecino
< 0.40    → Mayoría fuera de horario → Trabajador/vecino
```

**Ajuste por tipo POC**:
- **CONCESIONARIO**: Estricto, umbral ≥ 0.8
- **SUPERMERCADO**: Flexible, umbral ≥ 0.5

### D2. `stddev_hora_minima` (por usuario-ubicación)
**Fórmula**:
```sql
STDDEV(hora_minima) OVER (PARTITION BY msisdn, id_ubicacion)
```

**Rango**: 0.0 - 12.0 (en horas)

**Interpretación**:
```
< 1.0h → Muy consistente → Trabajador probable
1.0-1.5h → Consistente → Revisar
1.5-3.0h → Algo de variación → Probable visitante
> 3.0h → Muy variable → Visitante claro
```

### D3. `stddev_hora_maxima` (por usuario-ubicación)
**Fórmula**:
```sql
STDDEV(hora_maxima) OVER (PARTITION BY msisdn, id_ubicacion)
```

**Interpretación**: Similar a stddev_hora_minima

### D4. `patron_laboral` (FLAG)
**Fórmula**:
```sql
patron_laboral = (
  dif_horas >= 7 AND
  hora_minima BETWEEN 7 AND 10 AND
  hora_maxima BETWEEN 17 AND 20 AND
  dias_msisdn_ubicacion_PERIODO >= 4
)
```

**Valores**: TRUE / FALSE

**Interpretación**:
```
TRUE  → Cumple patrón típico de trabajador → Penalizar fuertemente
FALSE → No cumple patrón laboral → No penalizar
```

### D5. `tipo_frecuencia`
**Fórmula**:
```sql
CASE
  WHEN dias_msisdn_ubicacion_PERIODO = 1 THEN 'BAJA_FREC'
  WHEN dias_msisdn_ubicacion_PERIODO BETWEEN 2 AND 4 THEN 'MEDIA_FREC'
  ELSE 'ALTA_FREC'
END
```

**Interpretación**:
- BAJA_FREC: Visitante ocasional ✅
- MEDIA_FREC: Visitante regular ✅
- ALTA_FREC: Visitante frecuente o trabajador ⚠️

### D6. `bucket_tiempo`
**Fórmula**:
```sql
CASE
  WHEN tiempo_ok_min < 15 THEN '<15min'
  WHEN tiempo_ok_min < 30 THEN '15-30min'
  WHEN tiempo_ok_min < 60 THEN '30-60min'
  WHEN tiempo_ok_min < 90 THEN '60-90min'
  WHEN tiempo_ok_min < 120 THEN '90-120min'
  WHEN tiempo_ok_min < 180 THEN '2-3h'
  ELSE '>3h'
END
```

**Interpretación**:
- <30min: Visita muy corta ⚠️
- 30-90min: Rango ideal para visita ✅
- >90min: Visita larga o trabajador ⚠️

### D7. `llega_antes_abrir` / `sale_despues_cerrar`
**Fórmula** (ejemplo Volvo, abre 10h, cierra 20h):
```sql
llega_antes_abrir = (hora_minima < 10)
sale_despues_cerrar = (hora_maxima > 20)
```

**Interpretación**:
- Si llega antes frecuentemente → Trabajador probable
- Si sale después frecuentemente → Trabajador probable

---

## 📋 Tabla Resumen

| Variable | Fuente | Tipo | Uso Principal | Criticidad |
|----------|--------|------|---------------|------------|
| `msisdn` | Base | ID | Identificación | ⭐⭐⭐ |
| `id_ubicacion` | Base | ID | Identificación | ⭐⭐⭐ |
| `tiempo_total_ok_dia` | Base | Temporal | P(temporal) - duración | ⭐⭐⭐⭐⭐ |
| `tiempo_total_no_ok_dia` | Base | Temporal | P(patron) - ratio | ⭐⭐⭐⭐⭐ |
| `hora_minima` | Base | Temporal | P(patron) - variabilidad | ⭐⭐⭐⭐⭐ |
| `hora_maxima` | Base | Temporal | P(patron) - variabilidad | ⭐⭐⭐⭐⭐ |
| `dias_msisdn_ubicacion_PERIODO` | Base | Frecuencia | P(temporal) - frecuencia | ⭐⭐⭐⭐ |
| `PROBABILIDAD_VISITA_OK` | Base | Espacial | P(espacial) | ⭐⭐⭐⭐⭐ |
| `dif_horas` | Base | Temporal | P(patron) - duración permanencia | ⭐⭐⭐ |
| `num_horas` | Base | Temporal | P(patron) - continuidad | ⭐⭐ |
| `DIA_SEMANA` | Base | Temporal | Filtros laborables | ⭐⭐ |
| `HORARIO` | Base | Config | Definir tiempo_ok/no_ok | ⭐⭐⭐ |
| `ratio_horario` | Derivada | Patron | Distinguir visitante/trabajador | ⭐⭐⭐⭐⭐ |
| `stddev_hora_minima` | Derivada | Patron | Consistencia horaria | ⭐⭐⭐⭐ |
| `stddev_hora_maxima` | Derivada | Patron | Consistencia horaria | ⭐⭐⭐⭐ |
| `patron_laboral` | Derivada | Patron | Detector trabajador | ⭐⭐⭐⭐ |
| `tipo_frecuencia` | Derivada | Frecuencia | Clasificación visitante | ⭐⭐⭐ |

---

## 🎯 Combinaciones Clave para el Modelo

### Combinación 1: Visitante Claro
```
tiempo_ok: 30-90 min
ratio_horario: ≥ 0.8
dias: 1-4
stddev_hora_minima: > 3h
patron_laboral: FALSE
→ P(visita) = ALTA
```

### Combinación 2: Trabajador Claro
```
tiempo_ok: >180 min
ratio_horario: 0.4-0.7
dias: ≥ 5
stddev_hora_minima: < 1.5h
stddev_hora_maxima: < 1.5h
patron_laboral: TRUE
→ P(visita) = MUY BAJA (descartar)
```

### Combinación 3: Dudoso (Requiere Análisis)
```
tiempo_ok: 60-120 min
ratio_horario: 0.6-0.8
dias: 2-3
stddev_hora_minima: 2-3h
patron_laboral: FALSE
→ P(visita) = MEDIA (validar)
```

### Combinación 4: Vecino Visitante (Supermercado)
```
tiempo_ok: 15-45 min
ratio_horario: 0.3-0.6 (bajo porque vive cerca)
dias: 3-7
stddev_hora_minima: > 4h (horarios muy variables)
patron_laboral: FALSE
→ P(visita) = ALTA (para SUPERMERCADO)
```

---

## 🔍 Queries Útiles por Variable

### Ver distribución de hora_minima
```sql
SELECT
  FLOOR(hora_minima) as hora,
  COUNT(*) as n_registros,
  COUNT(DISTINCT msisdn) as n_usuarios
FROM tabla
GROUP BY 1
ORDER BY 1;
```

### Ver usuarios con horarios consistentes
```sql
WITH user_patterns AS (
  SELECT
    msisdn,
    id_ubicacion,
    STDDEV(hora_minima) as stddev_hora_min,
    STDDEV(hora_maxima) as stddev_hora_max,
    COUNT(DISTINCT fecha) as dias
  FROM tabla
  GROUP BY 1, 2
)
SELECT * FROM user_patterns
WHERE stddev_hora_min < 1.5
  AND stddev_hora_max < 1.5
  AND dias >= 4
ORDER BY dias DESC;
```

### Ver distribución de ratio_horario
```sql
SELECT
  CASE
    WHEN ratio >= 0.95 THEN '0.95-1.0'
    WHEN ratio >= 0.8 THEN '0.8-0.95'
    WHEN ratio >= 0.6 THEN '0.6-0.8'
    WHEN ratio >= 0.4 THEN '0.4-0.6'
    ELSE '<0.4'
  END as bucket_ratio,
  COUNT(*) as n_registros,
  COUNT(DISTINCT msisdn) as n_usuarios
FROM tabla
GROUP BY 1
ORDER BY 1;
```

---

**Próximo paso**: Ejecutar queries exploratorias de [02_QUERIES_ANALISIS.sql](02_QUERIES_ANALISIS.sql)
