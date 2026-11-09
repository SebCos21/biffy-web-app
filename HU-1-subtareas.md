# HU-1 · Base de datos, autenticación y perfiles reales

> **Rama:** `hu1-base-datos-auth-perfiles`
> **Historia:** Como usuario de Biffy (comprador, restaurante o repartidor),
> quiero registrarme e iniciar sesión con mi cuenta real y que mi perfil quede
> guardado, para entrar a la app con mis datos desde cualquier dispositivo.
>
> **Fuente:** `3EB02ABDF92612B20EDC95-Backend_de_Biffy__4_historias_de_usuario.docx`
> (HU-1). Proyecto Supabase: `jwdzpwsfwtkdeeuceaco`.

## Alcance de la historia

1. Aplicar `supabase/apply_all.sql` (o `supabase db push`) al proyecto remoto.
2. Configurar Auth con correo y contraseña (confirmación según el entorno).
3. Crear las 3 cuentas demo con `service_role` desde un script local.
4. Perfiles, direcciones, preferencias, ajustes y verificación universitaria.

## Subtareas

### HU-1.1 · Aplicar el esquema y verificar la base

- [ ] Aplicar `supabase/apply_all.sql` en el SQL Editor o `supabase link` +
      `supabase db push` contra `jwdzpwsfwtkdeeuceaco`.
- [ ] Ejecutar `supabase/migrations/0099_verify.sql` y guardar la salida
      (`Biffy OK · N tablas · N políticas RLS`).
- [ ] Confirmar RLS activo en las 24 tablas y que `universities`,
      `delivery_points`, `categories` y `gotas_rewards` tienen datos semilla.
- [ ] Confirmar que `apply_all.sql` sigue siendo el generado desde
      `supabase/migrations/` (sin ediciones manuales).

**Archivos:** `supabase/apply_all.sql`, `supabase/migrations/0099_verify.sql`,
`supabase/README.md`.

### HU-1.2 · Configurar Auth por correo y contraseña

- [ ] Definir confirmación de correo por entorno: desactivada en demo/staging,
      activada en producción.
- [ ] Revisar plantilla de correo en español, remitente y límites de Auth.
- [ ] Verificar que `AppConfig.hasSupabase` solo habilita el backend cuando
      existen `SUPABASE_URL` y `SUPABASE_KEY` en `env.json`.
- [ ] Comprobar que sin variables la app arranca en demo y no hace peticiones
      de red.

**Archivos:** `lib/core/config/app_config.dart`, `env.example.json`,
`supabase/README.md`.

### HU-1.3 · Script local de cuentas demo (`service_role`)

- [ ] Crear/ajustar el script de administración (fuera de la app) que crea las
      cuentas con `admin.createUser` y contraseña `biffy123`:
      - `diego.demo@icesi.edu.co` (comprador)
      - `andres.repartidor@demo.biffy.co` (repartidor)
      - `qbano@demo.biffy.co` (restaurante)
- [ ] Ejecutarlo contra el proyecto remoto y validar el inicio de sesión de las
      tres cuentas en la app real.
- [ ] Confirmar que la `service_role` no está en el repositorio, ni en
      `env.json`, ni en la app: solo la clave publicable.

**Archivos:** `tool/seed_supabase.dart`, `env.example.json`, `.gitignore`.

### HU-1.4 · Registro con rol, perfil y 450 Gotas

- [ ] Validar que un registro nuevo como comprador, repartidor o restaurante
      crea la fila en `profiles` con el rol elegido (`handle_new_user`).
- [ ] Verificar que las 450 Gotas se acreditan **una sola vez** en
      `gotas_ledger` (sin duplicar al reintentar).
- [ ] Revisar el flujo `signUp` de `SupabaseAuthRepository` y los mensajes de
      error en español para la UI.
- [ ] Cubrir el registro de los tres roles con una prueba de integración.

**Archivos:** `lib/data/repositories/supabase_auth_repository.dart`,
`lib/shared/state/session_controller.dart`,
`supabase/migrations/0003_functions.sql`,
`supabase/migrations/0009_welcome_gotas.sql`.

### HU-1.5 · Perfil de repartidor y alta de negocio

- [ ] Confirmar que el repartidor obtiene su fila en `courier_profiles` al
      registrarse.
- [ ] Confirmar que el restaurante crea negocio y sede con
      `register_business` y queda vinculado a su perfil.
- [ ] Probar ambos caminos con cuentas nuevas reales y revisar el resultado en
      la base.
- [ ] Asegurar que los errores de RPC se traducen a mensajes en español.

**Archivos:** `lib/data/repositories/supabase_auth_repository.dart`,
`lib/shared/state/session_controller.dart`,
`supabase/migrations/0003_functions.sql`.

### HU-1.6 · Verificación universitaria por dominio

- [ ] Probar `verify_university` con el dominio correcto: el comprador queda
      verificado.
- [ ] Probar con un dominio distinto: la RPC devuelve error y no marca al
      usuario.
- [ ] Verificar que la verificación solo aplica al rol comprador y que la UI
      muestra el resultado sin errores crudos.

**Archivos:** `lib/shared/state/session_controller.dart`,
`supabase/migrations/0003_functions.sql`, `supabase/migrations/0004_rls.sql`.

### HU-1.7 · Guardas del perfil (rol, Gotas y verificación)

- [ ] Intentar `update profiles` directo cambiando `role`, Gotas o
      verificación con un cliente autenticado: debe fallar
      (`guard_profile_update`).
- [ ] Dejar la prueba documentada con el SQL usado y el error obtenido.
- [ ] Confirmar que esos campos solo cambian por RPC/administración.

**Archivos:** `supabase/migrations/0004_rls.sql`,
`supabase/migrations/0003_functions.sql`.

### HU-1.8 · Direcciones, preferencias y ajustes aislados por usuario

- [ ] Probar crear, editar, marcar predeterminada y borrar (lógicamente) una
      dirección; la app debe reflejarlo tras reabrir.
- [ ] Guardar y releer preferencias y ajustes.
- [ ] Verificar con dos usuarios distintos que cada uno ve solo sus datos
      (RLS en `addresses`, `preferences`, `app_settings`).
- [ ] Revisar el manejo de errores de escritura para no perder el estado local.

**Archivos:** `lib/data/repositories/supabase_profile_repository.dart`,
`lib/shared/state/session_controller.dart`,
`supabase/migrations/0004_rls.sql`.

### HU-1.9 · Persistencia de sesión y cierre de sesión

- [ ] Confirmar que la sesión sobrevive al reiniciar la app
      (`restoreSession`) y que la hidratación de perfil funciona.
- [ ] Confirmar que `signOut` limpia la sesión y el estado en memoria.
- [ ] Probar con las cuentas demo y con una cuenta nueva.

**Archivos:** `lib/data/repositories/supabase_auth_repository.dart`,
`lib/shared/state/session_controller.dart`.

### HU-1.10 · Modo demo intacto y claves seguras

- [ ] Ejecutar la app sin `SUPABASE_URL`: debe seguir en demo local, sin red.
- [ ] Revisar que `SUPABASE_KEY` sea la clave publicable y que ninguna clave
      `service_role` esté versionada.
- [ ] Actualizar `HANDOFF.md` y `supabase/README.md` con el estado real de la
      base y las cuentas demo.

**Archivos:** `HANDOFF.md`, `supabase/README.md`, `env.example.json`.

### HU-1.11 · Pruebas y cierre de la historia

- [ ] Pruebas de RLS con al menos dos usuarios distintos (acciones permitidas y
      rechazadas).
- [ ] `flutter analyze` sin errores y `flutter test` en verde (incluye
      `test/integration/full_flow.dart` en modo demo).
- [ ] Smoke test manual: registro → login → perfil → dirección → preferencias
      con las tres cuentas demo.
- [ ] Registrar evidencias (salida de `0099_verify.sql`, capturas o logs) y
      cerrar la HU en `HANDOFF.md`.

## Orden sugerido

1. HU-1.1 → HU-1.2 → HU-1.3 (base y accesos reales).
2. HU-1.4 → HU-1.5 → HU-1.6 → HU-1.7 (registro y perfiles).
3. HU-1.8 → HU-1.9 → HU-1.10 (datos personales y modo demo).
4. HU-1.11 (pruebas y cierre).

## Definición de hecho (aplica a toda la HU)

- Cada cambio de esquema es una migración nueva; nunca se edita desde el panel.
- Hay pruebas de RLS con al menos dos usuarios distintos.
- `flutter analyze` y los tests están en verde y `full_flow.dart` pasa en demo.
- `HANDOFF.md` actualizado al cerrar la historia.
