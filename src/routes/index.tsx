import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "Biffy" },
      {
        name: "description",
        content: "Biffy: tu aplicación, en todos tus dispositivos.",
      },
      { property: "og:title", content: "Biffy" },
      {
        property: "og:description",
        content: "Biffy: tu aplicación, en todos tus dispositivos.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: Index,
});

const palette = [
  { name: "Primary", className: "bg-primary" },
  { name: "Secondary", className: "bg-secondary" },
  { name: "Background", className: "bg-background" },
  { name: "Text main", className: "bg-foreground" },
  { name: "Accent green", className: "bg-success" },
  { name: "Accent red", className: "bg-danger" },
];

function Index() {
  return (
    <main className="flex min-h-screen items-center justify-center bg-background px-6 py-16">
      <div className="w-full max-w-xl text-center">
        <div className="mx-auto flex size-14 items-center justify-center rounded-2xl bg-primary text-3xl font-bold text-primary-foreground">
          B
        </div>
        <h1 className="mt-6 text-5xl font-bold tracking-tight text-foreground">
          Biffy
        </h1>
        <p className="mt-3 text-lg text-muted-foreground">
          El entorno de Biffy está listo. Paleta y tipografías ya configuradas.
        </p>

        <div className="mt-12 grid grid-cols-3 gap-3 sm:grid-cols-6">
          {palette.map((color) => (
            <div key={color.name} className="flex flex-col items-center gap-2">
              <div
                className={`size-12 rounded-xl border border-border shadow-sm ${color.className}`}
              />
              <span className="text-xs font-medium text-muted-foreground">
                {color.name}
              </span>
            </div>
          ))}
        </div>

        <p className="mt-12 text-sm text-muted-foreground">
          Cuéntame qué hace Biffy y construyo las primeras pantallas.
        </p>
      </div>
    </main>
  );
}
