# Guía del Modelo Genérico Parametrizado

**Versión**: 4.0  
**Archivo**: `sql/03_MODELO_GENERICO.sql`

---

## 🎯 ¿Qué es?

Un **modelo único universal** que se adapta a cualquier tipo de POC mediante configuración de parámetros.

**No más**:
- ❌ Crear `03_MODELO_VOLVO.sql`, `03_MODELO_BK.sql`, `03_MODELO_MERCADONA.sql`...
- ❌ Duplicar funciones UDF
- ❌ Mantener múltiples versiones

**Ahora**:
- ✅ Un solo modelo
- ✅ Parámetros centralizados en tabla
- ✅ Agregar nuevos POCs = agregar filas a tabla

---

## 📊 Tabla de Configuración

Todos los parámetros están en:
```sql
CONFIG_MODELO_PARAMETRIZADA
```

### Parámetros por POC

| Categoría | Parámetros | Ejemplo |
|-----------|-----------|---------|
| **Identificación** | `tipo_poc`, `descripcion` | 'CONCESIONARIO' |
| **Horarios** | `hora_apertura`, `hora_cierre` | 10.0, 20.0 |
| **Tiempos visita** | `tiempo_min_valido`, `tiempo_max_valido`, `tiempo_optimo_min`, `tiempo_optimo_max` | 900s, 10800s, 1800s, 5400s |
| **Frecuencia** | `dias_minimo`, `dias_maximo` | 1, 9 |
| **Ratios** | `ratio_minimo`, `ratio_optimo` | 0.80, 0.90 |
| **Patrón** | `stddev_trabajador_max`, `stddev_visitante_min`, `dif_horas_trabajador_min`, `pct_fuera_horario_max` | 1.5h, 3.0h, 6.0h, 50% |
| **Umbrales** | `umbral_muy_probable`, `umbral_probable`, `umbral_posible`, `umbral_dudoso` | 0.20, 0.15, 0.10, 0.05 |
| **Pesos** | `peso_espacial`, `peso_temporal`, `peso_patron` | 1.0, 1.0, 1.0 |

---

## 🚀 Cómo Usar

### Caso 1: POC ya configurado

Si tu tipo de POC ya existe (CONCESIONARIO, SUPERMERCADO, RESTAURANTE, CENTRO_COMERCIAL, BANCO):

1. **Abrir** `sql/03_MODELO_GENERICO.sql`

2. **Cambiar línea 454**:
```sql
WHERE tipo_poc = 'TU_TIPO'
-- Ejemplo: WHERE tipo_poc = 'RESTAURANTE'
```

3. **Cambiar línea 515**:
```sql
WHERE v.poc = 'TU_CAMPAÑA'
-- Ejemplo: WHERE v.poc = 'FANTA_GAMING_JUN2026_CON_EXTERIOR'
```

4. **Ejecutar** todo el script

---

### Caso 2: Nuevo tipo de POC

Si necesitas un tipo nuevo (ej: GASOLINERA, FARMACIA, GYM):

#### Paso 1: Añadir configuración

En `sql/03_MODELO_GENERICO.sql`, **Parte 1**, agregar nuevo STRUCT:

```sql
-- Ejemplo: FARMACIAS
STRUCT(
  'FARMACIA' as tipo_poc,
  'Farmacias y parafarmacias' as descripcion,

  -- HORARIOS
  9.0 as hora_apertura,
  21.0 as hora_cierre,

  -- TIEMPOS DE VISITA (en segundos)
  300 as tiempo_min_valido,        -- 5 min
  3600 as tiempo_max_valido,       -- 1 hora
  600 as tiempo_optimo_min,        -- 10 min
  1800 as tiempo_optimo_max,       -- 30 min

  -- FRECUENCIA (días) - Rango válido
  1 as dias_minimo,
  11 as dias_maximo,

  -- RATIOS
  0.70 as ratio_minimo,
  0.90 as ratio_optimo,

  -- PATRÓN HORARIO
  1.3 as stddev_trabajador_max,
  3.0 as stddev_visitante_min,
  6.0 as dif_horas_trabajador_min,
  55.0 as pct_fuera_horario_max,

  -- UMBRALES DE CLASIFICACIÓN
  0.18 as umbral_muy_probable,
  0.12 as umbral_probable,
  0.08 as umbral_posible,
  0.04 as umbral_dudoso,

  -- PESOS
  1.0 as peso_espacial,
  1.0 as peso_temporal,
  0.95 as peso_patron,

  'Intermedio. Visitas cortas. Algunos vecinos frecuentes.' as notas
)
```

#### Paso 2: Aplicar

Seguir **Caso 1** con tu nuevo `tipo_poc`.

---

## 🔧 Ajuste de Parámetros

### ¿Cómo saber qué valores poner?

#### 1. **Horarios** (`hora_apertura`, `hora_cierre`)
- Consultar horario real del negocio
- Si 24h: `hora_apertura = 0.0`, `hora_cierre = 24.0`

#### 2. **Tiempos de visita** (en segundos)
```
tiempo_min_valido     → Mínimo razonable (takeaway = 5 min = 300s)
tiempo_optimo_min     → Inicio del rango típico
tiempo_optimo_max     → Fin del rango típico
tiempo_max_valido     → Máximo antes de sospechar trabajador
```

**Ejemplos**:
- **Banco**: 10 min - 40 min típico, máx 1h
- **Restaurante**: 20 min - 45 min típico, máx 90 min
- **Concesionario**: 30 min - 90 min típico, máx 3h

#### 3. **Frecuencia** (días) - Rango válido
```
dias_minimo  → Mínimo de días para ser visita válida (< esto = ruido)
dias_maximo  → Máximo de días antes de sospechar trabajador (> esto = trabajador)
```

**Lógica**:
- `dias_visita < dias_minimo` → Penalización (muy poco, podría ser ruido)
- `dias_visita = dias_minimo` → Óptimo (visitante ocasional ideal = 1.0)
- `dias_minimo < dias_visita ≤ dias_maximo` → Gradual descendente (1.0 → 0.3)
- `dias_visita > dias_maximo` → Fuerte penalización (probable trabajador = 0.1)

**Ejemplos**:
- **Supermercado**: 1, 14 (gente va varias veces/semana, > 14 días sospechoso)
- **Concesionario**: 1, 9 (comprar coche es ocasional, > 9 días muy raro)
- **Restaurante**: 1, 11 (comer fuera es frecuente, > 11 días sospechoso)
- **Gym**: 1, 19 (gente va muy seguido, pero > 19 días podría ser empleado)
- **Banco**: 1, 7 (ir al banco es poco frecuente, > 7 días extraño)

#### 4. **Ratios** (0.0 - 1.0)
```
ratio_minimo  → Mínimo aceptable de tiempo_ok / tiempo_total
ratio_optimo  → Ideal para visitante puro
```

**Regla general**:
- **Estricto** (concesionario, banco): 0.80, 0.90
- **Flexible** (supermercado, vecinos): 0.50, 0.80
- **Intermedio** (restaurante): 0.70, 0.85

#### 5. **Patrón horario**
```
stddev_trabajador_max     → ¿Cuánta variabilidad horaria tiene un trabajador? (bajo)
stddev_visitante_min      → ¿Cuánta variabilidad tiene un visitante? (alto)
dif_horas_trabajador_min  → ¿Cuántas horas promedio trabajan?
pct_fuera_horario_max     → ¿Qué % de días fuera de horario es sospechoso?
```

**Valores típicos**:
- **Trabajador típico**: stddev < 1.5h, dif_horas > 6h
- **Visitante típico**: stddev > 3h, dif_horas < 5h
- **Fuera de horario**: > 50% es sospechoso

#### 6. **Umbrales de clasificación**

Usar `sql/07_ANALISIS_UMBRALES.sql` para encontrar los óptimos:
1. Ejecutar modelo con umbrales iniciales (copiar de tipo similar)
2. Ejecutar análisis de umbrales
3. Ajustar según distribución observada

**Umbrales iniciales sugeridos**:
- **Estricto** (concesionario, banco): 0.20, 0.15, 0.10, 0.05
- **Flexible** (supermercado): 0.18, 0.12, 0.08, 0.04
- **Intermedio** (restaurante): 0.18, 0.12, 0.08, 0.04

#### 7. **Pesos** (ajuste fino)

Valores por defecto: `1.0, 1.0, 1.0`

Ajustar si:
- **Vecinos frecuentes** (supermercado): `peso_patron = 0.9` (menos peso al patrón)
- **Prob espacial poco confiable**: `peso_espacial = 0.8`
- **Visitas muy cortas**: `peso_temporal = 1.1`

---

## 📋 Ejemplos Completos

### Ejemplo 1: Volvo (ya configurado)

```sql
-- Línea 454
WHERE tipo_poc = 'CONCESIONARIO'

-- Línea 515
WHERE v.poc = 'VOLVO_XC40-AON_ABR2026_4'
```

### Ejemplo 2: Burger King (ya configurado)

```sql
-- Línea 454
WHERE tipo_poc = 'RESTAURANTE'

-- Línea 515
WHERE v.poc = 'FANTA_GAMING_JUN2026_CON_EXTERIOR'
```

### Ejemplo 3: Mercadona (ya configurado)

```sql
-- Línea 454
WHERE tipo_poc = 'SUPERMERCADO'

-- Línea 515
WHERE v.poc = 'MERCADONA_MAYO2026_PROMO'
```

---

## 🔍 Validación

Después de ejecutar el modelo:

### 1. Query A - Distribución de clasificaciones
```sql
SELECT clasificacion_final, COUNT(*)
FROM VISITAS_CLASIFICADAS_GEN
GROUP BY clasificacion_final;
```

**Esperado**:
- VISITA_MUY_PROBABLE: 5-15% del total
- VISITA_PROBABLE: 5-10%
- DESCARTADO: 60-80%

### 2. Query B - Comparación con filtro actual
```sql
-- Ya incluida en el modelo
-- Compara usuarios recuperados vs filtro actual
```

### 3. Análisis de umbrales
```sql
-- Ejecutar sql/07_ANALISIS_UMBRALES.sql
-- Ajustar umbrales en CONFIG_MODELO_PARAMETRIZADA si es necesario
```

---

## ⚙️ Troubleshooting

### Problema 1: Demasiados usuarios MUY_PROBABLE

**Causa**: Umbrales muy bajos o parámetros muy permisivos

**Solución**:
1. Revisar Query A - características promedio de MUY_PROBABLE
2. Si ratio_promedio < 0.8 o dias_promedio > 5 → ajustar parámetros:
   - Aumentar `ratio_minimo`
   - Disminuir `dias_trabajador_min`
   - Aumentar umbrales de clasificación

### Problema 2: Muy pocos usuarios recuperados

**Causa**: Umbrales muy altos o parámetros muy estrictos

**Solución**:
1. Ejecutar `07_ANALISIS_UMBRALES.sql`
2. Ver Query 3 - curva de usuarios por umbral
3. Ajustar umbrales para target deseado

### Problema 3: Trabajadores clasificados como visitantes

**Causa**: Parámetros de patrón muy permisivos

**Solución**:
1. Revisar Query A - stddev_promedio de MUY_PROBABLE
2. Si stddev < 2.0 → ajustar:
   - Disminuir `stddev_trabajador_max` (ej: de 1.5 a 1.2)
   - Disminuir `dias_trabajador_min` (ej: de 10 a 8)
   - Aumentar `peso_patron` (ej: de 1.0 a 1.1)

### Problema 4: Visitantes clasificados como trabajadores

**Causa**: Parámetros de patrón muy estrictos

**Solución**:
1. Aumentar `stddev_trabajador_max` (ej: de 1.5 a 2.0)
2. Aumentar `dias_trabajador_min` (ej: de 10 a 12)
3. Disminuir `peso_patron` (ej: de 1.0 a 0.9)

---

## 🎓 Mejores Prácticas

### 1. **Empezar con un POC similar**
Si no sabes qué parámetros usar, copia de uno similar:
- GASOLINERA → copiar SUPERMERCADO
- CAFETERÍA → copiar RESTAURANTE
- LIBRERÍA → copiar BANCO

### 2. **Iterar**
1. Primera ejecución con parámetros de tipo similar
2. Validar con Query A
3. Ajustar parámetros
4. Re-ejecutar
5. Repetir hasta satisfacción

### 3. **Documentar decisiones**
En el campo `notas` de la configuración, explicar por qué elegiste esos parámetros.

### 4. **Validación manual**
Siempre revisar muestra de 20-50 usuarios MUY_PROBABLE manualmente antes de producción.

### 5. **A/B Testing**
Si tienes ground truth (ventas, validación manual):
- Ejecutar modelo con Configuración A
- Ejecutar modelo con Configuración B
- Comparar precision/recall
- Elegir mejor

---

## 📈 Escalabilidad

### 10 POCs diferentes
```sql
-- Solo 10 filas en CONFIG_MODELO_PARAMETRIZADA
-- Ejecutar el modelo 10 veces cambiando tipo_poc y poc
```

### 100 POCs diferentes
```sql
-- 100 filas en CONFIG_MODELO_PARAMETRIZADA
-- Script de loop para ejecutar automáticamente
```

### Procesamiento batch
```sql
-- Modificar Paso 2 del modelo para procesar múltiples POCs a la vez
-- GROUP BY tipo_poc en lugar de filtrar por uno solo
```

---

## 🔄 Actualización de Parámetros

### Opción 1: UPDATE directo
```sql
UPDATE `mo-advertising-sta.ADVERTISING_TEST.CONFIG_MODELO_PARAMETRIZADA`
SET dias_trabajador_min = 12,
    umbral_muy_probable = 0.18
WHERE tipo_poc = 'RESTAURANTE';
```

### Opción 2: Re-crear tabla completa
```sql
-- Ejecutar Parte 1 del modelo con todos los STRUCTs actualizados
```

---

## 📚 Archivos Relacionados

- **Modelo**: `sql/03_MODELO_GENERICO.sql`
- **Análisis umbrales**: `sql/07_ANALISIS_UMBRALES.sql` (adaptar nombre POC)
- **Documentación variables**: `docs/01_VARIABLES.md`
- **Guía comparación**: `docs/06_GUIA_COMPARACION.md`

---

**Versión**: 1.0  
**Última actualización**: 2026-09-23  
**Autor**: Equipo de Analítica - Modelo de Visitas
