import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { toast } from "sonner";
import { CreditCard, Trash2, ShieldCheck, CheckCircle2, Sparkles, Plus } from "lucide-react";
import { Screen, TopBar, PrimaryButton } from "@/components/biffy/ui";
import { paymentMethodsCatalog } from "@/lib/mock-data";
import { useStore } from "@/lib/store";
import { seo } from "@/lib/seo";
import { cn } from "@/lib/utils";
import {
  detectCardBrand,
  formatCardNumber,
  formatExpiry,
  getBrandLabel,
  getBrandColor,
  isExpiryValid,
  luhnCheck,
} from "@/lib/card-utils";

export const Route = createFileRoute("/pagos")({
  head: () => seo("Métodos de pago", "Administra tus métodos de pago en Biffy."),
  component: Payments,
});

function Payments() {
  const s = useStore();
  const [showAddForm, setShowAddForm] = useState(false);
  const [rawNumber, setRawNumber] = useState("");
  const [holderName, setHolderName] = useState("");
  const [rawExpiry, setRawExpiry] = useState("");
  const [cvv, setCvv] = useState("");
  const [isDefault, setIsDefault] = useState(true);

  const brand = detectCardBrand(rawNumber);
  const formattedNumber = formatCardNumber(rawNumber);
  const formattedExpiry = formatExpiry(rawExpiry);
  const cleanNumber = rawNumber.replace(/\D/g, "");

  const isCardNumberValid = cleanNumber.length >= 15 && luhnCheck(cleanNumber);
  const isExpValid = isExpiryValid(formattedExpiry);
  const isCvvValid = brand === "amex" ? cvv.length === 4 : cvv.length === 3;
  const isHolderValid = holderName.trim().length >= 3;
  const isFormValid = isCardNumberValid && isExpValid && isCvvValid && isHolderValid;

  const handleFillDemo = (type: "visa" | "mc") => {
    if (type === "visa") {
      setRawNumber("4242424242424242");
      setHolderName(s.user?.name || "Sofía Gómez");
      setRawExpiry("1228");
      setCvv("123");
    } else {
      setRawNumber("5555555555554444");
      setHolderName(s.user?.name || "Mateo Díaz");
      setRawExpiry("0927");
      setCvv("987");
    }
    toast.success("Datos de prueba cargados");
  };

  const handleSaveCard = () => {
    if (!isFormValid) {
      if (!isCardNumberValid) toast.error("Número de tarjeta inválido");
      else if (!isHolderValid) toast.error("Ingresa el nombre del titular");
      else if (!isExpValid) toast.error("Fecha de expiración inválida");
      else if (!isCvvValid) toast.error("CVV de seguridad inválido");
      return;
    }

    const [month = "12", year = "28"] = formattedExpiry.split("/");
    s.addCard({
      brand,
      last4: cleanNumber.slice(-4),
      holderName: holderName.trim(),
      expMonth: month,
      expYear: year,
      isDefault,
    });

    // Reset form
    setRawNumber("");
    setHolderName("");
    setRawExpiry("");
    setCvv("");
    setShowAddForm(false);
    toast.success("¡Tarjeta agregada y verificada!");
  };

  return (
    <Screen nav={false} className="pb-16">
      <TopBar title="Métodos de pago" />
      <div className="space-y-5 px-4">
        {/* Banner de seguridad */}
        <div className="flex items-center gap-3 rounded-2xl bg-primary/10 p-3.5 text-xs text-primary">
          <ShieldCheck className="size-5 shrink-0" />
          <p>Tus pagos están protegidos con encriptación SSL de 256 bits y cumplimiento PCI-DSS.</p>
        </div>

        {/* Tarjetas de crédito/débito guardadas */}
        <section className="space-y-3">
          <div className="flex items-center justify-between">
            <h2 className="text-sm font-bold text-muted-foreground uppercase tracking-wider">Mis Tarjetas</h2>
            {!showAddForm && (
              <button
                onClick={() => setShowAddForm(true)}
                className="flex items-center gap-1 text-xs font-bold text-primary active:scale-95"
              >
                <Plus className="size-4" /> Agregar nueva
              </button>
            )}
          </div>

          {s.cards.length === 0 && !showAddForm && (
            <div className="rounded-2xl border border-dashed p-6 text-center">
              <CreditCard className="mx-auto size-8 text-muted-foreground opacity-50" />
              <p className="mt-2 text-sm font-semibold">No tienes tarjetas guardadas</p>
              <p className="text-xs text-muted-foreground">Agrega una tarjeta para pagar más rápido tus pedidos.</p>
              <button
                onClick={() => setShowAddForm(true)}
                className="mt-3 inline-flex items-center gap-1.5 rounded-xl bg-primary px-4 py-2 text-xs font-bold text-primary-foreground active:scale-95"
              >
                <Plus className="size-4" /> Agregar tarjeta
              </button>
            </div>
          )}

          {s.cards.map((card) => {
            const isSelected = s.defaultPayment === card.id;
            return (
              <div
                key={card.id}
                className={cn(
                  "relative flex items-center gap-3 rounded-2xl border bg-card p-4 transition-all shadow-sm",
                  isSelected && "border-primary ring-2 ring-primary/20",
                )}
              >
                <button
                  onClick={() => s.setDefaultCard(card.id)}
                  className="flex flex-1 items-center gap-3 text-left"
                >
                  <div
                    className={cn(
                      "grid size-12 shrink-0 place-items-center rounded-xl bg-gradient-to-br text-white font-black text-xs shadow-sm",
                      getBrandColor(card.brand),
                    )}
                  >
                    {card.brand === "visa"
                      ? "VISA"
                      : card.brand === "mastercard"
                        ? "MC"
                        : card.brand === "amex"
                          ? "AMEX"
                          : "CARD"}
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2">
                      <p className="font-bold text-sm">
                        {getBrandLabel(card.brand)} •••• {card.last4}
                      </p>
                      {isSelected && (
                        <span className="rounded-full bg-primary/15 px-2 py-0.5 text-[10px] font-extrabold text-primary">
                          Por defecto
                        </span>
                      )}
                    </div>
                    <p className="text-xs text-muted-foreground truncate">
                      {card.holderName} · Vence {card.expMonth}/{card.expYear}
                    </p>
                  </div>
                </button>

                <button
                  onClick={() => s.removeCard(card.id)}
                  aria-label="Eliminar tarjeta"
                  className="grid size-9 place-items-center rounded-full text-muted-foreground hover:text-danger active:scale-90"
                >
                  <Trash2 className="size-4" />
                </button>
              </div>
            );
          })}
        </section>

        {/* Formulario Interactivo para Agregar Tarjeta */}
        {showAddForm && (
          <section className="rounded-3xl border bg-card p-5 shadow-sm space-y-4 animate-in fade-in slide-in-from-top-3 duration-200">
            <div className="flex items-center justify-between">
              <h3 className="font-extrabold text-base">Nueva Tarjeta</h3>
              <button
                onClick={() => setShowAddForm(false)}
                className="text-xs font-semibold text-muted-foreground hover:text-foreground"
              >
                Cancelar
              </button>
            </div>

            {/* Tarjeta Visual de Previsualización */}
            <div
              className={cn(
                "relative h-44 w-full rounded-2xl bg-gradient-to-tr p-5 text-white shadow-lg transition-all duration-300 flex flex-col justify-between overflow-hidden",
                getBrandColor(brand),
              )}
            >
              {/* Elementos decorativos */}
              <div className="absolute -right-12 -top-12 size-36 rounded-full bg-white/10 blur-xl pointer-events-none" />
              <div className="absolute -left-10 -bottom-10 size-36 rounded-full bg-black/20 blur-xl pointer-events-none" />

              <div className="flex items-start justify-between z-10">
                <div className="flex items-center gap-2">
                  <div className="h-6 w-9 rounded-md bg-amber-300/80 border border-amber-200/50 flex items-center justify-center shadow-inner">
                    <div className="h-3 w-5 border border-amber-600/40 rounded-sm" />
                  </div>
                  <span className="text-[11px] font-mono tracking-widest uppercase opacity-80">BIFFY PAY</span>
                </div>
                <span className="font-black text-sm tracking-widest uppercase">
                  {brand === "visa"
                    ? "VISA"
                    : brand === "mastercard"
                      ? "MasterCard"
                      : brand === "amex"
                        ? "AMEX"
                        : "DEBIT / CREDIT"}
                </span>
              </div>

              <div className="my-auto z-10">
                <p className="font-mono text-lg tracking-[0.2em] font-semibold drop-shadow-sm">
                  {formattedNumber || "•••• •••• •••• ••••"}
                </p>
              </div>

              <div className="flex justify-between items-end z-10 text-[11px] uppercase tracking-wider">
                <div className="max-w-[70%] truncate">
                  <span className="block text-[9px] opacity-75">TITULAR</span>
                  <span className="font-semibold">{holderName || "NOMBRE Y APELLIDO"}</span>
                </div>
                <div>
                  <span className="block text-[9px] opacity-75">VENCE</span>
                  <span className="font-semibold">{formattedExpiry || "MM/AA"}</span>
                </div>
              </div>
            </div>

            {/* Botones de autofill de prueba */}
            <div className="flex items-center gap-2 pt-1">
              <span className="text-xs text-muted-foreground flex items-center gap-1 font-semibold">
                <Sparkles className="size-3.5 text-secondary" /> Prueba rápida:
              </span>
              <button
                type="button"
                onClick={() => handleFillDemo("visa")}
                className="rounded-lg bg-blue-500/10 px-2.5 py-1 text-xs font-bold text-blue-600 active:scale-95"
              >
                Visa demo
              </button>
              <button
                type="button"
                onClick={() => handleFillDemo("mc")}
                className="rounded-lg bg-red-500/10 px-2.5 py-1 text-xs font-bold text-red-600 active:scale-95"
              >
                Mastercard demo
              </button>
            </div>

            {/* Inputs del formulario */}
            <div className="space-y-3">
              <div>
                <label className="text-xs font-bold text-muted-foreground">Número de tarjeta</label>
                <div className="relative mt-1">
                  <input
                    value={formattedNumber}
                    onChange={(e) => setRawNumber(e.target.value)}
                    inputMode="numeric"
                    placeholder="1234 5678 9012 3456"
                    className="w-full rounded-xl border bg-background p-3 font-mono text-sm tracking-wider focus:outline-none focus:ring-2 focus:ring-primary"
                  />
                  {isCardNumberValid && (
                    <CheckCircle2 className="absolute right-3 top-3.5 size-4 text-success" />
                  )}
                </div>
              </div>

              <div>
                <label className="text-xs font-bold text-muted-foreground">Nombre en la tarjeta</label>
                <input
                  value={holderName}
                  onChange={(e) => setHolderName(e.target.value)}
                  placeholder="Como aparece en el plástico"
                  autoCapitalize="characters"
                  className="mt-1 w-full rounded-xl border bg-background p-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-bold text-muted-foreground">Expiración (MM/AA)</label>
                  <input
                    value={formattedExpiry}
                    onChange={(e) => setRawExpiry(e.target.value)}
                    inputMode="numeric"
                    placeholder="MM/AA"
                    maxLength={5}
                    className="mt-1 w-full rounded-xl border bg-background p-3 font-mono text-sm tracking-wider focus:outline-none focus:ring-2 focus:ring-primary"
                  />
                </div>
                <div>
                  <label className="text-xs font-bold text-muted-foreground">
                    Código CVC / CVV
                  </label>
                  <input
                    value={cvv}
                    onChange={(e) => setCvv(e.target.value.replace(/\D/g, "").slice(0, 4))}
                    inputMode="numeric"
                    placeholder={brand === "amex" ? "4 dígitos" : "3 dígitos"}
                    maxLength={4}
                    className="mt-1 w-full rounded-xl border bg-background p-3 font-mono text-sm tracking-wider focus:outline-none focus:ring-2 focus:ring-primary"
                  />
                </div>
              </div>

              <label className="flex items-center gap-2 pt-1 cursor-pointer">
                <input
                  type="checkbox"
                  checked={isDefault}
                  onChange={(e) => setIsDefault(e.target.checked)}
                  className="rounded border-muted text-primary focus:ring-primary size-4"
                />
                <span className="text-xs font-semibold">Guardar como método preferido de pago</span>
              </label>

              <PrimaryButton onClick={handleSaveCard} className="mt-2 w-full">
                Guardar y verificar tarjeta
              </PrimaryButton>
            </div>
          </section>
        )}

        {/* Otros Métodos de Pago */}
        <section className="space-y-2 pt-2">
          <h2 className="text-sm font-bold text-muted-foreground uppercase tracking-wider">Otros Métodos</h2>
          {paymentMethodsCatalog
            .filter((m) => m.id !== "card")
            .map((m) => {
              const isSelected = s.defaultPayment === m.id;
              return (
                <button
                  key={m.id}
                  onClick={() => {
                    s.setDefaultPayment(m.id);
                    toast.success(`${m.label} seleccionado por defecto`);
                  }}
                  className={cn(
                    "flex w-full items-center gap-3 rounded-2xl border bg-card p-4 active:scale-[0.99] transition-all",
                    isSelected && "border-primary ring-2 ring-primary/20",
                  )}
                >
                  <span className="text-2xl">{m.emoji}</span>
                  <span className="flex-1 text-left font-semibold">{m.label}</span>
                  {isSelected && (
                    <span className="rounded-full bg-primary/15 px-2.5 py-0.5 text-xs font-bold text-primary">
                      Por defecto
                    </span>
                  )}
                </button>
              );
            })}
        </section>
      </div>
    </Screen>
  );
}
