# Biffy — Análisis del prototipo (acumulado, sin construir)

## Estado: solo análisis

El usuario está pasando el prototipo por secciones. **No se construye nada hasta que diga "Empezar".** Cuando lo diga, se construirá el flujo completo y además se mejorará (consistencia visual, accesibilidad, estados vacíos/error, advertencias de alergias, controles de precio). Las imágenes son referencia, no recursos para incrustar.

## Stack real del proyecto
TanStack Start + React (Next.js/App Router no es soportado por la plataforma; ya se explicó al usuario). Paleta y tipografías ya configuradas en Tailwind: primary #5E23E3, secondary #F3B428, background #F4F5F9, text-main #1E1E20, accent-green #23A05B, accent-red #E85D57; Sora títulos, Manrope texto.

## Sección 1 — Filtros de onboarding (3 pasos)
Se muestran en dos momentos: al iniciar sesión y en la sección de puntos (completar todo el filtro otorga puntos).

1. **Gustos y antojos** ("Conoce tu gusto favorito"): grid de tarjetas (Hamburguesas, Pizza, Asiático y wok con badge "Favorito de los estudiantes", Mexicano, Saludable, Pollo crujiente, Pasta, Sushi, Postres, Café y panadería). Seleccionadas en violeta con check ámbar. Barra "N antojos seleccionados · IA calibrando tus gustos…" + Continuar. Opción "Saltar".
2. **Estilo de vida y alergias** ("¿Hay algo que debamos saber?"): selección múltiple (Sin restricciones, Vegetariano, Vegano, Sin gluten, Sin lactosa, Otra dieta) y tarjeta ámbar "Alta prioridad" de alergias (Maní, Frutos secos, Mariscos, Soja, Lácteos, + Añadir) con nota "Filtro IA activo: bloquea cualquier contacto con maní". Preferencias ajustables/pausables por menú.
3. **Presupuesto en COP**: $10k–$20k (ahorrador), $20k–$30k (recomendado, punto ideal), $30k–$50k (premium), "Trátate hoy" (sin límites). "Garantía de precios del campus": vales de la universidad y promociones acumulables. Botón "Finalizar configuración".

## Sección 2 — Home, plato y restaurante
- **Home (con sesión):** saludo, campus, seguimiento de pedido activo, recomendación personalizada, descuentos, categorías, restaurantes rápidos, puntos Biffy, botón de recompensas.
- **Home (sin sesión):** exploración pública; pedir sesión al actuar.
- **Detalle de plato:** foto, restaurante, precio, descripción, extras personalizables, cantidad, agregar al carrito.
- **Detalle de restaurante:** datos del local, menú por categorías, platos con precios y agregar, pedidos grupales, resumen de carrito.

## Sección 3 — Explorar / buscador
- Header: logo, selector de campus "UniAndes ML" (dropdown), carrito con badge, avatar.
- "Explora 🍴" + badge "CAMPUS LIVE"; subtítulo "Encuentra tu antojo en campus".
- Buscador con micrófono (voz) y botón de filtros avanzados.
- Chips rápidos: ⚡ Rápido (<15m), 💰 Menos de $20k, ⭐ 4.8+.
- Categorías Populares (scroll horizontal, "Ver todo"): filtra por tipo — todas las pizzas, todas las hamburguesas, etc.
- 🔥 Tendencia en UniAndes ("Top Spots"): tarjetas grandes de restaurante con badge de ubicación, tiempo estimado, rating, cocina, rango de precios COP, "Ver menú →".
- ✨ Platos Destacados ("Pide al instante"): filas con badge (PROMO, TOP 1, FIT), precio tachado, "Agregar +".
- Bottom nav: Inicio, Explorar, Biffy AI, Perfil.

## Sección 4 — Recompensas (Club de Enjambre)
- El botón de recompensas en Home **solo aparece con sesión iniciada**; también se ubica como "ganar puntos".
- Formas de ganar puntos: 1) completar la encuesta de filtros, 2) invitar más gente, 3) cumplir cierta cantidad de pedidos.
- Moneda: Gotas Biffy 🍯 — 700 Gotas ≈ $7.000 COP.
- Racha activa: 7/10 pedidos completados (70%), falta 3 para almuerzo gratis; barra de progreso ámbar.
- Niveles de Enjambre (Temporada UniAndes): N1 · 3 pedidos = Boba Tea o Café gratis (Reclamar); N2 · 6 pedidos = Arepa o Snack gratis (Reclamar); N3 · 10 pedidos = Almuerzo Completo (bloqueado, "Faltan 3 pedidos").
- Actividad Reciente: movimientos de gotas (+100 pedido, +150 bonificación de racha).

## Mejoras pactadas para la implementación
- Advertencias de alergias en platos y checkout, estados vacíos y de error, accesibilidad (contraste, targets táctiles), controles de precio claros, imágenes propias en vez de las del prototipo.

## Siguiente paso
Seguir recibiendo secciones del prototipo. Construir todo solo cuando el usuario diga **"Empezar"**.
