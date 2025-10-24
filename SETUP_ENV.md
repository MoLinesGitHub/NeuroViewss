# 🔐 NeuroViews - Configuración de Variables de Entorno

## Variables de Entorno Requeridas

Para que Claude Code y los MCPs funcionen correctamente, necesitas configurar las siguientes variables de entorno:

### 1. Crear archivo Config.xcconfig (Local)

```bash
cd "NeuroViews 2.0"
cp Config.xcconfig.example Config.xcconfig
```

Edita `Config.xcconfig` y reemplaza los placeholders con tus claves reales:
- `OPENAI_API_KEY`
- `ANTHROPIC_API_KEY`
- `GITHUB_PAT_1`, `GITHUB_PAT_2`, etc.
- (Ver Config.xcconfig.example para la lista completa)

⚠️ **IMPORTANTE**: `Config.xcconfig` está en `.gitignore` y NUNCA debe ser commiteado.

### 2. Variables de Entorno para MCPs

Añade estas variables a tu shell profile (`~/.zshrc` o `~/.bashrc`):

```bash
# GitHub MCP
export GITHUB_PERSONAL_ACCESS_TOKEN="tu_github_token_aqui"

# Task Master AI (elige uno)
export OPENAI_API_KEY="tu_openai_key_aqui"
# O
export ANTHROPIC_API_KEY="tu_anthropic_key_aqui"

# Opcional: Perplexity para research
export PERPLEXITY_API_KEY="tu_perplexity_key_aqui"
```

Luego recarga tu shell:
```bash
source ~/.zshrc  # o source ~/.bashrc
```

### 3. Verificar Configuración

```bash
# Verificar variables de entorno
echo $GITHUB_PERSONAL_ACCESS_TOKEN
echo $OPENAI_API_KEY

# Verificar que Config.xcconfig existe
ls -la "NeuroViews 2.0/Config.xcconfig"
```

## MCPs Configurados

Los siguientes MCPs están configurados en `.mcp.json`:

1. **task-master-ai** - Gestión de tareas y workflow
2. **xcode-mcp** - Control de Xcode
3. **swift-mcp** - Compilación Swift
4. **ios-simulator-mcp** - Control de simuladores
5. **github** - Integración con GitHub (requiere `GITHUB_PERSONAL_ACCESS_TOKEN`)
6. **sequential-thinking** - Razonamiento complejo
7. **memory** - Memoria persistente entre sesiones

## Solución de Problemas

### Los MCPs no se conectan
1. Verifica que las variables de entorno estén definidas
2. Reinicia Claude Code completamente
3. Verifica los logs de MCP en Claude Code

### Config.xcconfig no se encuentra
1. Asegúrate de haberlo creado desde Config.xcconfig.example
2. Verifica que esté en la carpeta `NeuroViews 2.0/`
3. NO debe estar en git (debe aparecer en .gitignore)

### GitHub token inválido
1. Verifica que el token tenga los permisos correctos
2. El token debe tener al menos: `repo`, `read:org`, `workflow`
3. Genera un nuevo token en: https://github.com/settings/tokens

## Seguridad

⚠️ **NUNCA** comitees:
- `Config.xcconfig`
- Archivos `.env` con claves reales
- Tokens o API keys en código

✅ **SIEMPRE**:
- Usa variables de entorno
- Usa archivos `.example` para plantillas
- Verifica `.gitignore` antes de commitear
- Revoca tokens si se filtran accidentalmente
