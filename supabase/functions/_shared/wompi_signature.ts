// Firmas de Wompi: integridad del checkout y checksum de los eventos.
//
// - Integridad: SHA-256 de los campos configurados en el panel + el secreto de
//   integridad. Por defecto: referencia + monto en centavos + moneda.
// - Eventos: SHA-256 de los valores de `signature.properties` (en orden) +
//   `signature.timestamp` + el secreto de eventos. Wompi lo manda en
//   `X-Event-Checksum` y en `signature.checksum`.
export type WompiEvent = {
  event?: string;
  data?: { transaction?: Record<string, unknown> };
  signature?: {
    properties?: string[];
    checksum?: string;
    timestamp?: number;
  };
  environment?: string;
  sent_at?: string;
};

/// SHA-256 en hexadecimal minúscula.
export async function sha256Hex(input: string): Promise<string> {
  const bytes = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(digest)]
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

/// Lee una ruta con puntos (`transaction.id`) de un objeto.
function valueAtPath(source: unknown, path: string): unknown {
  let current: unknown = source;
  for (const part of path.split('.')) {
    if (current === null || typeof current !== 'object') return undefined;
    current = (current as Record<string, unknown>)[part];
  }
  return current;
}

/// Compara dos cadenas sin cortar en el primer byte distinto.
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

/// Firma de integridad para el Checkout Web.
export async function integritySignature(
  reference: string,
  amountInCents: number,
  currency: string,
  secret: string,
): Promise<string> {
  return await sha256Hex(`${reference}${amountInCents}${currency}${secret}`);
}

/// Verifica el checksum de un evento de Wompi.
export async function verifyEventSignature(
  event: WompiEvent,
  headerChecksum: string | null,
  secret: string,
): Promise<boolean> {
  const signature = event.signature;
  if (!signature || !Array.isArray(signature.properties)) return false;
  const timestamp = signature.timestamp;
  if (timestamp === undefined || timestamp === null) return false;

  const values = signature.properties
    // Wompi resuelve las propiedades contra `data` (p. ej. `transaction.id`);
    // si alguna no está ahí se busca en la raíz por compatibilidad.
    .map((path) => {
      const fromData = valueAtPath(event.data, path);
      return fromData === undefined ? valueAtPath(event, path) : fromData;
    })
    .map((value) => value === undefined || value === null ? '' : String(value))
    .join('');
  if (!values) return false;

  const computed = await sha256Hex(`${values}${timestamp}${secret}`);
  const provided = (headerChecksum ?? signature.checksum ?? '').toLowerCase();
  return timingSafeEqual(computed, provided);
}
