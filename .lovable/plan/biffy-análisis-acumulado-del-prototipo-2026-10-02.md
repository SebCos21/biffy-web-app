# Biffy — Análisis acumulado del prototipo

## Estado: solo análisis

No se construirá nada hasta que el usuario diga **"Empezar"**. El prototipo es referencia funcional y visual: al implementarlo se conservará su intención, mejorando jerarquía, consistencia, accesibilidad y fluidez.

## Secciones ya analizadas (resumen)

1. **Filtros de onboarding** — 3 pasos (gustos, alergias/estilo de vida, presupuesto COP); alimentan la IA; al iniciar sesión y en puntos.
2. **Home** — con sesión (saludo, pedido activo, recomendaciones, descuentos, puntos, recompensas) y sin sesión (exploración pública).
3. **Detalle de plato** — foto, precio COP, personalización, cantidad, carrito; advertencias de alergias.
4. **Detalle de restaurante** — datos del local, menú por categorías, pedidos grupales, resumen de carrito.
5. **Explorar / buscador** — búsqueda, voz, filtros, chips rápidos, categorías, tendencias, platos destacados.
6. **Recompensas (Club de Enjambre)** — Gotas Biffy (700 ≈ $7.000 COP); racha 7/10; niveles 3/6/10; puntos por encuesta, invitar gente y pedidos.
7. **Biffy AI** — Decision AI con modos y % match (3 mejores opciones); chat con comandos, nota de seguridad y ranking.
8. **Perfil** — cuenta verificada, info personal bloqueada con PIN al correo/número, pedidos, rewards, favoritos, preferencias (encuesta desaparece al completarla), pagos, notificaciones, seguridad, soporte, cerrar sesión, acceso a modo repartidor.
9. **Carrito y checkout** — editar/eliminar ítems; programar ahora o con calendario + franjas de hora según disponibilidad del local; punto de entrega; resumen con tarifa de campus y descuento estudiante; método de pago estilo Rappi.
10. **Pedidos y seguimiento en vivo** — tabs Activos/Programados/Anteriores; modificar hora, cancelar, pedir de nuevo; mapa con ruta del repartidor, ETA, progreso Confirmado→Preparado→En camino→Entregado, tarjeta del repartidor y código de entrega.

## Sección 11 — Modo repartidor (nueva)

### Inicio del repartidor
- Header "Modo repartidor" con estado **CONECTADA** y toggle para conectarse/desconectarse.
- Saludo con fecha/hora y campus; tarjetas de **Ganancias hoy** ($34.500) y **Entregas** (5 pedidos).
- **Mapa de demanda cerca de ti** ("Alta ahora"): zonas activas con # de pedidos, puntos calientes (Eje W–ML alta demanda, Biblioteca +$1.200 de bonificación).
- **Pedidos disponibles** (3 cerca): restaurante, punto de entrega, distancia y tiempo (0,8 KM · 12 MIN), estado "Lista para tomar" y pago ($7.800).
- Aviso "Estás visible para restaurantes cercanos" + DESCONectar.

### Nueva oferta (EN VIVO)
- Banner "Oferta exclusiva para ti — decide antes de que expire" con **cuenta regresiva** (18s).
- Mapa con **ruta total** (14 min), recogida y destino.
- Detalle: restaurante, punto de recogida (Plazoleta B · Local 12), "Listo en 6 min", recogida → entrega, **distancia (1,3 km)** y **pago estimado ($7.800)**.
- Acciones: **Rechazar** (no afecta el nivel de repartidor) / **Aceptar pedido**.

### Paso 1 de 2 — Recoger y verificar (EN RESTAURANTE)
- Mapa con "Llegaste" y punto de recogida; badge PEDIDO LISTO.
- Tarjeta del pedido con **código de recogida (8492)** para mostrar al equipo del restaurante.
- **Checklist de recogida**: código validado, pedido sellado (bolsa cerrada sin derrames), verificar productos; resumen "2 productos · Bolsa mediana" con ver detalle.
- CTA "Confirmar recogida"; enlace a soporte si hay problema.

### Paso 2 de 2 — Entrega activa (EN CAMINO)
- "Hacia el cliente — Entrega a Sofía", ETA (6 min · 12:23 PM) y mapa con ruta al destino.
- Tarjeta del cliente (nombre, punto exacto, botones llamar/chat) y nota del cliente ("Estoy en las bancas junto al ascensor").
- **Código de entrega (4821)**: el cliente lo brinda para confirmar identidad antes de entregar (badge SEGURO).
- El repartidor conoce el **método de pago** del pedido.
- **Evidencia fotográfica**: foto del pedido entregado como prueba.
- Al completar: total del día y **pago inmediato (+$7.800)**; la app cobra su **tarifa cada quincena**.
- CTA "Marcar como entregado"; opción "No encuentro al cliente · Pedir ayuda".

### Reglas del rol
- Los **pedidos programados (calendario) no afectan** al repartidor: cuando llega la hora, la oferta le aparece como una normal.
- El repartidor tiene la **misma sección de configuración** del perfil y puede **volver a modo estudiante** cuando quiera pedir por la app.
- **Idea fuera del prototipo (aprobada para análisis)**: recompensas monetarias o premios por cumplir cierta cantidad de carreras, mostradas con **barra de progreso**.

## Mejoras previstas al construir (acumulado)

- Unificar encabezados, navegación, radios, sombras, espaciado y estados interactivos.
- Advertencias de alergias visibles en platos, personalización y checkout.
- Estados vacíos, carga, error, restaurante cerrado y sin pedido activo.
- Contraste, tamaño táctil y retroalimentación de selecciones.
- Chat con streaming, historial e indicador de escritura.
- Perfil: desbloqueo por PIN con verificación real al correo/número.
- Checkout: disponibilidad de fecha/hora según horario real del restaurante; no confirmar slots no disponibles.
- Mapas (seguimiento cliente y vistas de repartidor): evaluar Google Maps/Mapbox al construir.
- Repartidor: expiración real de ofertas, evidencia fotográfica obligatoria, liquidación quincenal de tarifa de la app, y barra de progreso de recompensas por carreras.

## Flujo conectado registrado

```text
Estudiante: Home → Explorar → Restaurante → Plato → Carrito → Programar (calendario/hora según local)
  → Pago (estilo Rappi) → Pedidos → Seguimiento en vivo (mapa, código de entrega)

Repartidor: Activar modo → Inicio (demanda cerca, ganancias) → Oferta en vivo (ruta, km, pago, countdown)
  → Aceptar → Recoger y verificar (código + checklist) → Entrega activa (mapa, código del cliente,
  método de pago, foto de evidencia) → Pago inmediato (tarifa app cobrada quincenal)
  → Recompensas por carreras (barra de progreso) · puede volver a modo estudiante
```

## Siguiente paso

Continuar recibiendo secciones. Cuando el usuario diga **"Empezar"**, preparar e implementar el flujo completo con las mejoras acordadas.
