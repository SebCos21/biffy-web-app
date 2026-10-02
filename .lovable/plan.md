# Biffy — Análisis acumulado del prototipo

## Estado: solo análisis

No se construirá nada hasta que el usuario diga **“Empezar”**. El prototipo es una referencia funcional y visual: al implementarlo se conservará su intención, pero se mejorarán jerarquía, consistencia, accesibilidad y fluidez del recorrido.

## 1. Filtros de onboarding

Flujo de 3 pasos que alimenta las recomendaciones de IA y puede completarse al iniciar sesión o desde la sección de puntos para obtener una recompensa:

1. Gustos y tipos de comida favoritos.
2. Estilo de vida, alergias e intolerancias, con alertas de alta prioridad.
3. Presupuesto por comida en COP.

## 2. Home con dos estados

### Usuario con sesión iniciada
- Saludo personalizado, sede/campus y tiempo libre disponible.
- Seguimiento de pedidos activos con estado, tiempo estimado y repartidor.
- Recomendaciones basadas en los filtros de gustos, restricciones y presupuesto.
- Descuentos y beneficios personalizados.
- Acceso a “Sorpréndeme, Biffy” para recibir una sugerencia.
- Categorías, restaurantes rápidos del campus y progreso de Puntos Biffy.
- Botón de recompensas (solo con sesión) y navegación inferior: Inicio, Explorar, Biffy AI y Perfil.

### Usuario sin iniciar sesión
- Puede explorar e interactuar con comidas y restaurantes.
- Puede abrir detalles, consultar información, personalizar platos y avanzar en la experiencia pública.
- No ve recomendaciones calculadas con filtros personales, descuentos personalizados, botón de recompensas ni progreso de puntos.
- Cuando una acción requiera identidad o datos personales, se le invitará a iniciar sesión sin bloquear la exploración previa.

## 3. Detalle de plato

- Imagen principal, restaurante, tiempo estimado, valoración, nombre y precio en COP.
- Etiquetas nutricionales o contextuales, descripción e ingredientes.
- Personalización mediante extras, sustituciones o exclusiones, cada una con impacto claro en el precio.
- Selector de cantidad y total actualizado antes de agregar al carrito.
- Acciones para volver, compartir y guardar como favorito.
- Al implementarse, las alergias activas deberán reflejarse de forma clara antes de confirmar una selección incompatible.

## 4. Detalle de restaurante

- Imagen, nombre, estado abierto/cerrado, descripción, valoración, tiempo, ubicación y beneficios universitarios.
- Modalidad de retiro o entrega.
- Menú organizado por categorías con platos, etiquetas, precios y acción rápida para agregar.
- Recomendaciones de Biffy visibles únicamente cuando correspondan al estado de sesión y filtros.
- Opción para pedidos grupales.
- Resumen persistente del carrito con cantidad, total y acceso al carrito.

## 5. Explorar / buscador

- Header: logo, selector de campus (dropdown), carrito con badge, avatar.
- Título "Explora 🍴" + badge "CAMPUS LIVE"; subtítulo "Encuentra tu antojo en campus".
- Buscador con micrófono (búsqueda por voz) y botón de filtros avanzados.
- Chips rápidos: ⚡ Rápido (<15m), 💰 Menos de $20k, ⭐ 4.8+.
- Categorías Populares (scroll horizontal, "Ver todo"): filtra por tipo de comida (todas las pizzas, todas las hamburguesas…).
- 🔥 Tendencia en UniAndes ("Top Spots"): tarjetas grandes de restaurante con badge de ubicación, tiempo estimado, rating, cocina, rango de precios COP y "Ver menú →".
- ✨ Platos Destacados ("Pide al instante"): filas con badge (PROMO, TOP 1, FIT), precio tachado, "Agregar +".

## 6. Recompensas (Club de Enjambre)

- El botón de recompensas en Home **solo aparece con sesión iniciada**; también se ubica como "ganar puntos".
- Formas de ganar puntos: 1) completar la encuesta de filtros, 2) invitar más gente, 3) cumplir cierta cantidad de pedidos.
- Moneda: Gotas Biffy 🍯 — 700 Gotas ≈ $7.000 COP.
- Racha activa: 7/10 pedidos completados (70%), faltan 3 para almuerzo gratis; barra ámbar.
- Niveles de Enjambre (Temporada UniAndes): N1 · 3 pedidos = Boba Tea o Café gratis (Reclamar); N2 · 6 pedidos = Arepa o Snack gratis (Reclamar); N3 · 10 pedidos = Almuerzo Completo (bloqueado, "Faltan 3 pedidos").
- Actividad Reciente: movimientos de gotas (+100 pedido, +150 bonificación de racha).

## 7. Biffy AI (Decision AI y Chat) — tab 3 del bottom nav

### Biffy Decision AI (pantalla principal)
- Badge "✨ BIFFY DECISION AI 🐝", mascota (abeja) con badge de notificación.
- "¿Qué se te antoja? 🐝" — "Dime qué buscas o deja que analice tu horario y gustos de UniAndes."
- Modos de decisión (seleccionables, badge "N activos"): ⚡ Algo rápido (<10 min), 💰 Económico (<$18k Student Saver), 🥗 Saludable (Keto, proteína o veg), ❤️ Favoritos (tus N pedidos top), 🎲 Sorpréndeme (elección smart), 🍯 Mis gustos (Modo calibrado con los filtros de onboarding).
- Estado "Biffy está pensando…" con mensaje contextual (hueco de horario, antojo) y barra de progreso violeta→ámbar.
- Recomendación: "👀 Creo que esto es perfecto para ti" + badge "98% Match"; foto con plato, edificio y rating; restaurante, tiempo y precio en COP; explicación "💡 ¿Por qué?…"; botones "Pedir ahora ⚡" y "Dame otra opción".
- Nota "Calibrado con tu historial de pedidos en UniAndes".
- **Según el análisis completo del usuario, entrega las 3 mejores opciones** (el prototipo muestra una, habrá carousel/lista de 3).
- Módulo "Chat con Biffy" con botón "Abrir chat →".

### Chat con Biffy
- Encabezado con estado "● En línea"; saludo personalizado + chips de contexto (⚠ Alerta maní, 💧 Sin lactosa); tarjeta "Cómo funciona" (Preferencias / Alergias / Horario).
- Sugerencias rápidas: "Lo más pedido en 24 horas", "Hamburguesas disponibles", "Opciones según mis alergias".
- Composer con comandos sugeridos: "hamburguesas", "sin lactosa", "cerca de ML", "opciones rápidas".
- Respuestas: texto + Nota de seguridad (compatibilidad con alergias) + ranking estructurado (posición, plato, restaurante, tiempo, precio, # pedidos) con chips "Compatible" (verde) / "Revisa alergias" (ámbar).
- El usuario puede describir lo que busca y pedir: qué comida, qué contiene la comida y el precio; Biffy devuelve una lista de opciones.

## Mejoras previstas al construir

- Unificar encabezados, navegación, radios, sombras, espaciado, etiquetas y estados interactivos.
- Diferenciar con claridad recomendaciones, promociones generales y descuentos personales.
- Hacer visibles los cambios de precio y las advertencias por alergias durante la personalización.
- Mantener acciones principales accesibles sin tapar contenido en pantallas móviles.
- Diseñar estados vacíos, carga, error, restaurante cerrado y ausencia de pedido activo.
- Mejorar contraste, tamaño táctil, lectura y retroalimentación de selecciones.
- Conservar el carácter juvenil universitario, evitando que la interfaz se sienta saturada.
- Para el chat: streaming en tiempo real, historial accesible, indicador de escritura y respuestas estructuradas (no texto plano) con advertencias de seguridad.

## Flujo conectado registrado

```text
Home pública
  ├─ Explorar comida/restaurante
  ├─ Detalle de restaurante
  ├─ Detalle de plato y personalización
  └─ Inicio de sesión cuando una acción lo requiera

Home con sesión
  ├─ Pedido activo y seguimiento
  ├─ Recomendaciones según filtros
  ├─ Descuentos, puntos y botón de recompensas
  ├─ Detalle de restaurante
  └─ Detalle de plato → carrito

Biffy AI (con sesión)
  ├─ Modos de decisión → recomendación(es) con % match → Pedir ahora
  └─ Chat con comandos → ranking/lista de opciones con nota de seguridad
```

## Siguiente paso

Continuar recibiendo y analizando las demás secciones. Cuando el usuario diga **“Empezar”**, preparar e implementar el flujo completo con las mejoras acordadas.
