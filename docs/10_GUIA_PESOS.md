# Guía de Pesos del Modelo

**Versión**: 1.0  
**Fecha**: 2026-10-02

---

## 🎯 ¿Qué son los pesos?

Los pesos controlan la **importancia relativa** de cada componente del modelo probabilístico:

```sql
prob_final = POWER(prob_espacial, peso_espacial) *
             POWER(componente_temporal, peso_temporal) *
             POWER(componente_patron, peso_patron)
```

---

## 📊 Cómo funcionan los pesos

### Matemática

`POWER(valor, peso)` eleva el valor a la potencia del peso:

| Valor | Peso | Resultado | Efecto |
|-------|------|-----------|--------|
| 0.4 | 1.0 | 0.40 | Sin cambio |
| 0.4 | 0.5 | 0.63 | **Suaviza** (eleva valores bajos) |
| 0.4 | 0.3 | 0.74 | Suaviza mucho |
| 0.4 | 1.5 | 0.25 | **Acentúa** (penaliza más) |
| 0.8 | 0.5 | 0.89 | Cambio menor en valores altos |
| 0.8 | 1.5 | 0.72 | Penaliza valores medios |

### Reglas generales

- **peso < 1.0**: Suaviza (reduce impacto negativo de valores bajos)
- **peso = 1.0**: Sin cambio (multiplicación normal)
- **peso > 1.0**: Acentúa (penaliza más valores mediocres)

---

## 🔧 Pesos por componente

### **peso_espacial**

Controla la influencia de `prob_espacial` (distancia celda-POC).

**Problema que resuelve**:  
Si `prob_espacial = 0.3` (celda algo lejos), con peso 1.0 mata toda la probabilidad:
```
0.3 * 1.0 * 1.0 * 1.0 = 0.30
```

Con `peso_espacial = 0.5`:
```
POWER(0.3, 0.5) * 1.0 * 1.0 * 1.0 = 0.55 * 1.0 * 1.0 * 1.0 = 0.55
```

**Cuándo ajustar**:
- **Bajar (0.3-0.5)**: Cuando prob_espacial es poco fiable o hay vecinos frecuentes
- **Mantener (1.0)**: Cuando la proximidad espacial es crítica
- **Subir (1.2-1.5)**: Cuando solo quieres usuarios MUY cercanos

**Valores recomendados por POC**:
- CONCESIONARIO: `0.5` (nadie vive al lado, distancia menos crítica)
- SUPERMERCADO: `0.5` (muchos vecinos, distancia menos relevante)
- BANCO: `0.5` (visitas planificadas, distancia menos crítica)

---

### **peso_temporal**

Controla la influencia del componente temporal (tiempo + ratio + factor_dia).

**Problema que resuelve**:  
El componente temporal ya es bastante estricto. Peso = 1.0 está bien normalmente.

**Cuándo ajustar**:
- **Bajar (0.8-0.9)**: Cuando quieres ser más permisivo con tiempos atípicos
- **Mantener (1.0)**: Caso general (RECOMENDADO)
- **Subir (1.1-1.3)**: Cuando el tiempo es el factor más importante

**Valores recomendados**:
- Todos los POC: `1.0` (mantener importancia normal)

---

### **peso_patron**

Controla la influencia del patrón agregado (frecuencia + stddev + % fuera horario).

**Problema que resuelve**:  
En POCs con vecinos frecuentes, el patrón puede ser demasiado estricto.

**Cuándo ajustar**:
- **Bajar (0.8-0.9)**: Vecinos frecuentes, alta rotación normal
- **Mantener (1.0)**: Cuando el patrón es muy confiable
- **Subir (1.1-1.2)**: Cuando quieres ser MUY estricto con trabajadores

**Valores recomendados por POC**:
- CONCESIONARIO: `1.0` (patrón muy importante)
- SUPERMERCADO: `0.9` (vecinos frecuentes, patrón menos relevante)
- RESTAURANTE: `0.95` (intermedio)
- BANCO: `1.0` (patrón muy importante)

---

## 📋 Configuración actual

```sql
-- CONCESIONARIO (estricto, sin vecinos)
peso_espacial = 0.5   -- Suaviza prob_espacial
peso_temporal = 1.0   -- Normal
peso_patron = 1.0     -- Normal

-- SUPERMERCADO (flexible, muchos vecinos)
peso_espacial = 0.5   -- Suaviza prob_espacial
peso_temporal = 1.0   -- Normal
peso_patron = 0.9     -- Reduce ligeramente patrón

-- RESTAURANTE (intermedio)
peso_espacial = 0.5
peso_temporal = 1.0
peso_patron = 0.95

-- CENTRO_COMERCIAL (flexible)
peso_espacial = 0.5
peso_temporal = 1.0
peso_patron = 0.95

-- BANCO (estricto)
peso_espacial = 0.5
peso_temporal = 1.0
peso_patron = 1.0
```

---

## 🧪 Cómo ajustar pesos

### Paso 1: Identificar el problema

Ejecuta el modelo y analiza componentes:

```sql
SELECT
  clasificacion_final,
  COUNT(*) as n_usuarios,
  ROUND(AVG(prob_espacial), 3) as avg_prob_espacial,
  ROUND(AVG(prob_temporal_dia), 3) as avg_prob_temporal,
  ROUND(AVG(factor_patron_agregado), 3) as avg_factor_patron,
  ROUND(AVG(prob_visita_dia), 3) as avg_prob_final
FROM VISITAS_CON_PROBABILIDAD_GEN_DIA
GROUP BY clasificacion_final;
```

**Diagnósticos**:
- `avg_prob_espacial` muy bajo (< 0.5) y usuarios se descartan → **bajar peso_espacial**
- `avg_factor_patron` muy bajo (< 0.3) y usuarios se descartan → **bajar peso_patron**
- Muchos MUY_PROBABLE (inflación) → **subir algún peso**

### Paso 2: Actualizar CONFIG_MODELO_PARAMETRIZADA

```sql
UPDATE `mo-advertising-sta.ADVERTISING_TEST.CONFIG_MODELO_PARAMETRIZADA`
SET 
  peso_espacial = 0.3,  -- Cambiar según necesidad
  peso_temporal = 1.0,
  peso_patron = 0.8
WHERE tipo_poc = 'CONCESIONARIO';
```

### Paso 3: Re-ejecutar modelo

Ejecuta el modelo completo de nuevo y compara resultados.

---

## 💡 Ejemplos prácticos

### Ejemplo 1: Prob_espacial mata todo

**Problema**:
```
Usuario perfecto en patrón pero:
prob_espacial = 0.35
prob_temporal = 0.95
factor_patron = 0.90

Con peso_espacial = 1.0:
prob_final = 0.35 * 0.95 * 0.90 = 0.30 → PROBABLE
```

**Solución**: Bajar peso_espacial a 0.5
```
prob_final = POWER(0.35, 0.5) * 0.95 * 0.90 = 0.59 * 0.95 * 0.90 = 0.50 → MUY_PROBABLE
```

### Ejemplo 2: Muchos usuarios MUY_PROBABLE

**Problema**: Salen 155K usuarios MUY_PROBABLE, deberían ser 79K.

**Diagnóstico**:
```sql
-- Ver distribución de componentes en MUY_PROBABLE
SELECT
  APPROX_QUANTILES(prob_espacial, 10) as p_espacial,
  APPROX_QUANTILES(factor_patron, 10) as p_patron
FROM VISITAS_CON_PROBABILIDAD_GEN_DIA
WHERE clasificacion_final = 'VISITA_MUY_PROBABLE';
```

Si `p_patron` es bajo (mayoría < 0.5) → trabajadores se cuelan.

**Solución**: Subir peso_patron a 1.2
```
POWER(0.4, 1.2) = 0.33  (en vez de 0.4)
→ Penaliza más patrones sospechosos
```

---

## ⚠️ Precauciones

1. **No cambiar todos a la vez**: Ajusta uno, evalúa, luego ajusta otro.

2. **Rangos recomendados**:
   - peso_espacial: `0.3 - 0.8`
   - peso_temporal: `0.9 - 1.1`
   - peso_patron: `0.8 - 1.2`

3. **Valores extremos** (< 0.3 o > 1.5) pueden causar comportamientos inesperados.

4. **Documentar cambios**: Anota por qué cambiaste un peso en campo `notas`.

---

## 🔄 Workflow recomendado

```
1. Ejecutar modelo con pesos por defecto
2. Analizar distribución de componentes
3. Identificar componente problemático
4. Ajustar UN peso (±0.1 o ±0.2)
5. Re-ejecutar
6. Comparar resultados
7. Iterar si necesario
```

---

**Última actualización**: 2026-10-02  
**Autor**: Equipo de Analítica - Modelo de Visitas
