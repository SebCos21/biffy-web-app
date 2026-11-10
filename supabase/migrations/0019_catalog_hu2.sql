-- ============================================================================
-- 0019 · HU-2 · Catálogo y gestión del comercio en tiempo real
-- ============================================================================
-- Es idempotente: se puede volver a ejecutar sin efectos secundarios.
-- Si una migración futura vuelve a hacer `grant ... delete on all tables`,
-- hay que repetir los `revoke` de la sección 2.
-- ============================================================================

-- 1) Revisión del catálogo (una sola fila; lo importante es que cambie, para
-- que Realtime emita un UPDATE visible para todos).
create table if not exists public.catalog_revision (
  id int primary key default 1 check (id = 1),
  rev bigint not null default 0,
  updated_at timestamptz not null default now()
);

insert into public.catalog_revision (id) values (1) on conflict do nothing;

alter table public.catalog_revision enable row level security;

drop policy if exists catalog_revision_read on public.catalog_revision;
create policy catalog_revision_read on public.catalog_revision
  for select to anon, authenticated using (true);

revoke all on public.catalog_revision from anon, authenticated;
grant select on public.catalog_revision to anon, authenticated;

create or replace function public.bump_catalog_revision()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.catalog_revision
     set rev = rev + 1,
         updated_at = now()
   where id = 1;
  return null;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array['branches', 'dishes', 'dish_options'] loop
    execute format(
      'drop trigger if exists bump_catalog_revision on public.%I', t);
    execute format(
      'create trigger bump_catalog_revision
         after insert or update or delete on public.%I
         for each statement execute function public.bump_catalog_revision()', t);
  end loop;
end $$;

do $$
declare
  t text;
begin
  foreach t in array array['dish_options', 'catalog_revision'] loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
      raise notice 'Realtime habilitado para public.%.', t;
    exception
      when duplicate_object then
        null;
      when undefined_object then
        raise notice 'No existe la publicación supabase_realtime; se omite %.', t;
    end;
  end loop;
end $$;

-- 2) Borrado lógico obligatorio. NO separar branches_write/dishes_write en
-- insert/update: son las que dejan al dueño marcar deleted_at (la fila nueva
-- debe seguir siendo visible para él). Solo se quita el privilegio DELETE.
revoke delete on public.businesses from authenticated;
revoke delete on public.branches from authenticated;
revoke delete on public.dishes from authenticated;

-- 3) Datos públicos del negocio (la vista corre con permisos de su dueño a
-- propósito: es la única puerta pública a `businesses`).
drop view if exists public.businesses_public;
create view public.businesses_public as
select id, brand, cuisine, description
from public.businesses;

revoke all on public.businesses_public from anon, authenticated;
grant select on public.businesses_public to anon, authenticated;

-- 4) Opciones de platos ocultos: pasan por dishes_read.
drop policy if exists dish_options_read on public.dish_options;
create policy dish_options_read on public.dish_options
  for select to anon, authenticated
  using (
    exists (select 1 from public.dishes d where d.id = dish_options.dish_id)
  );

-- 5) Bucket dish-images: 5 MiB, solo imágenes, y WITH CHECK al renombrar.
update storage.buckets
   set file_size_limit = 5242880,
       allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
 where id = 'dish-images';

drop policy if exists dish_images_update on storage.objects;
create policy dish_images_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'dish-images'
    and (storage.foldername(name))[1] = public.my_business_id()::text
  )
  with check (
    bucket_id = 'dish-images'
    and (storage.foldername(name))[1] = public.my_business_id()::text
  );
