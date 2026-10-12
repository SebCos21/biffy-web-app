export type CardBrand = "visa" | "mastercard" | "amex" | "other";

export function detectCardBrand(num: string): CardBrand {
  const clean = num.replace(/\D/g, "");
  if (/^4/.test(clean)) return "visa";
  if (/^(5[1-5]|222[1-9]|22[3-9]\d|2[3-6]\d{2}|27[01]\d|2720)/.test(clean)) return "mastercard";
  if (/^3[47]/.test(clean)) return "amex";
  return "other";
}

export function formatCardNumber(num: string): string {
  const clean = num.replace(/\D/g, "").slice(0, 16);
  const parts = clean.match(/[\s\S]{1,4}/g);
  return parts ? parts.join(" ") : clean;
}

export function formatExpiry(val: string): string {
  const clean = val.replace(/\D/g, "").slice(0, 4);
  if (clean.length >= 2) {
    const month = parseInt(clean.slice(0, 2), 10);
    const validMonth = Math.min(12, Math.max(1, month)).toString().padStart(2, "0");
    const year = clean.slice(2);
    return year ? `${validMonth}/${year}` : `${validMonth}`;
  }
  return clean;
}

export function luhnCheck(num: string): boolean {
  const clean = num.replace(/\D/g, "");
  if (clean.length < 13 || clean.length > 19) return false;
  let sum = 0;
  let shouldDouble = false;
  for (let i = clean.length - 1; i >= 0; i--) {
    let digit = parseInt(clean.charAt(i), 10);
    if (shouldDouble) {
      digit *= 2;
      if (digit > 9) digit -= 9;
    }
    sum += digit;
    shouldDouble = !shouldDouble;
  }
  return sum % 10 === 0;
}

export function isExpiryValid(exp: string): boolean {
  if (!/^\d{2}\/\d{2}$/.test(exp)) return false;
  const [mStr, yStr] = exp.split("/");
  const month = parseInt(mStr ?? "0", 10);
  const year = 2000 + parseInt(yStr ?? "0", 10);
  if (month < 1 || month > 12) return false;
  const now = new Date();
  const expDate = new Date(year, month, 1);
  return expDate > now;
}

export function getBrandLabel(brand: CardBrand): string {
  switch (brand) {
    case "visa":
      return "Visa";
    case "mastercard":
      return "Mastercard";
    case "amex":
      return "American Express";
    default:
      return "Tarjeta";
  }
}

export function getBrandColor(brand: CardBrand): string {
  switch (brand) {
    case "visa":
      return "from-blue-600 via-indigo-700 to-slate-900";
    case "mastercard":
      return "from-red-600 via-amber-600 to-stone-900";
    case "amex":
      return "from-teal-600 via-cyan-700 to-sky-950";
    default:
      return "from-purple-700 via-indigo-800 to-slate-900";
  }
}
