# Biffy — Análisis del prototipo (sección 1: filtros de onboarding)

## Estado: solo análisis

El usuario está pasando el prototipo por secciones. **No se construye nada hasta que diga "Empezar".** Este documento registra el análisis de la primera sección entregada.

## Lo analizado: flujo de filtros en 3 pasos

Pantallas donde el usuario define gustos, alergias e intolerancias para que la IA filtre resultados. Se muestran en dos momentos: al iniciar sesión (onboarding) y en la sección de puntos para premios (completar todo el filtro otorga puntos).

### Paso 1 — "Conoce tu gusto favorito"
- Header: botón atrás, indicador "Paso 1 de 3", opción "Saltar".
- Biffy Assistant (abeja) como guía: "Dile a Biffy qué te hace feliz el estómago".
- Grid de tarjetas de antojos seleccionables: Hamburguesas, Pizza, Asiático y wok (tarjeta ancha con badge "Favorito de los estudiantes"), Mexicano, Saludable, Pollo crujiente, Pasta, Sushi, Postres, Café y panadería.
- Seleccionadas: fondo violeta primary, borde y check ámbar. No seleccionadas: lavanda claro.
- Barra de estado: "6 antojos seleccionados · IA calibrando tus gustos…" + botón "Continuar".

### Paso 2 — "¿Hay algo que debamos saber?"
- Barra de progreso violeta bajo el header.
- **Estilo de vida** (selección múltiple): Sin restricciones, Vegetariano, Vegano, Sin gluten, Sin lactosa, Otra dieta.
- **Alergias alimentarias** (tarjeta ámbar, badge "Alta prioridad"): Biffy filtra automáticamente ingredientes peligrosos. Chips: Maní (seleccionado), Frutos secos, Mariscos, Soja, Lácteos, "+ Añadir alergia". Nota "Filtro IA activo: bloquea cualquier contacto con maní".
- Aviso: se pueden ajustar o pausar estas preferencias en cada menú.

### Paso 3 — "¿Cuál es tu presupuesto de comida?"
- Cuatro rangos en COP: $10k–$20k (ahorrador estudiante), $20k–$30k (punto ideal, recomendado por Biffy), $30k–$50k (premium), "Trátate hoy" (sin límites).
- Cada tarjeta con descripción y badge contextual (ej. "Más populares en el campus").
- "Garantía de precios del campus": vales de comida de la universidad y acumulación de promociones.
- Botón final: "Finalizar configuración".

## Decisiones de diseño detectadas
- Fondo lavanda muy claro, tarjetas blancas redondeadas con sombra suave.
- Violeta #5E23E3 para selección y acentos; ámbar #F3B428 para checks y badges.
- Emojis como iconografía de categorías; tipografía display en negrita con palabras destacadas en violeta.

## Siguiente paso
Esperar más secciones del prototipo. Cuando el usuario diga **"Empezar"**, se construirá el flujo completo de la app con estas pantallas.
