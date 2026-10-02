# Biffy — Análisis acumulado del prototipo

## Estado: solo análisis

No se construirá nada hasta que el usuario diga **"Empezar"**. El prototipo es referencia funcional y visual: al implementarlo se conservará su intención, mejorando jerarquía, consistencia, accesibilidad y fluidez.

## Secciones ya analizadas (resumen)

1. **Filtros de onboarding** — 3 pasos (gustos, alergias/estilo de vida, presupuesto COP); alimentan la IA; se muestran al iniciar sesión y en la sección de puntos (completarlos da puntos).
2. **Home** — dos variantes: con sesión (saludo, pedido activo, recomendaciones, descuentos, puntos, botón de recompensas) y sin sesión (exploración pública, se invita a iniciar sesión solo cuando una acción lo requiere).
3. **Detalle de plato** — foto, restaurante, precio COP, personalización con impacto en precio, cantidad, agregar al carrito; advertencias de alergias al implementar.
4. **Detalle de restaurante** — datos del local, menú por categorías, pedidos grupales, resumen persistente del carrito.
5. **Explorar / buscador** — búsqueda por plato o restaurante, voz, filtros avanzados, chips rápidos, categorías que filtran por tipo de comida, tendencias del campus, platos destacados.
6. **Recompensas (Club de Enjambre)** — botón solo con sesión; Gotas Biffy (700 ≈ $7.000 COP); racha 7/10; niveles 3/6/10 pedidos; puntos por: completar encuesta de filtros, invitar gente, cumplir cantidad de pedidos.
7. **Biffy AI** — Decision AI con modos de decisión y recomendación con % match (el análisis completo entrega las **3 mejores opciones**); chat con comandos, nota de seguridad de alergias y ranking estructurado.

## Sección 8 — Perfil de usuario (nueva)

Tab "Perfil" del bottom nav. Contenido identificado en el prototipo:

### Información de cuenta
- Header con logo y avatar; tarjeta de perfil: foto, nombre, badge "VERIFICADA", universidad y carrera (UniAndes · Ingeniería).
- Estadísticas: pedidos totales, nivel (Lvl 2 Gourmet), puntos.
- **Información personal bloqueada**: los datos sensibles solo se muestran si el usuario solicita un PIN que llega a su correo o número y lo ingresa correctamente.

### Mi Biffy
- Mis pedidos (último pedido + badge "1 en curso") → historial de pedidos.
- Biffy Rewards (progreso de sellos 7/10, acceso a recompensas).
- Favoritos guardados (restaurantes cercanos).

### Mis preferencias
- Comida preferida (etiquetas: Burgers, Asian & Ramen, Healthy bowls).
- Alergias y restricciones (Sin Lactosa, Alerta maní activa).
- Presupuesto habitual ($20k–$30k COP).
- Puntos de entrega en campus (guardados, con uno Default).
- **Encuesta de filtros para ganar puntos**: acceso desde aquí; **si ya completó la encuesta, ese acceso desaparece** y no vuelve a mostrarse.
- Botón "Editar" para ajustar preferencias.

### Cuenta y ajustes
- Métodos de pago (Bancolombia ••••4821, Nequi).
- Notificaciones de pedidos (alertas sonoras y estado en vivo).
- Configuración y seguridad (FaceID, correo UniAndes, privacidad).
- Ayuda y soporte Biffy (chat en vivo con el equipo del campus / contactar soporte).
- **Cerrar sesión** (acción en rojo).

### Modo repartidor (nuevo rol)
- Tarjeta destacada violeta "Gana moviéndote por el campus": recibe ofertas cercanas, entrega pedidos dentro de UniAndes, control de tu tiempo.
- Toggle "Activar modo repartidor" (se puede volver a modo estudiante cuando quiera).
- Sección "Antes de empezar": tú eliges cuándo, ganancias claras, identidad y método de pago verificados.
- CTA "Entrar como repartidora".

## Mejoras previstas al construir (acumulado)

- Unificar encabezados, navegación, radios, sombras, espaciado y estados interactivos.
- Advertencias de alergias visibles en platos, personalización y checkout.
- Estados vacíos, carga, error, restaurante cerrado y sin pedido activo.
- Contraste, tamaño táctil y retroalimentación de selecciones.
- Chat con streaming, historial e indicador de escritura.
- Perfil: el desbloqueo por PIN de info personal se implementará con verificación real (código al correo/número) cuando se construya con backend.

## Siguiente paso

Continuar recibiendo secciones. Cuando el usuario diga **"Empezar"**, preparar e implementar el flujo completo con las mejoras acordadas.
