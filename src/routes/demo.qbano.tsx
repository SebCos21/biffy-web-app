import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { Share2, Sparkles, UtensilsCrossed } from "lucide-react";
import { toast } from "sonner";
import { Screen, TopBar, PrimaryButton } from "@/components/biffy/ui";
import { useStore } from "@/lib/store";
import { seo } from "@/lib/seo";
import sandwich from "@/assets/demo-qbano-sandwich.jpg";

export const Route = createFileRoute("/demo/qbano")({
  head: () => seo("Qbano en Icesi · Demostración", "Prueba una compra simulada de Qbano con Biffy AI y entrega programada dentro de Icesi."),
  component: QbanoDemo,
});

function QbanoDemo() {
  const s = useStore();
  const navigate = useNavigate();
  const start = (ai: boolean) => {
    s.startQbanoDemo();
    if (ai) navigate({ to: "/ai" });
    else navigate({ to: "/restaurante/$id", params: { id: "qbano-icesi" } });
  };
  const share = async () => {
    const url = `${window.location.origin}/demo/qbano`;
    try {
      if (navigator.share) await navigator.share({ title: "Qbano en Icesi · Biffy demo", url });
      else { await navigator.clipboard.writeText(url); toast.success("Enlace copiado"); }
    } catch { toast("No se compartió el enlace"); }
  };
  return (
    <Screen nav={false}>
      <TopBar title="Qbano · Icesi" />
      <img src={sandwich} alt="Sándwich ilustrativo para la demostración de Qbano" width={1024} height={768} className="aspect-[4/3] w-full object-cover" />
      <div className="space-y-4 px-4 pt-5">
        <p className="text-xs font-bold text-success">UNIVERSIDAD ICESI · CALI</p>
        <h1 className="text-3xl font-extrabold">Qbano en Icesi</h1>
        <div className="flex justify-between border-y py-3 text-sm"><span>Compradora de ejemplo</span><b>Valentina · Icesi</b></div>
        <p className="text-sm text-muted-foreground">Demostración sin cobros ni entregas reales. Menú, precios, horarios, sede y foto ilustrativos; no son información oficial de Qbano. El pedido se conserva mientras esta página permanezca abierta.</p>
        <PrimaryButton onClick={() => start(true)}><Sparkles className="size-5" /> Pedir con Biffy AI</PrimaryButton>
        <PrimaryButton className="bg-card text-foreground border" onClick={() => start(false)}><UtensilsCrossed className="size-5" /> Ver menú de Qbano</PrimaryButton>
        <PrimaryButton className="bg-muted text-foreground" onClick={share}><Share2 className="size-5" /> Compartir ejemplo</PrimaryButton>
      </div>
    </Screen>
  );
}