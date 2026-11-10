-- ============================================================================
-- HU-2 · Pruebas de RLS del catálogo entre comercios (SQL Editor)
-- ============================================================================
-- Uso: Supabase Dashboard -> SQL Editor -> pegar todo -> Run.
-- Requiere 0019_catalog_hu2.sql aplicada. Todo corre dentro de
-- `begin ... rollback`: no deja datos. Si algo falla se detiene con
-- `FALLO: ...`; si todo pasa termina con el aviso `OK n`.
--
-- Actores (ids fijos, solo existen dentro de la transacción):
--   A  comercio   a0000000-...-000000000001  negocio a...b1, sede a...c1
--   B  comercio   b0000000-...-000000000001  negocio b...b1, sede b...c1
--   C  comprador  c0000000-...-000000000001
--
-- Cada bloque fija el JWT con `request.jwt.claims` y cambia de rol con
-- `set local role`; al terminar vuelve a `postgres` con `reset role`.
-- ============================================================================

begin;

-- ------------------------------------------------------------- Preparación
-- Corre como postgres: crea usuarios, negocios, sedes, platos, opciones y
-- objetos de Storage de partida.
do $$
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
  ) values
    ('00000000-0000-0000-0000-000000000000',
     'a0000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated',
     'hu2.comercio.a@test.biffy.co', '', '{}'::jsonb,
     '{"role":"restaurant","full_name":"Comercio A"}'::jsonb, now(), now()),
    ('00000000-0000-0000-0000-000000000000',
     'b0000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated',
     'hu2.comercio.b@test.biffy.co', '', '{}'::jsonb,
     '{"role":"restaurant","full_name":"Comercio B"}'::jsonb, now(), now()),
    ('00000000-0000-0000-0000-000000000000',
     'c0000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated',
     'hu2.comprador@test.biffy.co', '', '{}'::jsonb,
     '{"role":"buyer","full_name":"Comprador C"}'::jsonb, now(), now());

  insert into public.businesses (id, owner_id, brand, bank_name, account_number)
  values
    ('a0000000-0000-4000-8000-0000000000b1',
     'a0000000-0000-4000-8000-000000000001', 'HU2 A', 'Banco A', '1111'),
    ('b0000000-0000-4000-8000-0000000000b1',
     'b0000000-0000-4000-8000-000000000001', 'HU2 B', 'Banco B', '2222');

  -- El guardia de perfiles solo deja fijar business_id en modo interno.
  perform set_config('biffy.internal', '1', true);
  update public.profiles
     set business_id = 'a0000000-0000-4000-8000-0000000000b1'
   where id = 'a0000000-0000-4000-8000-000000000001';
  update public.profiles
     set business_id = 'b0000000-0000-4000-8000-0000000000b1'
   where id = 'b0000000-0000-4000-8000-000000000001';
  perform set_config('biffy.internal', '0', true);

  insert into public.branches (id, business_id, name, deleted_at) values
    ('a0000000-0000-4000-8000-0000000000c1',
     'a0000000-0000-4000-8000-0000000000b1', 'A sede', null),
    ('a0000000-0000-4000-8000-0000000000c2',
     'a0000000-0000-4000-8000-0000000000b1', 'A sede borrada', now()),
    ('b0000000-0000-4000-8000-0000000000c1',
     'b0000000-0000-4000-8000-0000000000b1', 'B sede', null);

  insert into public.dishes (id, branch_id, name, price, category_id, active)
  values
    ('a0000000-0000-4000-8000-0000000000d1',
     'a0000000-0000-4000-8000-0000000000c1', 'A activo', 10000, 'almuerzo', true),
    ('a0000000-0000-4000-8000-0000000000d2',
     'a0000000-0000-4000-8000-0000000000c1', 'A pausado', 10000, 'almuerzo', false),
    ('b0000000-0000-4000-8000-0000000000d1',
     'b0000000-0000-4000-8000-0000000000c1', 'B activo', 10000, 'almuerzo', true);

  insert into public.dish_options (id, dish_id, kind, label, price_delta) values
    ('a0000000-0000-4000-8000-0000000000e1',
     'a0000000-0000-4000-8000-0000000000d1', 'size', 'Grande', 2000),
    ('a0000000-0000-4000-8000-0000000000e2',
     'a0000000-0000-4000-8000-0000000000d2', 'size', 'Grande', 2000),
    ('b0000000-0000-4000-8000-0000000000e1',
     'b0000000-0000-4000-8000-0000000000d1', 'size', 'Grande', 2000);

  insert into storage.objects (bucket_id, name) values
    ('dish-images', 'b0000000-0000-4000-8000-0000000000b1/b.jpg'),
    ('merchant-docs', 'a0000000-0000-4000-8000-0000000000b1/rut.pdf');

  perform set_config('hu2.ok', '0', true);
end $$;

-- ------------------------------------- 1) A no toca nada del comercio B
do $$
declare
  n int;
  ok int := 0;
begin
  perform set_config('request.jwt.claims',
    '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
  set local role authenticated;

  update public.branches set name = 'hackeada'
   where id = 'b0000000-0000-4000-8000-0000000000c1';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FALLO: A editó la sede de B'; end if;
  ok := ok + 1;

  update public.dishes set price = 1
   where id = 'b0000000-0000-4000-8000-0000000000d1';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FALLO: A editó un plato de B'; end if;
  ok := ok + 1;

  update public.dish_options set label = 'hackeada'
   where id = 'b0000000-0000-4000-8000-0000000000e1';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FALLO: A editó una opción de B'; end if;
  ok := ok + 1;

  begin
    insert into public.branches (business_id, name)
    values ('b0000000-0000-4000-8000-0000000000b1', 'intrusa');
    raise exception 'FALLO: A creó una sede en el negocio de B';
  exception when insufficient_privilege then
    ok := ok + 1;
  end;

  begin
    insert into public.dishes (branch_id, name, price, category_id)
    values ('b0000000-0000-4000-8000-0000000000c1', 'intruso', 1, 'almuerzo');
    raise exception 'FALLO: A creó un plato en la sede de B';
  exception when insufficient_privilege then
    ok := ok + 1;
  end;

  begin
    insert into public.dish_options (dish_id, kind, label)
    values ('b0000000-0000-4000-8000-0000000000d1', 'extra', 'intrusa');
    raise exception 'FALLO: A creó una opción en un plato de B';
  exception when insufficient_privilege then
    ok := ok + 1;
  end;

  begin
    update public.dishes set branch_id = 'b0000000-0000-4000-8000-0000000000c1'
     where id = 'a0000000-0000-4000-8000-0000000000d1';
    raise exception 'FALLO: A movió su plato a la sede de B';
  exception when insufficient_privilege then
    ok := ok + 1;
  end;

  reset role;
  perform set_config('hu2.ok', (current_setting('hu2.ok')::int + ok)::text, true);
end $$;

-- ------------------- 2) A gestiona lo suyo; el DELETE duro está prohibido
do $$
declare
  n int;
  ok int := 0;
begin
  perform set_config('request.jwt.claims',
    '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
  set local role authenticated;

  insert into public.branches (id, business_id, name)
  values ('a0000000-0000-4000-8000-0000000000c3',
          'a0000000-0000-4000-8000-0000000000b1', 'A sede nueva');
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FALLO: A no pudo crear su sede'; end if;
  ok := ok + 1;

  insert into public.dishes (id, branch_id, name, price, category_id)
  values ('a0000000-0000-4000-8000-0000000000d3',
          'a0000000-0000-4000-8000-0000000000c1', 'A nuevo', 12000, 'almuerzo');
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FALLO: A no pudo crear su plato'; end if;
  ok := ok + 1;

  insert into public.dish_options (dish_id, kind, label, price_delta)
  values ('a0000000-0000-4000-8000-0000000000d3', 'extra', 'Queso', 1500);
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FALLO: A no pudo crear su opción'; end if;
  ok := ok + 1;

  update public.dishes set price = 13000
   where id = 'a0000000-0000-4000-8000-0000000000d3';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FALLO: A no pudo editar su plato'; end if;
  ok := ok + 1;

  update public.dishes set sold_out = true
   where id = 'a0000000-0000-4000-8000-0000000000d1';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FALLO: A no pudo agotar su plato'; end if;
  ok := ok + 1;

  update public.branches set paused = true
   where id = 'a0000000-0000-4000-8000-0000000000c3';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FALLO: A no pudo pausar su sede'; end if;
  ok := ok + 1;

  update public.dishes set deleted_at = now()
   where id = 'a0000000-0000-4000-8000-0000000000d3';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FALLO: A no pudo borrar (lógico) su plato'; end if;
  ok := ok + 1;

  update public.branches set deleted_at = now()
   where id = 'a0000000-0000-4000-8000-0000000000c3';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FALLO: A no pudo borrar (lógico) su sede'; end if;
  ok := ok + 1;

  begin
    delete from public.dishes where id = 'a0000000-0000-4000-8000-0000000000d1';
    raise exception 'FALLO: A borró de forma definitiva un plato';
  exception when insufficient_privilege then
    ok := ok + 1;
  end;

  begin
    delete from public.branches where id = 'a0000000-0000-4000-8000-0000000000c1';
    raise exception 'FALLO: A borró de forma definitiva una sede';
  exception when insufficient_privilege then
    ok := ok + 1;
  end;

  begin
    delete from public.businesses where id = 'a0000000-0000-4000-8000-0000000000b1';
    raise exception 'FALLO: A borró de forma definitiva su negocio';
  exception when insufficient_privilege then
    ok := ok + 1;
  end;

  reset role;
  perform set_config('hu2.ok', (current_setting('hu2.ok')::int + ok)::text, true);
end $$;

-- ------------- 3) El comprador solo ve lo publicado y sin borrado lógico
do $$
declare
  n int;
  ok int := 0;
begin
  perform set_config('request.jwt.claims',
    '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
  set local role authenticated;

  select count(*) into n from public.dishes
   where id = 'a0000000-0000-4000-8000-0000000000d1';
  if n <> 1 then raise exception 'FALLO: el comprador no ve un plato activo'; end if;
  ok := ok + 1;

  select count(*) into n from public.dishes
   where id = 'a0000000-0000-4000-8000-0000000000d2';
  if n <> 0 then raise exception 'FALLO: el comprador ve un plato pausado'; end if;
  ok := ok + 1;

  select count(*) into n from public.dishes
   where id = 'a0000000-0000-4000-8000-0000000000d3';
  if n <> 0 then raise exception 'FALLO: el comprador ve un plato borrado'; end if;
  ok := ok + 1;

  select count(*) into n from public.branches
   where id in ('a0000000-0000-4000-8000-0000000000c2',
                'a0000000-0000-4000-8000-0000000000c3');
  if n <> 0 then raise exception 'FALLO: el comprador ve sedes borradas'; end if;
  ok := ok + 1;

  select count(*) into n from public.branches
   where id = 'a0000000-0000-4000-8000-0000000000c1';
  if n <> 1 then raise exception 'FALLO: el comprador no ve una sede activa'; end if;
  ok := ok + 1;

  select count(*) into n from public.dish_options
   where id = 'a0000000-0000-4000-8000-0000000000e2';
  if n <> 0 then
    raise exception 'FALLO: el comprador ve opciones de un plato pausado';
  end if;
  ok := ok + 1;

  select count(*) into n from public.dish_options
   where id = 'a0000000-0000-4000-8000-0000000000e1';
  if n <> 1 then
    raise exception 'FALLO: el comprador no ve opciones de un plato activo';
  end if;
  ok := ok + 1;

  reset role;
  perform set_config('hu2.ok', (current_setting('hu2.ok')::int + ok)::text, true);
end $$;

-- ------------------ 4) Datos privados del negocio y vista pública mínima
do $$
declare
  n int;
  ok int := 0;
  cols text[];
begin
  select array_agg(column_name::text order by ordinal_position) into cols
    from information_schema.columns
   where table_schema = 'public' and table_name = 'businesses_public';
  if cols is distinct from array['id', 'brand', 'cuisine', 'description'] then
    raise exception 'FALLO: businesses_public expone %', cols;
  end if;
  ok := ok + 1;

  -- Comprador: no lee la tabla, sí la vista; no lee documentos de A.
  perform set_config('request.jwt.claims',
    '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
  set local role authenticated;

  select count(*) into n from public.businesses
   where id = 'a0000000-0000-4000-8000-0000000000b1';
  if n <> 0 then raise exception 'FALLO: el comprador lee businesses de A'; end if;
  ok := ok + 1;

  select count(*) into n from public.businesses_public
   where id = 'a0000000-0000-4000-8000-0000000000b1';
  if n <> 1 then raise exception 'FALLO: el comprador no lee businesses_public'; end if;
  ok := ok + 1;

  select count(*) into n from storage.objects
   where bucket_id = 'merchant-docs'
     and name like 'a0000000-0000-4000-8000-0000000000b1/%';
  if n <> 0 then raise exception 'FALLO: el comprador lee merchant-docs de A'; end if;
  ok := ok + 1;

  -- Comercio B: tampoco.
  perform set_config('request.jwt.claims',
    '{"sub":"b0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);

  select count(*) into n from public.businesses
   where id = 'a0000000-0000-4000-8000-0000000000b1';
  if n <> 0 then raise exception 'FALLO: B lee businesses de A'; end if;
  ok := ok + 1;

  select count(*) into n from storage.objects
   where bucket_id = 'merchant-docs'
     and name like 'a0000000-0000-4000-8000-0000000000b1/%';
  if n <> 0 then raise exception 'FALLO: B lee merchant-docs de A'; end if;
  ok := ok + 1;

  -- Comercio A: sí ve lo suyo (control positivo).
  perform set_config('request.jwt.claims',
    '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);

  select count(*) into n from public.businesses
   where id = 'a0000000-0000-4000-8000-0000000000b1';
  if n <> 1 then raise exception 'FALLO: A no lee su propio negocio'; end if;
  ok := ok + 1;

  -- Anónimo: la tabla no devuelve filas (o ni siquiera tiene permiso).
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  set local role anon;
  begin
    select count(*) into n from public.businesses;
    if n <> 0 then raise exception 'FALLO: anon lee la tabla businesses'; end if;
  exception when insufficient_privilege then
    null;
  end;
  ok := ok + 1;

  reset role;
  perform set_config('hu2.ok', (current_setting('hu2.ok')::int + ok)::text, true);
end $$;

-- ------------------------------- 5) catalog_revision sube y es de solo lectura
do $$
declare
  r0 bigint;
  r1 bigint;
  ok int := 0;
begin
  perform set_config('request.jwt.claims',
    '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
  set local role authenticated;

  select rev into r0 from public.catalog_revision where id = 1;
  if r0 is null then raise exception 'FALLO: catalog_revision no es legible'; end if;

  update public.dishes set price = price + 1
   where id = 'a0000000-0000-4000-8000-0000000000d1';
  select rev into r1 from public.catalog_revision where id = 1;
  if r1 <= r0 then raise exception 'FALLO: editar un plato no sube la revisión'; end if;
  ok := ok + 1;

  r0 := r1;
  update public.dish_options set label = 'Extra grande'
   where id = 'a0000000-0000-4000-8000-0000000000e1';
  select rev into r1 from public.catalog_revision where id = 1;
  if r1 <= r0 then raise exception 'FALLO: editar una opción no sube la revisión'; end if;
  ok := ok + 1;

  r0 := r1;
  update public.branches set tagline = 'Nueva frase'
   where id = 'a0000000-0000-4000-8000-0000000000c1';
  select rev into r1 from public.catalog_revision where id = 1;
  if r1 <= r0 then raise exception 'FALLO: editar una sede no sube la revisión'; end if;
  ok := ok + 1;

  perform set_config('request.jwt.claims',
    '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);

  begin
    update public.catalog_revision set rev = 0 where id = 1;
    raise exception 'FALLO: el comprador escribió catalog_revision';
  exception when insufficient_privilege then
    ok := ok + 1;
  end;

  begin
    insert into public.catalog_revision (id, rev) values (1, 0)
    on conflict (id) do update set rev = 0;
    raise exception 'FALLO: el comprador insertó en catalog_revision';
  exception when insufficient_privilege then
    ok := ok + 1;
  end;

  reset role;
  perform set_config('hu2.ok', (current_setting('hu2.ok')::int + ok)::text, true);
end $$;

-- --------------------------------------------- 6) Favoritos privados
do $$
declare
  n int;
  ok int := 0;
begin
  set local role authenticated;

  -- A marca un favorito suyo.
  perform set_config('request.jwt.claims',
    '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
  insert into public.favorite_dishes (user_id, dish_id)
  values ('a0000000-0000-4000-8000-000000000001',
          'b0000000-0000-4000-8000-0000000000d1');

  -- El comprador marca los suyos.
  perform set_config('request.jwt.claims',
    '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
  insert into public.favorite_dishes (user_id, dish_id)
  values ('c0000000-0000-4000-8000-000000000001',
          'a0000000-0000-4000-8000-0000000000d1');
  insert into public.favorite_branches (user_id, branch_id)
  values ('c0000000-0000-4000-8000-000000000001',
          'a0000000-0000-4000-8000-0000000000c1');

  select count(*) into n from public.favorite_dishes
   where user_id <> 'c0000000-0000-4000-8000-000000000001';
  if n <> 0 then raise exception 'FALLO: el comprador ve favoritos ajenos'; end if;
  ok := ok + 1;

  select count(*) into n from public.favorite_dishes;
  if n <> 1 then raise exception 'FALLO: el comprador no ve su favorito'; end if;
  ok := ok + 1;

  begin
    insert into public.favorite_dishes (user_id, dish_id)
    values ('a0000000-0000-4000-8000-000000000001',
            'a0000000-0000-4000-8000-0000000000d1');
    raise exception 'FALLO: el comprador creó un favorito a nombre de A';
  exception when insufficient_privilege then
    ok := ok + 1;
  end;

  begin
    insert into public.favorite_branches (user_id, branch_id)
    values ('a0000000-0000-4000-8000-000000000001',
            'b0000000-0000-4000-8000-0000000000c1');
    raise exception 'FALLO: el comprador creó una sede favorita a nombre de A';
  exception when insufficient_privilege then
    ok := ok + 1;
  end;

  -- A solo ve el suyo.
  perform set_config('request.jwt.claims',
    '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
  select count(*) into n from public.favorite_dishes
   where user_id <> 'a0000000-0000-4000-8000-000000000001';
  if n <> 0 then raise exception 'FALLO: A ve favoritos ajenos'; end if;
  ok := ok + 1;

  select count(*) into n from public.favorite_branches;
  if n <> 0 then raise exception 'FALLO: A ve sedes favoritas ajenas'; end if;
  ok := ok + 1;

  reset role;
  perform set_config('hu2.ok', (current_setting('hu2.ok')::int + ok)::text, true);
end $$;

-- ------------------------------------------ 7) Storage dish-images por carpeta
-- Storage bloquea los DELETE directos por SQL salvo con esta bandera.
select set_config('storage.allow_delete_query', 'true', true);

do $$
declare
  n int;
  ok int := 0;
begin
  perform set_config('request.jwt.claims',
    '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
  set local role authenticated;

  insert into storage.objects (bucket_id, name)
  values ('dish-images', 'a0000000-0000-4000-8000-0000000000b1/a.jpg');
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FALLO: A no pudo subir a su carpeta'; end if;
  ok := ok + 1;

  begin
    insert into storage.objects (bucket_id, name)
    values ('dish-images', 'b0000000-0000-4000-8000-0000000000b1/hack.jpg');
    raise exception 'FALLO: A subió a la carpeta de B';
  exception when insufficient_privilege then
    ok := ok + 1;
  end;

  delete from storage.objects
   where bucket_id = 'dish-images'
     and name = 'b0000000-0000-4000-8000-0000000000b1/b.jpg';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FALLO: A borró un archivo de B'; end if;
  ok := ok + 1;

  update storage.objects
     set name = 'a0000000-0000-4000-8000-0000000000b1/robada.jpg'
   where bucket_id = 'dish-images'
     and name = 'b0000000-0000-4000-8000-0000000000b1/b.jpg';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FALLO: A renombró un archivo de B'; end if;
  ok := ok + 1;

  begin
    update storage.objects
       set name = 'b0000000-0000-4000-8000-0000000000b1/movida.jpg'
     where bucket_id = 'dish-images'
       and name = 'a0000000-0000-4000-8000-0000000000b1/a.jpg';
    raise exception 'FALLO: A movió un archivo a la carpeta de B';
  exception when insufficient_privilege then
    ok := ok + 1;
  end;

  reset role;

  select count(*) into n from storage.objects
   where bucket_id = 'dish-images'
     and name = 'b0000000-0000-4000-8000-0000000000b1/b.jpg';
  if n <> 1 then raise exception 'FALLO: el archivo de B no sigue en su lugar'; end if;
  ok := ok + 1;

  perform set_config('hu2.ok', (current_setting('hu2.ok')::int + ok)::text, true);
end $$;

-- ------------------------------------------------------------------ Resultado
do $$
begin
  raise notice 'OK %', current_setting('hu2.ok');
end $$;

rollback;
