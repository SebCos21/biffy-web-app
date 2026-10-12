# Módulo Backend - BIFFY Delivery Platform 🐝

Este directorio aloja la arquitectura de servicios backend, migraciones de base de datos, tipados generados para TypeScript y configuración para **Supabase / PostgreSQL**.

## Estructura de Directorios

```text
backend/
├── README.md               # Este documento explicativo
├── supabase/
│   ├── config.toml         # Configuración del CLI de Supabase
│   └── migrations/         # Migraciones SQL versionadas
│       └── 20261012000000_biffy_initial_schema.sql
└── types/
    └── database.types.ts   # Tipos estáticos para cliente TypeScript
```

## Comandos Útiles de Supabase CLI

Para desarrollo local y sincronización de tipos:

1. **Iniciar Supabase local con Docker**:
   ```bash
   npx supabase start
   ```

2. **Aplicar migraciones**:
   ```bash
   npx supabase db push
   ```

3. **Generar tipos TypeScript automáticos para el frontend**:
   ```bash
   npx supabase gen types typescript --local > backend/types/database.types.ts
   ```

4. **Vincular con tu proyecto en la nube**:
   ```bash
   npx supabase link --project-ref <tu-project-id>
   ```
