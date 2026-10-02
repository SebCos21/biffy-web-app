# Biffy — Análisis acumulado del prototipo

## Estado: solo análisis

No se construirá nada hasta que el usuario diga **"Empezar"**. El prototipo es referencia funcional y visual: al implementarlo se conservará su intención, mejorando jerarquía, consistencia, accesibilidad y fluidez.

## Secciones ya analizadas (resumen)

1. **Filtros de onboarding** — 3 pasos (gustos, alergias/estilo de vida, presupuesto COP); alimentan la IA; al iniciar sesión y en puntos (completarlos da puntos).
2. **Home** — con sesión (saludo, pedido activo, recomendaciones, descuentos, puntos, recompensas) y sin sesión (exploración pública).
3. **Detalle de plato** — foto, precio COP, personalización con impacto en precio, cantidad, carrito; advertencias de alergias.
4. **Detalle de restaurante** — datos del local, menú por categorías, pedidos grupales, resumen de carrito.
5. **Explorar / buscador** — búsqueda, voz, filtros, chips rápidos, categorías, tendencias, platos destacados.
6. **Recompensas (Club de Enjambre)** — Gotas Biffy (700 ≈ $7.000 COP); racha 7/10; niveles 3/6/10; puntos por encuesta, invitar gente y pedidos.
7. **Biffy AI** — Decision AI con modos y % match (3 mejores opciones); chat con comandos, nota de seguridad y ranking.
8. **Perfil** — cuenta y verificación, info personal bloqueada con PIN al correo/número, pedidos, rewards, favoritos, preferencias (encuesta desaparece al completarla), pagos, notificaciones, seguridad, soporte, cerrar sesión, modo repartidor.

## Sección 9 — Carrito y checkout (nueva)

### Carrito ("Tu Pedido")
- Header con volver y avatar; título "Tu Pedido 🛒" + badge "N ITEMS"; restaurante y punto (Wok & Roll Express · Edificio ML).
- Ítems con foto, nombre, personalización ("Sin cebollín, salsa extra"), precio COP, stepper de cantidad y botón eliminar. **Se puede editar cantidad o eliminar el pedido.**

### Programación del pedido ("¿Cuándo quieres tu pedido?" — Biffy Smart)
- Opciones rápidas: **Ahora** (12–15 min, inmediato), **Mañana · 12:30 PM (Hueco clase)** con badge "Recomendado", **Hoy más tarde** (elegir hora).
- **Calendario mensual** para elegir fecha; la disponibilidad depende del local que vende la comida. Nota: "Los horarios dependerán de la disponibilidad de [restaurante]".
- **Selector de hora** por franjas (Mañana, Tarde, Noche, Cierre) con slots de 30 min; también depende de la disponibilidad del local.
- Confirmación: "Horario confirmado: [fecha] · [hora]" y "Se cocinará 10 min antes de tu descanso".

### Entrega y resumen
- Punto de entrega (Edificio ML · Bancas Piso 3) con "Cambiar".
- Resumen de cuenta: Subtotal $29.000, Tarifa de campus $2.500, **Descuento Estudiante Biffy −$3.000**, Total $28.500 COP (impuestos incluidos).
- Aviso de puntos: "Ganarás 120 Puntos Polen con este pedido".
- CTA "Continuar al pago ⚡ $28.500".

### Pago
- **Método de pago estilo Rappi**: selección entre los métodos guardados (Bancolombia ••••4821, Nequi, etc.) antes de confirmar.

## Sección 10 — Pedidos y seguimiento en vivo (nueva)

### Pantalla de pedidos
- Tabs: **Activos (1)**, **Programados (1)**, **Anteriores (12)**.
- **En curso** (PRIORITARIO): tarjeta con foto, restaurante, platos, # de pedido (BIF-8492), QR, estado animado ("Preparando tu bowl…"), "Listo en 8 mins · 12:15 PM", entrega en Locker Biffy (M. Laserna #04), CTA "Ver seguimiento en vivo".
- **Programados**: "Para mañana · 12:30 PM", badge Confirmado, platos y precio, punto de entrega, acciones **Modificar hora** y **Cancelar**.
- **Anteriores**: restaurante, platos, fecha/hora, precio, rating, "Pedir de nuevo" y factura.

### Seguimiento en vivo
- Estado "EN CAMINO": "Mateo lleva tu pedido — salió de Wok & Roll Express y va hacia Edificio ML".
- **Mapa del campus** con ruta del repartidor, ETA ("Llega en 8 min") y destino (Edificio ML · Bancas Piso 3).
- Línea de progreso: Confirmado → Preparado → En camino → Entregado, con hora aproximada.
- Tarjeta del repartidor: foto, nombre, vehículo (Moto), rating 4.9, 286 entregas, botones llamar y chat.
- Resumen del pedido (#BIF-8492, platos, total) y tarjeta "¿Necesitas ayuda?".
- Aviso: "Ten tu código 4821 listo para recibir el pedido" (código de entrega).

## Mejoras previstas al construir (acumulado)

- Unificar encabezados, navegación, radios, sombras, espaciado y estados interactivos.
- Advertencias de alergias visibles en platos, personalización y checkout.
- Estados vacíos, carga, error, restaurante cerrado y sin pedido activo.
- Contraste, tamaño táctil y retroalimentación de selecciones.
- Chat con streaming, historial e indicador de escritura.
- Perfil: desbloqueo por PIN con verificación real al correo/número.
- Checkout: disponibilidad de fecha/hora calculada según horario real del restaurante; validar que no se pueda confirmar un slot no disponible.
- Seguimiento: mapa con la ubicación del repartidor (se evaluará Google Maps/Mapbox al construir); estados de cancelación y reprogramación claros.

## Flujo conectado registrado

```text
Carrito → editar/eliminar ítems → elegir ahora o programar (calendario + hora según disponibilidad del local)
  → punto de entrega → resumen con descuento estudiante → método de pago (estilo Rappi) → confirmar
  → Pedidos (Activos / Programados / Anteriores) → Seguimiento en vivo (mapa, repartidor, código de entrega)
```

## Siguiente paso

Continuar recibiendo secciones. Cuando el usuario diga **"Empezar"**, preparar e implementar el flujo completo con las mejoras acordadas.
