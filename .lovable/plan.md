# Biffy — Análisis final (sin implementar hasta "Empezar")

## 1. Sección Campus
- Nueva sección "Campus" donde el estudiante pide de los locales de su universidad.
- Acceso solo con cuenta verificada de esa universidad (correo institucional o verificación de identidad del perfil). Sin verificar: se muestra la sección bloqueada con botón "Verificar mi universidad".
- Locales de campus con descuentos exclusivos para estudiantes verificados, visibles en el precio (precio normal tachado + precio estudiante).
- Se integra con Home (acceso directo), Explorar (filtro "Mi campus") y el carrito (descuento aplicado en el resumen).

## 2. Nada sin funcionalidad
- Todo botón del prototipo tendrá una acción real, aunque no se haya explicado.
- Ejemplos: categoría "Pizza" muestra solo pizzas; corazón agrega a favoritos; campana abre notificaciones; "Ver todo" abre la lista completa; compartir copia el enlace; llamar/chatear abre contacto; "Pedir de nuevo" vuelve a llenar el carrito.
- Si un botón no tiene destino claro, se le asigna la acción esperada en una app de delivery y se documenta.

## 3. Disponibilidad por distancia
- Cada local tiene un radio de entrega.
- Solo se muestran comidas y locales cuyo radio cubre la ubicación del usuario y que tienen repartidores cerca.
- Si el usuario está muy lejos, esa opción no aparece (en Home, Explorar, Campus ni Biffy AI).
- Si no hay nada disponible, se muestra un mensaje claro con opción de cambiar el punto de entrega.

## Siguiente paso
Esperar la palabra "Empezar" para construir toda la app y su flujo completo.
