<!-- LOVABLE:BEGIN -->
> [!IMPORTANT]
> This project is connected to [Lovable](https://lovable.dev). Avoid rewriting
> published git history — force pushing, or rebasing/amending/squashing commits
> that are already pushed — as it rewrites history on Lovable's side and the
> user will likely lose their project history.
>
> Commits you push to the connected branch sync back to Lovable and show up in
> the editor, so keep the branch in a working state.
<!-- LOVABLE:END -->

## Architecture rules
- All app state lives in `src/lib/store.tsx` (React Context) over mock data in `src/lib/mock-data.ts`; no backend until the user asks — keeps the prototype fully functional offline.
- Visibility of restaurants/dishes must go through `isReachable` (radius + couriers nearby) via `reachableRestaurants/reachableDishes` — single source for the distance rule.
- Mobile-first touch UI: shared pieces in `src/components/biffy/ui.tsx`; use `active:` states, never rely on hover; carousels use the `no-scrollbar` snap pattern.
- Merchant data lives in store state and is published into the shared mock catalog via `syncCatalog` in `src/lib/merchant.ts` — so client screens and the radius rule see merchant products without a second source.
- Shareable purchase demos use a dedicated entry route and initialize an explicit mock buyer through the shared store; this keeps demo checkout on the normal purchase flow without backend or persistent sessions.
