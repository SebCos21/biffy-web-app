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
- Navegación inferior: Inicio, Explorar, Biffy IA y Perfil.

### Usuario sin iniciar sesión
- Puede explorar e interactuar con comidas y restaurantes.
- Puede abrir detalles, consultar información, personalizar platos y avanzar en la experiencia pública.
- No ve recomendaciones calculadas con filtros personales, descuentos personalizados ni progreso de puntos.
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

## Mejoras previstas al construir

- Unificar encabezados, navegación, radios, sombras, espaciado, etiquetas y estados interactivos.
- Diferenciar con claridad recomendaciones, promociones generales y descuentos personales.
- Hacer visibles los cambios de precio y las advertencias por alergias durante la personalización.
- Mantener acciones principales accesibles sin tapar contenido en pantallas móviles.
- Diseñar estados vacíos, carga, error, restaurante cerrado y ausencia de pedido activo.
- Mejorar contraste, tamaño táctil, lectura y retroalimentación de selecciones.
- Conservar el carácter juvenil universitario, evitando que la interfaz se sienta saturada.

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
  ├─ Descuentos y puntos
  ├─ Detalle de restaurante
  └─ Detalle de plato → carrito
```

## Siguiente paso

Continuar recibiendo y analizando las demás secciones. Cuando el usuario diga **“Empezar”**, preparar e implementar el flujo completo con las mejoras acordadas.
