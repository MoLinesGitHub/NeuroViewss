# 🚀 CI/CD Configuration Guide - NeuroViews 2.0

**Configurado:** 24 de Enero de 2025
**Workflow:** `.github/workflows/ios-ci.yml`
**Estado:** ✅ Activo con coverage tracking

---

## 📋 Resumen de Configuración

### Workflow Principal: `ios-ci.yml`

**Triggers:**
- ✅ Push a `main` o `develop`
- ✅ Pull requests a `main` o `develop`

**Jobs:**
1. **build-and-test** - Build, tests y coverage tracking
2. **warning-analysis** - Análisis detallado de warnings (solo PRs)

---

## 🎯 Límites y Objetivos

### Coverage Tracking (NUEVO ✨)

```yaml
MIN_COVERAGE: 5.0      # Límite mínimo (Actualizado: 5.41% - 24 Ene 2025)
TARGET_COVERAGE: 20.0  # Meta Semana 1-2
FINAL_COVERAGE: 60.0   # Meta Semana 4
```

**Comportamiento:**
- ❌ **Build falla** si coverage < MIN_COVERAGE
- ⚠️ **Warning** si coverage < TARGET_COVERAGE
- ✅ **Success notice** si coverage ≥ TARGET_COVERAGE

**Ejemplo de output:**
```
✅ Coverage: 4.96% (784/15,813 lines)
✅ Coverage OK: Coverage is above minimum (4.5%) but below target (20.0%)
```

### Warning Limits

```yaml
MAX_WARNINGS: 84       # Límite actual
TARGET_WARNINGS: 40    # Meta Opción 1
FINAL_WARNINGS: 0      # Meta final
```

**Comportamiento:**
- ❌ **Build falla** si warnings > MAX_WARNINGS
- ⚠️ **Notice** si warnings ≤ TARGET_WARNINGS (sugerencia de reducir límite)
- ✅ **Success** si warnings ≤ MAX_WARNINGS

---

## 📊 Métricas Rastreadas

### Build Metrics
- Total de warnings
- Warnings por categoría (actor isolation, sendable, MainActor, etc.)
- Top 10 archivos con más warnings

### Test Metrics
- Tests passed/failed
- Test count total
- Test execution time

### Coverage Metrics (NUEVO ✨)
- **Cobertura global** del target `NeuroViews 2.0.app`
- Líneas cubiertas / líneas ejecutables
- Porcentaje de cobertura

---

## 🔧 Cómo Funciona el Coverage Tracking

### 1. Ejecución de Tests con Coverage
```bash
xcodebuild test \
  -scheme "NeuroViews 2.0" \
  -enableCodeCoverage YES \
  -resultBundlePath ./TestResults.xcresult
```

### 2. Extracción de Métricas
```bash
# Generar JSON con xccov
xcrun xccov view --report --json ./TestResults.xcresult > coverage.json

# Extraer coverage del target con jq
COVERAGE=$(jq -r '.targets[] | select(.name == "NeuroViews 2.0.app") | .lineCoverage * 100' coverage.json)
```

### 3. Validación de Límites
```bash
# Comparar con límite mínimo
if [ "$COVERAGE" < "$MIN_COVERAGE" ]; then
  echo "::error::Coverage below minimum"
  exit 1  # ❌ Build fails
fi
```

### 4. GitHub Summary
El workflow genera un resumen automático con:
- Build status
- Test results
- **Code coverage** (nuevo)
- Progress tracker
- Coverage breakdown por componente
- Next steps

---

## 📈 Coverage Breakdown en Summary

```markdown
### Coverage Breakdown
SmartAutoFocus:    ~11% (baseline: 7%)   ✅ Improved
ExposureAnalyzer:  ~9%  (baseline: 2%)   ✅ Improved
CameraManager:     0%   (baseline: 0%)   ⏳ Pending
SendablePixelBuffer: ~27%                ✅ Good
DataManager:       ~32%                  ✅ Good
```

---

## 🎯 Incremento de Límites

### Strategy: Ratcheting Coverage

A medida que añades tests, incrementa `MIN_COVERAGE` para evitar regresiones:

```yaml
# Semana 1 (24 Ene 2025)
MIN_COVERAGE: 4.5   # Baseline inicial: 4.96%
MIN_COVERAGE: 5.0   # ✅ ACTUALIZADO después de CameraManager tests: 5.41%

# Semana 2 (con mock infrastructure)
MIN_COVERAGE: 10.0  # Target: mocks básicos para análisis

# Semana 3 (tests de integración con mocks)
MIN_COVERAGE: 30.0  # Target: core methods con mocks completos

# Semana 4 (tests end-to-end)
MIN_COVERAGE: 50.0  # Target: 60% final goal approach
```

**Comando para actualizar:**
```bash
# Editar .github/workflows/ios-ci.yml
MIN_COVERAGE: 8.0  # Nuevo valor
```

---

## 🚨 Manejo de Fallos

### Coverage Below Minimum

**Síntoma:**
```
❌ error: Coverage (3.2%) is below minimum required (4.5%)
Build failed
```

**Solución:**
1. Verificar que los tests nuevos se ejecutaron
2. Revisar `coverage.json` en artifacts
3. Añadir tests faltantes o reducir `MIN_COVERAGE` temporalmente

### Warning Threshold Exceeded

**Síntoma:**
```
❌ error: Warning count (90) exceeds maximum allowed (84)
Build failed
```

**Solución:**
1. Revisar `all_warnings.txt` en artifacts
2. Resolver warnings nuevos
3. Si son warnings válidos, incrementar `MAX_WARNINGS` temporalmente

---

## 📁 Artifacts Generados

### test-results (30 días retention)
- `TestResults.xcresult` - Bundle completo de Xcode
- `build_log.txt` - Log de compilación
- `test_log.txt` - Log de ejecución de tests
- `coverage.json` - **Reporte JSON de coverage** (nuevo)

### warning-analysis (30 días retention, solo PRs)
- `all_warnings.txt` - Todos los warnings
- `warning_report.md` - Breakdown por categoría

### build-failure-logs (7 días retention, solo fallos)
- `build_log.txt` - Log de compilación fallida
- `test_log.txt` - Log de tests fallidos

---

## 🔍 Debugging Coverage Issues

### Ver coverage local
```bash
# Ejecutar tests con coverage
xcodebuild test \
  -scheme "NeuroViews 2.0" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -enableCodeCoverage YES \
  -resultBundlePath ./.build/test-results.xcresult

# Generar JSON
xcrun xccov view --report --json ./.build/test-results.xcresult > coverage.json

# Ver coverage global
cat coverage.json | jq -r '.targets[] | select(.name == "NeuroViews 2.0.app") | "Coverage: \(.lineCoverage * 100)% (\(.coveredLines)/\(.executableLines) lines)"'
```

### Ver coverage por archivo
```bash
cat coverage.json | jq -r '.targets[] | select(.name == "NeuroViews 2.0.app") | .files[] | "\(.path | split("/") | last): \(.lineCoverage * 100)%"' | sort -t: -k2 -n
```

---

## ✅ Verificación de Configuración

### Test del workflow localmente

**Usar [act](https://github.com/nektos/act) para simular GitHub Actions:**

```bash
# Instalar act
brew install act

# Ejecutar workflow localmente
act -j build-and-test
```

### Validar cambios antes de commit

```bash
# 1. Verificar sintaxis YAML
yamllint .github/workflows/ios-ci.yml

# 2. Ejecutar tests localmente
xcodebuild test -scheme "NeuroViews 2.0" -enableCodeCoverage YES

# 3. Verificar coverage >= MIN_COVERAGE
# (usar script de debugging arriba)
```

---

## 📚 Referencias

### Xcode Coverage
- [xccov documentation](https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/testing_with_xcode/chapters/07-code_coverage.html)
- [Code coverage best practices](https://developer.apple.com/videos/play/wwdc2022/110351/)

### GitHub Actions
- [GitHub Actions for iOS](https://docs.github.com/en/actions/automating-builds-and-tests/building-and-testing-swift)
- [Workflow syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)

### CI/CD Best Practices
- [iOS CI/CD guide](https://www.raywenderlich.com/10395676-continuous-integration-and-delivery-for-ios-with-github-actions)
- [Ratcheting code coverage](https://blog.alexellis.io/ratcheting-test-coverage/)

---

## 🎯 Próximos Pasos

### Corto Plazo (Esta Semana)
1. ✅ **Configurar CI/CD** con coverage tracking
2. 🎯 **Añadir badge de coverage** al README
3. 🎯 **Configurar Codecov/Coveralls** para visualización mejor (opcional)

### Mediano Plazo (Semanas 2-3)
4. Incrementar `MIN_COVERAGE` a 8% después de completar SmartAutoFocus + ExposureAnalyzer
5. Añadir CameraManager tests y subir `MIN_COVERAGE` a 15%
6. Configurar alerts de Slack/Discord para failures (opcional)

### Largo Plazo (Semana 4+)
7. Alcanzar 60% coverage global
8. Reducir `MAX_WARNINGS` a 0
9. Implementar coverage por módulo/package
10. Branch protection rules basadas en coverage mínimo

---

**Configurado por:** Claude Code
**Baseline establecido:** 4.96% (24 Ene 2025)
**Coverage actual:** 5.41% (24 Ene 2025 - con CameraManager tests)
**Límite actual:** 5.0%
**Meta final:** 60% (Semana 4)

**Estado:** ✅ Ready for production
