# Guía de Comparación de Modelos

**Piecewise (03_MODELO.sql) vs Distribuciones (05_FUNCIONES_DISTRIBUCION_CORREGIDAS.sql)**

---

## 🎯 Objetivo

Comparar los dos enfoques del modelo probabilístico para decidir cuál usar:

1. **Modelo Piecewise** - Funciones por tramos, control fino por segmento
2. **Modelo con Distribuciones** - Gamma, Beta, Poisson con fundamento estadístico

---

## 🚀 Cómo Ejecutar la Comparación

### Paso 1: Prerequisitos (5 min)

```sql
-- 1. Ejecutar modelo piecewise
-- Archivo: sql/03_MODELO.sql
-- Crea funciones: calcular_prob_visita()

-- 2. Ejecutar modelo con distribuciones
-- Archivo: sql/05_FUNCIONES_DISTRIBUCION_CORREGIDAS.sql
-- Crea funciones: calcular_prob_visita_con_dist()
```

### Paso 2: Ejecutar Comparación (10 min)

```sql
-- Ejecutar TODO el archivo:
-- sql/06_COMPARACION_MODELOS.sql

-- Este script:
-- ✓ Crea tabla USUARIOS_AGREGADOS
-- ✓ Aplica ambos modelos
-- ✓ Genera 7 análisis comparativos
-- ✓ Da recomendación automática
```

### Paso 3: Revisar Resultados

Ver las 7 secciones de análisis que genera el script.

---

## 📊 Interpretación de Resultados

### 3.1. Resumen General

**Qué muestra**:
```
Total usuarios evaluados: X
Usuarios válidos (>=0.15) - PIECEWISE: Y
Usuarios válidos (>=0.15) - DISTRIBUCIONES: Z
Diferencia absoluta: |Y - Z|
Diferencia relativa (%): 100 * |Y - Z| / Y
```

**Cómo interpretar**:
- ✅ **Diferencia < 5%**: Modelos muy similares
- ⚠️ **Diferencia 5-15%**: Diferencia moderada, analizar más
- ❌ **Diferencia > 15%**: Diferencia significativa, validar con datos reales

**Ejemplo**:
```
Total usuarios: 1,500,000
Válidos PIECEWISE: 800,000
Válidos DISTRIBUCIONES: 850,000
Diferencia: 50,000 (6.25%)
→ DIFERENCIA MODERADA, analizar distribución por clasificación
```

---

### 3.2. Distribución por Clasificación

**Qué muestra**:

Dos tablas (una por modelo) con:
- Clasificación (VISITA_MUY_PROBABLE, VISITA_PROBABLE, etc.)
- Número de usuarios
- Porcentaje
- Probabilidad promedio

**Cómo interpretar**:

Comparar las distribuciones:

| Clasificación | Piecewise | Distribuciones | Diferencia |
|---------------|-----------|----------------|------------|
| MUY_PROBABLE | 30% | 25% | -5pp ⚠️ |
| PROBABLE | 20% | 25% | +5pp |
| POSIBLE | 15% | 20% | +5pp |
| DUDOSO | 10% | 10% | 0pp ✅ |
| DESCARTADO | 25% | 20% | -5pp |

**Señales**:
- ✅ **Distribuciones similares**: Ambos modelos clasifican parecido
- ⚠️ **PIECEWISE más conservador**: Más usuarios en MUY_PROBABLE/PROBABLE
- ⚠️ **DISTRIBUCIONES más generoso**: Más usuarios recuperados pero menor calidad
- ❌ **Distribuciones opuestas**: Revisar parámetros, posible error

---

### 3.3. Matriz de Confusión

**Qué muestra**:

Concordancia entre modelos:

| Piecewise | Distribuciones | Usuarios | % |
|-----------|----------------|----------|---|
| VISITA_PROBABLE | VISITA_PROBABLE | 150K | 10% ✅ |
| VISITA_PROBABLE | VISITA_POSIBLE | 50K | 3.3% ⚠️ |
| DESCARTADO | DESCARTADO | 500K | 33% ✅ |
| DUDOSO | VISITA_PROBABLE | 20K | 1.3% ❌ |

**Cómo interpretar**:
- **Diagonal (acuerdo)**: Alto % es bueno
- **Celdas adyacentes**: Diferencias de 1 nivel son aceptables
- **Celdas lejanas**: Diferencias de 2+ niveles → revisar esos usuarios

**Umbral de concordancia**:
- ✅ **> 70% acuerdo exacto**: Excelente
- ✅ **60-70% acuerdo**: Bueno
- ⚠️ **50-60% acuerdo**: Aceptable, revisar discrepancias
- ❌ **< 50% acuerdo**: Problema, revisar parámetros

---

### 3.4. Correlación y Estadísticas

**Qué muestra**:
```
correlacion: 0.85
prob_piecewise_promedio: 0.12
prob_distribucion_promedio: 0.13
diferencia_promedio_abs: 0.03
diferencia_maxima: 0.25
```

**Cómo interpretar**:

**Correlación**:
- ✅ **> 0.9**: Modelos muy correlacionados
- ✅ **0.8-0.9**: Buena correlación
- ⚠️ **0.6-0.8**: Correlación moderada
- ❌ **< 0.6**: Baja correlación, modelos muy diferentes

**Diferencia promedio absoluta**:
- ✅ **< 0.05**: Excelente
- ✅ **0.05-0.10**: Bueno
- ⚠️ **0.10-0.15**: Moderado
- ❌ **> 0.15**: Alto

**Diferencia máxima**:
- ✅ **< 0.20**: Normal (algunos outliers)
- ⚠️ **0.20-0.40**: Revisar casos extremos
- ❌ **> 0.40**: Revisar parámetros

---

### 3.5. Usuarios con Mayor Discrepancia

**Qué muestra**:

Top 20 usuarios donde los modelos más difieren.

**Cómo interpretar**:

Buscar patrones en las discrepancias:

**Patrón 1**: Ratio alto + ALTA_FREC
```
tiempo_ok: 60 min
dias: 10
ratio: 0.85
stddev: 2.5h

Piecewise: 0.08 (VISITA_POSIBLE)
Distribuciones: 0.18 (VISITA_PROBABLE)

→ DISTRIBUCIONES más generoso con alta frecuencia
→ Revisar si son trabajadores o visitantes frecuentes
```

**Patrón 2**: Tiempo muy corto
```
tiempo_ok: 20 min
dias: 1
ratio: 1.0
stddev: NULL

Piecewise: 0.15 (VISITA_PROBABLE)
Distribuciones: 0.05 (DUDOSO)

→ PIECEWISE más flexible con tiempos cortos
→ Distribución Gamma penaliza fuerte <30 min
```

**Patrón 3**: Ratio medio + patrón variable
```
tiempo_ok: 60 min
dias: 3
ratio: 0.65
stddev: 4.5h

Piecewise: 0.12 (VISITA_POSIBLE)
Distribuciones: 0.08 (VISITA_POSIBLE)

→ Ambos clasifican igual pero con diferente confianza
→ Aceptable
```

**Acción**:
- Si hay patrones claros → ajustar parámetros del modelo que falla
- Si son casos aislados → validar manualmente 10-20 usuarios
- Si no hay patrón → diferencia es ruido, ambos modelos OK

---

### 3.6. Análisis por Segmentos

**Qué muestra**:

Comparación por:
1. Tipo de frecuencia (BAJA/MEDIA/ALTA)
2. Bucket de ratio (alto/bueno/medio/bajo)

**Cómo interpretar**:

#### Por Frecuencia

| Tipo | Piecewise | Distribuciones | Diferencia |
|------|-----------|----------------|------------|
| BAJA_FREC | 0.15 | 0.14 | -0.01 ✅ |
| MEDIA_FREC | 0.12 | 0.13 | +0.01 ✅ |
| ALTA_FREC | 0.08 | 0.06 | -0.02 ⚠️ |

**Señal**: DISTRIBUCIONES penaliza más ALTA_FREC (Poisson con λ=2.5)
**Acción**: Si es correcto, OK. Si recuperas pocos ALTA_FREC válidos, ajustar λ

#### Por Ratio

| Bucket | Piecewise | Distribuciones | Diferencia |
|--------|-----------|----------------|------------|
| Ratio alto (≥0.9) | 0.18 | 0.16 | -0.02 ✅ |
| Ratio bueno (0.8-0.9) | 0.14 | 0.12 | -0.02 ✅ |
| Ratio medio (0.6-0.8) | 0.09 | 0.07 | -0.02 ⚠️ |
| Ratio bajo (<0.6) | 0.04 | 0.03 | -0.01 ✅ |

**Señal**: DISTRIBUCIONES más conservador en todos los segmentos
**Acción**: Revisar parámetros de Beta bimodal (α=0.5, β=2)

---

### 3.7. Casos de Prueba Específicos

**Qué muestra**:

Probabilidad promedio de ambos modelos para 3 casos tipo:

1. **Visitante típico** (45 min, 2 días, ratio 0.9)
   - Esperado: prob alta (>0.12) en ambos
   
2. **Trabajador típico** (480 min, 20 días, ratio 0.45, stddev<1)
   - Esperado: prob baja (<0.05) en ambos
   
3. **Visitante ratio medio** (60 min, 1 día, ratio 0.7)
   - Esperado: prob media (0.08-0.12) en ambos

**Cómo interpretar**:

```
Caso: Visitante típico
Piecewise: 0.14
Distribuciones: 0.13
→ ✅ Ambos clasifican correctamente, similares
```

```
Caso: Trabajador típico
Piecewise: 0.03
Distribuciones: 0.08
→ ⚠️ DISTRIBUCIONES no penaliza suficiente
→ Revisar factor_patron_stddev()
```

```
Caso: Visitante ratio medio
Piecewise: 0.10
Distribuciones: 0.05
→ ⚠️ DISTRIBUCIONES muy estricto con ratio medio
→ Revisar Beta bimodal
```

---

## 🎯 Recomendación Automática

El script genera una recomendación basada en:

### Criterios

```sql
correlacion >= 0.9 AND pct_discrepancias < 10%
→ "Ambos muy similares, usar PIECEWISE (más simple)"

correlacion >= 0.8 AND pct_discrepancias < 20%
→ "Similares con diferencias, considerar HÍBRIDO"

correlacion < 0.8 OR pct_discrepancias >= 20%
→ "Difieren significativamente, validar con datos reales"
```

### Ejemplo

```
Recomendación: Similares con diferencias, considerar HÍBRIDO
Correlación: 0.87
Discrepancias grandes: 45,000
% Discrepancias: 12.5%
```

**Interpretación**:
- Modelos correlacionados pero con ~12% de casos discrepantes
- HÍBRIDO = usar lo mejor de cada uno:
  - PIECEWISE para control fino (ratio, frecuencia)
  - DISTRIBUCIONES para tiempo (Gamma) y validación estadística

---

## 🔧 Ajustes Según Resultados

### Caso 1: Distribuciones muy conservadoras

**Síntoma**: Recupera 20% menos usuarios que Piecewise

**Solución**:
```sql
-- Ajustar parámetros de Gamma (tiempo)
-- En prob_tiempo_gamma(), cambiar multiplicadores:
WHEN tiempo_ok_minutos < 15 THEN ... * 0.4  -- Era 0.3
WHEN tiempo_ok_minutos < 30 THEN ... * 0.7  -- Era 0.6

-- O ajustar shape/scale:
cdf_gamma_tiempo(15, 0.9, 45.0)  -- Era α=0.8, β=47
```

### Caso 2: Distribuciones muy generosas con ALTA_FREC

**Síntoma**: Recupera trabajadores (ALTA_FREC + ratio medio)

**Solución**:
```sql
-- Ajustar Poisson en prob_frecuencia_poisson():
WHEN dias_visita BETWEEN 5 AND 9 THEN 0.3  -- Era 0.4
WHEN dias_visita >= 10 THEN 0.05  -- Era 0.1
```

### Caso 3: Beta bimodal no captura bien el pico

**Síntoma**: Usuarios con ratio 1.0 tienen prob más baja de lo esperado

**Solución**:
```sql
-- Ajustar pesos en prob_ratio_bimodal():
(0.50 * CASE WHEN ratio >= 0.95 THEN 1.0 ELSE 0.0 END +  -- Era 0.42
 0.50 * pdf_beta_ratio(...))  -- Era 0.58
```

---

## ✅ Criterios de Decisión Final

### Usar PIECEWISE si:
- ✅ Correlación > 0.85
- ✅ Diferencia < 10%
- ✅ Simplicidad es prioridad
- ✅ Ajustes frecuentes necesarios
- ✅ Stakeholders prefieren explicaciones simples

### Usar DISTRIBUCIONES si:
- ✅ Quieres fundamento estadístico
- ✅ Necesitas extrapolar fuera de rangos
- ✅ Publicación científica
- ✅ Validación académica importante

### Usar HÍBRIDO si:
- ✅ Correlación 0.75-0.90
- ✅ Diferencias 10-20%
- ✅ Quieres lo mejor de ambos
- ✅ Flexibilidad + rigor

### Validar con Datos Reales si:
- ❌ Correlación < 0.75
- ❌ Diferencias > 20%
- ❌ Casos de prueba fallan
- ❌ Matrices de confusión muy diferentes

---

## 📝 Checklist de Comparación

### Pre-ejecución
- [ ] Ejecuté 03_MODELO.sql (Piecewise)
- [ ] Ejecuté 05_FUNCIONES_DISTRIBUCION_CORREGIDAS.sql (Distribuciones)
- [ ] Tengo acceso a tabla base de VOLVO
- [ ] BigQuery tiene permisos para crear tablas temporales

### Ejecución
- [ ] Ejecuté 06_COMPARACION_MODELOS.sql completo
- [ ] Sin errores en ninguna query
- [ ] Todas las 7 secciones de análisis generadas

### Análisis
- [ ] Revisé Resumen General (diferencia %)
- [ ] Revisé Distribución por Clasificación
- [ ] Revisé Matriz de Confusión
- [ ] Revisé Correlación (>=0.80?)
- [ ] Revisé Top Discrepancias (patrones?)
- [ ] Revisé Análisis por Segmentos
- [ ] Revisé Casos de Prueba (correctos?)

### Decisión
- [ ] Correlación > 0.85 → Usar Piecewise
- [ ] Correlación 0.75-0.90 + diferencias → Híbrido
- [ ] Correlación < 0.75 → Validar con datos reales
- [ ] Documenté decisión y razones

---

## 🚀 Próximos Pasos Según Decisión

### Si eliges PIECEWISE:
1. Usar funciones de `03_MODELO.sql`
2. Aplicar a tabla completa
3. Validar muestra de 100 usuarios
4. Producción

### Si eliges DISTRIBUCIONES:
1. Ajustar parámetros según comparación
2. Re-ejecutar 06_COMPARACION_MODELOS.sql
3. Validar que mejoraron las métricas
4. Aplicar a tabla completa
5. Producción

### Si eliges HÍBRIDO:
1. Crear `07_MODELO_HIBRIDO.sql` con:
   - Gamma para tiempo (de Distribuciones)
   - Piecewise para ratio y frecuencia
   - Factor patrón de Piecewise
2. Comparar Híbrido vs ambos originales
3. Producción

### Si necesitas validar con datos reales:
1. Exportar top 1000 usuarios de cada modelo
2. Cruzar con datos de ventas (si disponible)
3. Calcular precision/recall de cada modelo
4. Decidir basado en métricas reales

---

**Versión**: 1.0  
**Última actualización**: 2026-09-21  
**Autor**: Equipo de Analítica - Modelo de Visitas
