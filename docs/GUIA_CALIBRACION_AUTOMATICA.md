# 🎯 Guía de Calibración Automática de Parámetros

## 📋 Resumen Ejecutivo

**Problema**: Tener que ajustar manualmente 20+ parámetros por cada tipo de POC es tedioso y propenso a errores.

**Solución**: 5 estrategias para configurar parámetros automáticamente, desde lo más simple hasta lo más sofisticado.

---

## 🚀 Estrategias de Calibración

### **Nivel 1: Percentiles (RECOMENDADO PARA EMPEZAR)**

**Complejidad**: ⭐ Baja  
**Tiempo implementación**: 30 minutos  
**Requiere**: Solo datos de visitas  
**Accuracy**: 70-80%

#### Cómo Funciona
```sql
-- Calcular percentiles de tiempo
tiempo_min_valido = percentil_05
tiempo_optimo_min = percentil_25
tiempo_optimo_max = percentil_75
tiempo_max_valido = percentil_95
```

#### Ventajas
✅ Rápido, interpretable  
✅ No requiere etiquetas  
✅ Funciona bien para distribuciones razonables  
✅ Implementable 100% en BigQuery

#### Desventajas
❌ Sensible a outliers  
❌ No distingue automáticamente trabajadores de visitantes  
❌ Asume que p95 = trabajadores (puede no ser cierto)

#### Cuándo Usar
- Primera vez que calibras un POC nuevo
- No tienes tiempo para análisis profundo
- Datos relativamente limpios

#### Código
```sql
-- Ver 05_CALIBRACION_AUTOMATICA.sql
-- Sección: ESTRATEGIA 1
```

---

### **Nivel 2: Ajuste de Distribuciones**

**Complejidad**: ⭐⭐ Media  
**Tiempo implementación**: 2-3 horas  
**Requiere**: Python/R + conocimientos estadística  
**Accuracy**: 75-85%

#### Cómo Funciona

1. **Analizar distribución** de tiempos/frecuencias
2. **Ajustar distribución conocida** (Normal, Log-Normal, Gamma, etc.)
3. **Test de bondad de ajuste** (Kolmogorov-Smirnov, Chi-cuadrado)
4. **Derivar parámetros** de la distribución ajustada

```python
# Ejemplo: Si tiempo ~ LogNormal(μ=7.5, σ=0.8)
params = lognorm.fit(tiempos)
p05 = lognorm.ppf(0.05, *params)  # Percentil 5%
p95 = lognorm.ppf(0.95, *params)  # Percentil 95%
```

#### Ventajas
✅ Más robusto que percentiles empíricos  
✅ Suaviza outliers  
✅ Fundamento estadístico sólido  
✅ Funciona mejor con datos ruidosos

#### Desventajas
❌ Requiere Python/R (BigQuery no tiene fitting nativo)  
❌ Asume que datos siguen distribución conocida  
❌ Más complejo de explicar al negocio

#### Cuándo Usar
- Tienes datos con outliers extremos
- Tus datos siguen distribución asimétrica (tiempo suele ser log-normal)
- Quieres parámetros más "suaves" y estables

#### Distribuciones Comunes en Tiempos de Visita

| Distribución | Cuándo Aparece | Parámetros Típicos |
|--------------|----------------|-------------------|
| **Log-Normal** | Tiempos de visita (la más común) | μ=7.5, σ=0.8 → mediana ~30min |
| **Gamma** | Tiempos con mínimo fijo | shape=2.5, scale=600 |
| **Exponencial** | Llegadas aleatorias (poco común) | λ=1/1800 → media 30min |
| **Normal** | Muy raro en tiempos (no puede ser <0) | Solo si muy simétrico |

#### Código
```python
# Ver notebooks/analisis_distribuciones.py
# Clase: AnalizadorDistribuciones
```

---

### **Nivel 3: Clustering Automático**

**Complejidad**: ⭐⭐⭐ Alta  
**Tiempo implementación**: 1-2 días  
**Requiere**: BigQuery ML o Python + sklearn  
**Accuracy**: 80-90% (si clusters son buenos)

#### Cómo Funciona

1. **Extraer features** de cada POC (tiempo promedio, frecuencia, stddev_hora, etc.)
2. **Normalizar features** (z-score)
3. **Aplicar K-Means** (probar k=3,4,5)
4. **Interpretar clusters** (ej: cluster 1 = "Alto riesgo trabajadores")
5. **Asignar parámetros** por cluster

```python
# Features por POC
features = df.groupby('poc').agg({
    'tiempo_promedio': 'mean',
    'dias_visita': 'mean',
    'stddev_hora_minima': 'mean',
    'dif_horas': 'mean'
})

# K-Means
kmeans = KMeans(n_clusters=3)
clusters = kmeans.fit_predict(features)

# Interpretación
# Cluster 0: tiempo_alto, dias_bajo → COMPRA_PLANIFICADA
# Cluster 1: tiempo_bajo, dias_alto, stddev_bajo → ALTO_RIESGO_TRABAJADORES
# Cluster 2: tiempo_medio, dias_medio → COMPRA_RUTINARIA
```

#### Ventajas
✅ Descubre tipos de POC que no habías pensado  
✅ No necesitas clasificar POCs a mano  
✅ Escala a 100+ POCs  
✅ Reduce perfiles base de 5 a 3-4 automáticamente

#### Desventajas
❌ Requiere interpretar clusters (no es automático)  
❌ Necesita suficientes POCs diferentes (mínimo 10-15)  
❌ Sensible a elección de k (número de clusters)  
❌ Requiere BigQuery ML o pipeline externo

#### Cuándo Usar
- Tienes 10+ tipos de POC diferentes
- No estás seguro de cómo agruparlos
- Quieres validar tus 3 perfiles base actuales
- Aparecen POCs nuevos frecuentemente

#### Métricas para Elegir k Óptimo

```python
# Método del codo (Elbow)
inertias = []
for k in range(2, 10):
    kmeans = KMeans(n_clusters=k)
    kmeans.fit(features)
    inertias.append(kmeans.inertia_)

# Buscar "codo" en la curva

# Silhouette Score (mejor métrica)
from sklearn.metrics import silhouette_score
for k in range(2, 10):
    kmeans = KMeans(n_clusters=k)
    labels = kmeans.fit_predict(features)
    score = silhouette_score(features, labels)
    print(f'k={k}, silhouette={score:.3f}')

# k con mejor silhouette score es el óptimo
```

#### Código
```sql
-- Ver 05_CALIBRACION_AUTOMATICA.sql
-- Sección: ESTRATEGIA 3 (requiere BigQuery ML)
```

---

### **Nivel 4: Optimización de Pesos**

**Complejidad**: ⭐⭐⭐⭐ Muy Alta  
**Tiempo implementación**: 3-5 días  
**Requiere**: Ground truth O métrica proxy + Python/R  
**Accuracy**: 85-95% (con ground truth)

#### Cómo Funciona

1. **Definir función objetivo** (ej: maximizar accuracy con ground truth)
2. **Grid search** o **Optimización Bayesiana** sobre pesos
3. **Validar** en conjunto de test
4. **Desplegar** mejores pesos

#### Opción A: Con Ground Truth (IDEAL)

```python
# Tienes 100-500 usuarios etiquetados manualmente
ground_truth = [True, False, True, ...]  # es_visita_real

# Función objetivo: maximizar F1-score
def objetivo(pesos):
    prob_final = calcular_prob(pesos)
    predicciones = prob_final >= umbral
    f1 = f1_score(ground_truth, predicciones)
    return -f1  # Negativo porque minimize busca mínimo

# Optimizar
from scipy.optimize import minimize
resultado = minimize(objetivo, x0=[0.33, 0.33, 0.34], 
                      bounds=[(0.1, 0.6)]*3)
```

#### Opción B: Sin Ground Truth (Proxy Metric)

```python
# Métricas proxy (no requieren etiquetas):

# 1. Maximizar separación entre clases
def objetivo(pesos):
    prob = calcular_prob(pesos)
    prob_altas = prob[prob >= 0.12]
    prob_bajas = prob[prob < 0.12]
    # Queremos mucha diferencia entre grupos
    return -abs(prob_altas.mean() - prob_bajas.mean())

# 2. Minimizar "zona gris" (probabilities entre 0.08-0.15)
def objetivo(pesos):
    prob = calcular_prob(pesos)
    zona_gris = ((prob >= 0.08) & (prob <= 0.15)).sum()
    return zona_gris  # Minimizar

# 3. Maximizar correlación con "certeza" (prob extremas)
def objetivo(pesos):
    prob = calcular_prob(pesos)
    # Queremos muchas prob cercanas a 0 o 1, pocas en 0.5
    return -prob.var()  # Maximizar varianza
```

#### Grid Search vs Optimización Bayesiana

| Método | Velocidad | Garantía Óptimo Global | Cuando Usar |
|--------|-----------|------------------------|-------------|
| **Grid Search** | Lento (horas) | ✅ Sí | ≤3 parámetros, pocos POCs |
| **Optimización Bayesiana** | Rápido (minutos) | ❌ No (local) | >3 parámetros, muchos POCs |
| **Nelder-Mead** | Muy rápido (segundos) | ❌ No | Exploración inicial |

#### Ventajas
✅ Óptimo matemáticamente probado  
✅ Máxima accuracy posible  
✅ Puede descubrir combinaciones contra-intuitivas

#### Desventajas
❌ Requiere ground truth o proxy metric confiable  
❌ Muy lento (grid search)  
❌ Puede overfittear a conjunto de entrenamiento  
❌ Difícil explicar por qué pesos óptimos son lo que son

#### Cuándo Usar
- Tienes ground truth (aunque sea 100-200 usuarios)
- Quieres "exprimir" el último 5-10% de accuracy
- Tienes tiempo para iterar
- El modelo está en producción y quieres mejora continua

#### Código
```python
# Ver notebooks/analisis_distribuciones.py
# Clase: OptimizadorPesos
```

---

### **Nivel 5: Híbrido (RECOMENDADO PRODUCCIÓN)**

**Complejidad**: ⭐⭐ Media  
**Tiempo implementación**: 1 semana  
**Requiere**: Datos + algunas reglas de negocio  
**Accuracy**: 80-90%

#### Cómo Funciona

1. **Parámetros base**: calcular automáticamente (percentiles o distribuciones)
2. **Overrides manuales**: aplicar conocimiento del negocio donde aplique
3. **Optimización selectiva**: optimizar solo parámetros críticos (pesos)

```sql
-- Parámetros automáticos
tiempo_optimo_min = percentil_25_automatico

-- Override manual si POC especial
tiempo_optimo_min = CASE 
  WHEN poc LIKE '%BANCO%' THEN 900   -- Bancos: mínimo 15 min (sabemos esto)
  WHEN poc LIKE '%24H%' THEN percentil_10_automatico  -- 24h: más permisivo
  ELSE percentil_25_automatico  -- Default automático
END
```

#### Ventajas
✅ Combina lo mejor de ambos mundos  
✅ Automático donde tiene sentido, manual donde importa  
✅ Flexible y escalable  
✅ Fácil auditar y explicar

#### Desventajas
❌ Requiere mantener lista de overrides  
❌ Algo de trabajo manual

#### Cuándo Usar
- **SIEMPRE en producción**
- Tienes algunos POCs con requisitos especiales
- Balance entre automatización y control

---

## 📊 Análisis de Distribuciones - Deep Dive

### ¿Por qué importa la distribución?

**TL;DR**: Si usas percentiles empíricos de una distribución log-normal, el percentil 95 será MUY sensible a outliers. Si ajustas una log-normal y usas sus percentiles teóricos, serán más estables.

### Caso Real: Tiempo de Visita en Supermercado

```python
# Datos reales (ejemplo)
tiempos = [600, 720, 900, 1200, 1500, 1800, 2400, 3600, 28800]  # último es outlier
#         10min 12  15  20   25   30   40   60   8 HORAS (trabajador?)

# Percentil empírico 95:
p95_empirico = np.percentile(tiempos, 95)  # 13680 segundos (3.8 horas)
# ❌ Influenciado por outlier único

# Ajustar log-normal y calcular p95 teórico:
params = lognorm.fit(tiempos)
p95_teorico = lognorm.ppf(0.95, *params)  # ~4200 segundos (70 min)
# ✅ Robusto a outlier, captura la "mayoría" de visitas
```

### Tests de Distribución - Interpretación

#### Skewness (Asimetría)

```
skewness > 1.0  → Muy asimétrica derecha (Log-Normal, Gamma)
skewness > 0.5  → Moderadamente asimétrica derecha
-0.5 < skewness < 0.5  → Simétrica (Normal)
skewness < -0.5 → Asimétrica izquierda (raro en tiempos)
```

**Ejemplo**: Si `skewness = 1.8` para tiempos de visita:
- ✅ Ajustar **Log-Normal** o **Gamma**
- ❌ NO usar **Normal** (mal ajuste)

#### Kurtosis (Colas Pesadas)

```
kurtosis > 3  → Colas pesadas (más outliers que Normal)
kurtosis ≈ 3  → Normal
kurtosis < 3  → Colas ligeras
```

**Ejemplo**: Si `kurtosis = 5.2`:
- Muchos outliers → considerar **winsorización** (recortar extremos)
- O usar distribución de colas pesadas (t-Student, Cauchy)

#### Test Kolmogorov-Smirnov

```
H0: Los datos siguen la distribución especificada
p-value > 0.05  → No rechazamos H0 (buen ajuste ✅)
p-value < 0.05  → Rechazamos H0 (mal ajuste ❌)
```

**Ejemplo**: 
```
KS test vs Normal: p=0.003  ❌ (no es normal)
KS test vs Log-Normal: p=0.42  ✅ (buen ajuste)
```

---

## 🎓 Casos de Uso Reales

### Caso 1: Cafetería Nueva (sin datos históricos)

**Situación**: Acabas de añadir un POC de cafetería, 0 datos históricos.

**Solución**:
1. **Semana 1**: Usar parámetros de perfil base `COMPRA_RUTINARIA`
2. **Semana 2**: Ejecutar Estrategia 1 (Percentiles) con datos de semana 1
3. **Mes 1**: Ejecutar Estrategia 2 (Distribuciones) para refinar
4. **Trimestre 1**: Optimizar pesos si tienes ground truth

### Caso 2: Supermercado con Muchos Trabajadores

**Situación**: Sabes que hay ~30% de trabajadores (cajeros, reponedores).

**Solución**:
1. Ejecutar Modelo 2-Pass (elimina trabajadores en Pass 1)
2. Usar **Estrategia 1** sobre días válidos de Pass 1
3. Ajustar manualmente `dias_max_valido` hacia abajo si sigue habiendo trabajadores
4. Aumentar `peso_patron` a 0.50 (más énfasis en detectar patrones fijos)

### Caso 3: 20 POCs Nuevos de Golpe

**Situación**: Cliente nuevo con 20 tipos de POC diferentes.

**Solución**:
1. Ejecutar **Estrategia 3** (Clustering) sobre los 20 POCs
2. Clustering descubre 4 grupos:
   - Cluster A: Visitas largas, infrecuentes → `COMPRA_PLANIFICADA`
   - Cluster B: Visitas cortas, muy frecuentes → `CAFETERIA`
   - Cluster C: Visitas medianas, frecuentes → `COMPRA_RUTINARIA`
   - Cluster D: Visitas largas, frecuentes, stddev bajo → `ALTO_RIESGO_TRABAJADORES`
3. Asignar parámetros por cluster
4. Refinar individualmente los que sean especiales

### Caso 4: Modelo en Producción, Quieres Mejorarlo

**Situación**: Modelo lleva 3 meses en producción, tienes feedback de negocio.

**Solución**:
1. Recopilar **100-200 usuarios etiquetados** (visitantes reales vs falsos positivos)
2. Ejecutar **Estrategia 4** (Optimización) sobre pesos
3. **A/B test**: 50% tráfico con pesos antiguos, 50% con pesos nuevos
4. Comparar métricas de negocio (conversión, CTR, etc.)
5. Desplegar ganador

---

## ⚙️ Implementación Paso a Paso

### Setup Inicial (Solo la Primera Vez)

```sql
-- 1. Crear tablas de configuración
CREATE TABLE CONFIG_PERFILES_BASE ...
CREATE TABLE CONFIG_POC_V2 ...

-- 2. Poblar con perfiles base (manual)
INSERT INTO CONFIG_PERFILES_BASE VALUES (...)

-- 3. Configurar primer POC (manual)
INSERT INTO CONFIG_POC_V2 VALUES (...)
```

### Pipeline Automático (Para Cada POC Nuevo)

```sql
-- PASO 1: Calcular estadísticas base
CREATE OR REPLACE TABLE ESTADISTICAS_BASE_POC AS
SELECT ...  -- Ver 05_CALIBRACION_AUTOMATICA.sql

-- PASO 2: Derivar parámetros automáticamente
CREATE OR REPLACE TABLE PARAMETROS_AUTOMATICOS AS
SELECT ...

-- PASO 3: Validar parámetros
SELECT * FROM PARAMETROS_AUTOMATICOS;
-- ✅ Revisar que tiempo_min < tiempo_optimo < tiempo_max
-- ✅ Revisar que pesos suman 1.0

-- PASO 4: Insertar en CONFIG_POC_V2 (con posibles overrides)
INSERT INTO CONFIG_POC_V2
SELECT 
  tipo_poc,
  -- Asignar perfil base según características
  CASE 
    WHEN dias_p95 > 15 THEN 'COMPRA_RUTINARIA'
    WHEN tiempo_p50 > 3600 THEN 'COMPRA_PLANIFICADA'
    ELSE 'OCIO'
  END as perfil_base,
  -- Ajustes desde parámetros automáticos
  tiempo_optimo_min / perfil.tiempo_base as ajuste_tiempo,
  ...
FROM PARAMETROS_AUTOMATICOS;

-- PASO 5: Ejecutar modelo
-- Ver 04_MODELO_MEJORADO_V2.sql
```

### Workflow con Python (Análisis Distribuciones)

```bash
# 1. Extraer datos de BigQuery
python notebooks/analisis_distribuciones.py --poc SUPERMERCADO

# Output:
# - distribucion_tiempo_SUPERMERCADO.png
# - distribucion_frecuencia_SUPERMERCADO.png
# - config_SUPERMERCADO.json

# 2. Revisar gráficos (visual check)
# 3. Si distribución es clara (Log-Normal), usar parámetros teóricos
# 4. Si distribución es extraña, volver a percentiles empíricos

# 5. Subir config a BigQuery
bq load --source_format=NEWLINE_DELIMITED_JSON \
  ADVERTISING_TEST.CONFIG_POC_V2 \
  config_SUPERMERCADO.json
```

---

## 📈 Métricas de Éxito

### Cómo Saber si la Calibración Automática Funciona

#### Métricas Sin Ground Truth

1. **Consistencia entre POCs similares**
   ```sql
   -- POCs del mismo perfil deberían tener parámetros similares
   SELECT perfil_base, 
          AVG(tiempo_optimo_min), STDDEV(tiempo_optimo_min)
   FROM CONFIG_CALCULADA_V2
   GROUP BY perfil_base;
   
   -- STDDEV bajo = consistencia alta ✅
   ```

2. **Distribución de probabilidades**
   ```sql
   -- Queremos distribución bimodal (picos en 0.0-0.1 y 0.8-1.0)
   -- No queremos todo concentrado en 0.3-0.5 (indecisión)
   
   SELECT 
     CASE 
       WHEN prob_visita_final < 0.1 THEN '0.0-0.1'
       WHEN prob_visita_final < 0.3 THEN '0.1-0.3'
       WHEN prob_visita_final < 0.7 THEN '0.3-0.7'  -- Zona gris (malo)
       WHEN prob_visita_final < 0.9 THEN '0.7-0.9'
       ELSE '0.9-1.0'
     END as bucket,
     COUNT(*) as n_visitas
   FROM VISITAS_FINALES_V2
   GROUP BY bucket;
   
   -- Ideal: mucho en 0.0-0.1 y 0.9-1.0, poco en 0.3-0.7
   ```

3. **Estabilidad temporal**
   ```sql
   -- Calibrar parámetros en semana 1, aplicar en semana 2-4
   -- ¿Distribución de resultados similar?
   ```

#### Métricas Con Ground Truth

1. **Accuracy / Precision / Recall**
2. **F1-Score**
3. **AUC-ROC**
4. **Curva Precision-Recall**

```python
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score

y_true = ground_truth
y_pred = (prob_visita_final >= umbral).astype(int)

print(f"Accuracy:  {accuracy_score(y_true, y_pred):.3f}")
print(f"Precision: {precision_score(y_true, y_pred):.3f}")
print(f"Recall:    {recall_score(y_true, y_pred):.3f}")
print(f"F1:        {f1_score(y_true, y_pred):.3f}")
```

**Benchmarks esperados**:
- Accuracy > 0.80 → Bueno
- Accuracy > 0.85 → Muy bueno
- Accuracy > 0.90 → Excelente (difícil sin mucho tuning)

---

## 🔮 Roadmap de Implementación

### Semana 1: Quick Win
- [ ] Ejecutar Estrategia 1 (Percentiles) en 2-3 POCs piloto
- [ ] Comparar con parámetros manuales actuales
- [ ] Validar que parámetros auto tienen sentido

### Semana 2-3: Análisis Profundo
- [ ] Instalar Python + dependencias (scipy, sklearn)
- [ ] Ejecutar análisis de distribuciones en todos los POCs
- [ ] Identificar qué distribuciones ajustan mejor
- [ ] Actualizar parámetros con valores teóricos

### Mes 1: Automatización
- [ ] Crear script automático de calibración
- [ ] Integrar en pipeline de datos (Airflow/Cloud Scheduler)
- [ ] Dashboard de monitoreo de parámetros

### Mes 2-3: Optimización
- [ ] Recopilar ground truth (100-200 usuarios etiquetados)
- [ ] Ejecutar optimización de pesos
- [ ] A/B test: manual vs automático
- [ ] Documentar mejores prácticas

---

## ❓ FAQ

**P: ¿Cuál estrategia debo usar?**  
R: Empieza con **Estrategia 1** (Percentiles). Si funciona bien, quédate ahí. Solo avanza a estrategias más complejas si tienes problemas claros.

**P: ¿Cada cuánto recalibrar parámetros?**  
R: 
- **Automático (Percentiles)**: Mensual
- **Distribuciones**: Trimestral
- **Optimización pesos**: Semestral o cuando tengas nuevo ground truth

**P: ¿Qué hago si la validación automática falla?**  
R: Revisa que tus datos sean razonables. Si `tiempo_p95` es 10 horas, probablemente tienes trabajadores contaminando. Usa modelo 2-pass primero.

**P: ¿Log-Normal siempre es mejor que Normal para tiempos?**  
R: Casi siempre, porque tiempos son >0 y típicamente asimétricos. Pero ejecuta el test de Kolmogorov-Smirnov para estar seguro.

**P: ¿Puedo calibrar parámetros con datos de PRE-campaña?**  
R: NO. Datos PRE tienen comportamiento diferente. Siempre calibra con datos CAMPAIGN.

**P: Mi POC tiene muy pocos datos (<50 usuarios). ¿Qué hago?**  
R: Usa parámetros del perfil base similar. No calibres hasta tener al menos 100-200 usuarios.

---

## 📚 Referencias

- **Scipy Stats**: https://docs.scipy.org/doc/scipy/reference/stats.html
- **Sklearn Clustering**: https://scikit-learn.org/stable/modules/clustering.html
- **BigQuery ML K-Means**: https://cloud.google.com/bigquery-ml/docs/reference/standard-sql/bigqueryml-syntax-create-kmeans
- **Optimización Bayesiana**: https://github.com/fmfn/BayesianOptimization

---

**Última actualización**: 2026-10-27  
**Autor**: Modelo Mejorado V2  
**Versión**: 1.0
