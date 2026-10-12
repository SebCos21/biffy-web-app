# Análisis Completo de la Aplicación BIFFY, Reestructuración y Hoja de Ruta 🚀

## 1. Análisis Exhaustivo del Estado Actual de BIFFY

**BIFFY** es una aplicación de entrega hiperlocal diseñada con una propuesta de valor enfocada en comunidades universitarias y micro-zonas urbanas de alta densidad.

### 1.1 "Nuestros Plus" (Ventajas Competitivas vs. Rappi, DiDi Food, UberEats)
| Característica | Aplicaciones Tradicionales (Rappi / DiDi / Uber) | BIFFY Delivery 🐝 |
|---|---|---|
| **Puntos de Encuentro Campus (`deliveryPoints`)** | Ubicación por GPS imprecisa. El repartidor se pierde en facultades o porterías grandes, generando 20-30 min de retraso. | **Puntos de encuentro predefinidos** (ej. Biblioteca Central, Hall de Ingeniería, Plazoleta Che) con instrucciones exactas. |
| **Radio de Cobertura y Asignación (`isReachable`)** | Venden platos de restaurantes a 8 km sin repartidores disponibles; pedidos cancelados tras 45 min de espera. | **Regla estricta de micro-radio + disponibilidad de repartidores cercanos**. Si no hay repartidores cerca, el restaurante no aparece disponible. |
| **Descuentos Universitarios Verificados** | Códigos de descuento temporales o membresías de pago (ej. RappiPrime). | **Descuento automático de campus (10% - 20%)** validando el correo institucional (`@unal.edu.co`, `@uniandes.edu.co`). |
| **Transparencia Nutricional y Alérgenos** | Filtros básicos de categoría (hamburguesa, pizza). Sin control médico o dietético. | **Detalle de macronutrientes** (kcal, proteínas, carbohidratos, grasas) y **filtro preventivo de alérgenos** (alerta si un plato tiene maní, gluten o lactosa). |
| **Economía de Recompensas ("Gotas" 💧)** | Puntos con vencimiento rápido o canjes poco transparentes. | **Conversión directa**: 700 gotas ≈ $7.000 COP redimibles de inmediato al pagar. Ganadas por encuestas dietéticas, pedidos y referidos. |
| **Asistente de IA Integrado ("Biffy AI")** | Búsqueda por texto estricto. | **Asistente contextual**: sugiere qué comer según antojo, presupuesto disponible, alérgenos y hora del día. |
| **Ecosistema 3-en-1 Unificado** | Aplicaciones separadas pesadas para cada rol (Rappi, Rappi Aliados, SoyRappi). | **Aplicación web progresiva unificada**: Estudiante, Repartidor y Restaurante pueden operar o alternar sin cambiar de app. |
| **Onboarding Tributario para Colombia** | Procesos burocráticos engorrosos. | **Flujo integrado con legislación colombiana**: Soporte para RUT (DIAN), INC (Impuesto Nacional al Consumo del 8%), certificados sanitarios y manipulación. |

---

### 1.2 Brechas Críticas y Oportunidades de Mejora Identificadas

1. **Gestión de Pagos Incompleta (Tarjeta de Crédito/Débito)**:
   - En `src/routes/pagos.tsx`, solo existía un campo numérico básico sin validación Luhn, sin fecha de expiración (MM/AA), sin código de seguridad (CVV/CVC), sin nombre del titular, sin detección de franquicia (Visa, Mastercard, Amex), y sin persistencia real en el estado global.
   - En `src/routes/carrito.tsx`, al pagar solo aparecía la opción genérica "Tarjeta", sin permitir al usuario elegir entre sus tarjetas guardadas ni agregar una nueva durante el checkout.
2. **Monolito en el Estado (`src/lib/store.tsx`)**:
   - Más de 330 líneas combinando autenticación, carrito, pedidos, repartidor, restaurante, catálogo, notificaciones y preferencias. Un cambio en una notificación provoca re-renderizado de pantallas no relacionadas.
3. **Persistencia de Datos**:
   - Actualmente 100% en memoria/mocks. Al recargar la página (F5), se pierden tarjetas agregadas, cambios en productos del restaurante o pedidos realizados.
4. **Falta de Sincronización Bidireccional en Tiempo Real**:
   - El restaurante avanza pedidos con un temporizador artificial `setTimeout`, el repartidor recibe ofertas simuladas cada 5 segundos y el cliente no ve actualizaciones reactivas basadas en eventos reales.

---

## 2. Plan de Reestructuración de Carpetas y Escalabilidad

### 2.1 La Regla de Oro con Lovable: ¿Por qué no mover `src` ciegamente a `frontend/`?
> [!IMPORTANT]
> **Compatibilidad con Lovable y TanStack Start**:
> El repositorio está conectado a Lovable bajo el template `tanstack_start_ts_current`. Lovable espera que `package.json`, `vite.config.ts` y `src/` residan en la raíz del repositorio para su compilador en la nube y su vista previa en tiempo real.
> Si moviéramos todos los archivos a una carpeta `frontend/` sin que Lovable lo soporte, el editor en la nube de Lovable **dejaría de funcionar**.

### 2.2 Arquitectura Recomendada: Modular, Limpia y Escalable

Organizamos el repositorio en 3 grandes áreas sin romper Lovable:
```text
biffy-web-app/
├── docs/                       # Toda la documentación de arquitectura, base de datos y guías
│   ├── database-model.md       # Modelo conceptual, ERD y diccionario
│   ├── schema.sql              # DDL ejecutable para PostgreSQL/Supabase
│   └── app-analysis-and-roadmap.md # Este documento de análisis y hoja de ruta
│
├── backend/                    # Infraestructura de backend y base de datos
│   ├── README.md               # Guía de backend y API
│   ├── supabase/
│   │   ├── config.toml         # Configuración de Supabase CLI
│   │   └── migrations/         # Migraciones SQL versionadas
│   └── types/
│       └── database.types.ts   # Tipos generados automáticamente de la DB
│
├── src/                        # Frontend Web App (Compatible 100% con Lovable y Vite)
│   ├── components/             # Componentes de presentación UI reutilizables
│   │   ├── biffy/              # Componentes de diseño Biffy (tarjetas, mapa, chip, topbar)
│   │   └── ui/                 # Componentes base shadcn/ui (dialog, switch, etc.)
│   ├── features/               # Arquitectura basada en módulos/funcionalidades (Feature-based)
│   │   ├── payments/           # Lógica y validación de tarjetas de crédito y pasarelas
│   │   ├── auth/               # Autenticación, roles y verificación de estudiantes
│   │   ├── cart/               # Carrito, cálculo de tarifas y descuentos
│   │   ├── orders/             # Seguimiento, estados y tickets de cocina
│   │   ├── courier/            # Gestión de repartidor, turnos y código de entrega
│   │   └── merchant/           # Gestión de productos, sedes y documentos legales
│   ├── lib/                    # Estado, clientes API, utilidades y mocks
│   │   ├── store.tsx           # Store global con persistencia en localStorage
│   │   ├── format.ts           # Formateo de moneda COP, distancias y horarios
│   │   ├── mock-data.ts        # Catálogo mock de arranque
│   │   └── supabase.ts         # Cliente de conexión para la base de datos real
│   └── routes/                 # Enrutamiento basado en archivos (TanStack Router)
```

---

## 3. ¿Cuál es la Mejor Opción de Base de Datos para BIFFY?

### Comparativa de Opciones Tecnológicas

| Criterio | **Supabase (PostgreSQL + PostGIS)** *(Recomendado)* | **Firebase (Firestore)** | **Backend Propio (Node + PostgreSQL en AWS)** |
|---|---|---|---|
| **Integración con Lovable** | **Nativa (1-Click)**. Lovable se conecta directo a Supabase. | Requiere configuración manual extensa. | No integrable con la sincronización automática de Lovable. |
| **Soporte Geoespacial (Micro-radios)** | **Excelente**: PostGIS calcula `ST_DWithin` en microsegundos con índices GIST. | **Deficiente**: Firestore no soporta consultas geoespaciales nativas con radios variables. | Excelente, pero requiere mantenimiento de servidor. |
| **Sincronización en Tiempo Real** | **Nativa**: Supabase Realtime (WebSockets sobre cambios de PostgreSQL). | Excelente con listeners de Firestore. | Requiere montar y escalar Socket.IO / Redis PubSub. |
| **Seguridad Multi-Rol** | **RLS (Row Level Security)** nativo en SQL para Cliente, Repartidor y Comercio. | Firestore Rules complejas y difíciles de auditar. | Middleware JWT manual en API. |
| **Costo y Escalabilidad Inicial** | **Gratuito / Muy accesible** en capa de inicio. | Escala por lecturas/escrituras (puede encarecerse). | Costo fijo mensual de servidores (EC2/RDS). |

> [!TIP]
> **Veredicto Definitivo**: **Supabase** es la mejor opción sin discusión para BIFFY. Permite mantener el código en Lovable, tener PostgreSQL relacional con PostGIS para los campus universitarios, y sincronizar en vivo las pantallas de Cliente, Repartidor y Restaurante.

---

## 4. Paso a Paso: Cómo Proceder con la Base de Datos para Pruebas 100% Funcionales

### Fase 1: Creación del Proyecto en Supabase (15 minutos)
1. Entrar a [supabase.com](https://supabase.com) y crear un nuevo proyecto llamado `biffy-delivery`.
2. Elegir la región geográfica más cercana a Colombia (ej. `us-east-1` N. Virginia).
3. Ir al **SQL Editor** de Supabase y pegar el contenido de [`docs/schema.sql`](./schema.sql).
4. Hacer clic en **Run**. En menos de 10 segundos estarán creadas todas las tablas, extensiones (PostGIS), índices y datos de prueba.

### Fase 2: Conexión con la Aplicación Web (10 minutos)
1. En Supabase, ir a **Project Settings -> API** y copiar:
   - `Project URL`
   - `anon public key`
2. En la raíz de este proyecto, agregar un archivo `.env`:
   ```env
   VITE_SUPABASE_URL=https://tu-proyecto.supabase.co
   VITE_SUPABASE_ANON_KEY=tu-clave-anonima-aqui
   ```
3. Instalar la librería cliente:
   ```bash
   npm install @supabase/supabase-js
   ```
4. Configurar el cliente en `src/lib/supabase.ts`.

### Fase 3: Migración Gradual del Store (Híbrido Offline / Online)
1. Implementar la capa de servicios (`src/services/`):
   - `src/services/catalogService.ts`: Si hay conexión a Supabase, consulta `dishes` y `sedes`; si no, usa `mock-data.ts`.
   - `src/services/orderService.ts`: Al confirmar un pedido en `carrito.tsx`, realiza un `insert` en `orders` y `merchant_tickets`.
   - `src/services/courierService.ts`: El repartidor actualiza su ubicación en `courier_profiles`.
2. Activar los canales de Realtime para que los 3 roles interactúen en vivo:
   - Cuando el cliente hace checkout, el restaurante escucha `merchant_tickets` y emite sonido de comanda.
   - Cuando el restaurante pulsa "Listo", el repartidor recibe la notificación de oferta.
   - Cuando el repartidor ingresa el código del cliente, el pedido pasa a "entregado" en la pantalla del cliente.

### Fase 4: Pasarela de Pagos Real (Wompi Colombia / Bold / MercadoPago)
1. Para tarjetas de crédito/débito en Colombia, la mejor opción es **Wompi** (Bancolombia) o **MercadoPago**.
2. Wompi permite tokenizar la tarjeta en el frontend sin que el servidor toque datos sensibles de PCI-DSS.
3. Se guarda el token en `payment_methods.gateway_token` y se efectúa el cobro seguro al confirmar el pedido.
