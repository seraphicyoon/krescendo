-- Krescendo V10: invitaciones, clientes, pedidos y seguridad del catálogo.
-- Ejecuta este archivo completo una sola vez en Supabase > SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.site_settings (
  id text primary key,
  hero_image_url text,
  updated_at timestamptz not null default now()
);
alter table public.site_settings enable row level security;
drop policy if exists "Public reads site settings" on public.site_settings;
drop policy if exists "Store admin manages site settings" on public.site_settings;
create policy "Public reads site settings" on public.site_settings for select using (true);
create policy "Store admin manages site settings" on public.site_settings for all to authenticated
  using ((auth.jwt() ->> 'email') = 'yoonmendo@gmail.com')
  with check ((auth.jwt() ->> 'email') = 'yoonmendo@gmail.com');
insert into public.site_settings(id) values('main') on conflict(id) do nothing;

create table if not exists public.invite_codes (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  active boolean not null default true,
  used_by uuid references auth.users(id) on delete set null,
  used_by_email text,
  used_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.invite_codes enable row level security;
drop policy if exists "Store admin manages invites" on public.invite_codes;
create policy "Store admin manages invites" on public.invite_codes for all to authenticated
  using ((auth.jwt() ->> 'email') = 'yoonmendo@gmail.com')
  with check ((auth.jwt() ->> 'email') = 'yoonmendo@gmail.com');

create or replace function public.create_invite_code()
returns text language plpgsql security definer set search_path = public as $$
declare new_code text;
begin
  if (auth.jwt() ->> 'email') is distinct from 'yoonmendo@gmail.com' then raise exception 'Acceso denegado'; end if;
  loop
    new_code := 'KRS-' || upper(substr(encode(gen_random_bytes(4),'hex'),1,4)) || '-' || upper(substr(encode(gen_random_bytes(4),'hex'),1,4));
    begin insert into public.invite_codes(code) values(new_code); exit; exception when unique_violation then end;
  end loop;
  return new_code;
end;
$$;
revoke all on function public.create_invite_code() from public;
grant execute on function public.create_invite_code() to authenticated;

create or replace function public.require_krescendo_invite()
returns trigger language plpgsql security definer set search_path = public as $$
declare supplied_code text; claimed_id uuid;
begin
  if lower(new.email) = 'yoonmendo@gmail.com' then return new; end if;
  supplied_code := upper(trim(coalesce(new.raw_user_meta_data ->> 'invite_code','')));
  update public.invite_codes set active=false,used_by=new.id,used_by_email=new.email,used_at=now()
    where code=supplied_code and active=true and used_at is null returning id into claimed_id;
  if claimed_id is null then raise exception 'Se requiere una invitación válida'; end if;
  return new;
end;
$$;

drop trigger if exists require_krescendo_invite_on_signup on auth.users;
create trigger require_krescendo_invite_on_signup after insert on auth.users
for each row execute function public.require_krescendo_invite();

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  reference text not null unique,
  status text not null default 'pending_transfer' check (status in ('pending_transfer','paid','preparing','shipped','cancelled')),
  total numeric(10,2) not null check (total >= 0),
  shipping jsonb not null,
  created_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  product_name text not null,
  unit_price numeric(10,2) not null,
  quantity integer not null check (quantity > 0),
  created_at timestamptz not null default now()
);

alter table public.orders enable row level security;
alter table public.order_items enable row level security;

drop policy if exists "Customers read own orders" on public.orders;
drop policy if exists "Customers read own order items" on public.order_items;
create policy "Customers read own orders" on public.orders for select to authenticated
  using (user_id = auth.uid() or (auth.jwt() ->> 'email') = 'yoonmendo@gmail.com');
create policy "Customers read own order items" on public.order_items for select to authenticated
  using (exists (select 1 from public.orders o where o.id = order_id and (o.user_id = auth.uid() or (auth.jwt() ->> 'email') = 'yoonmendo@gmail.com')));

-- Al habilitar cuentas de clientes, solo este correo debe conservar permisos de administración.
drop policy if exists "Admins manage categories" on public.categories;
drop policy if exists "Admins manage products" on public.products;
drop policy if exists "Store admin manages categories" on public.categories;
drop policy if exists "Store admin manages products" on public.products;
create policy "Store admin manages categories" on public.categories for all to authenticated
  using ((auth.jwt() ->> 'email') = 'yoonmendo@gmail.com')
  with check ((auth.jwt() ->> 'email') = 'yoonmendo@gmail.com');
create policy "Store admin manages products" on public.products for all to authenticated
  using ((auth.jwt() ->> 'email') = 'yoonmendo@gmail.com')
  with check ((auth.jwt() ->> 'email') = 'yoonmendo@gmail.com');

do $$ begin
  if to_regclass('public.reviews') is not null then
    execute 'drop policy if exists "Admins manage reviews" on public.reviews';
    execute 'drop policy if exists "Store admin manages reviews" on public.reviews';
    execute 'create policy "Store admin manages reviews" on public.reviews for all to authenticated using ((auth.jwt() ->> ''email'') = ''yoonmendo@gmail.com'') with check ((auth.jwt() ->> ''email'') = ''yoonmendo@gmail.com'')';
  end if;
end $$;

create or replace function public.create_store_order(cart_items jsonb, shipping_data jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  item jsonb;
  product_row public.products%rowtype;
  qty integer;
  calculated_total numeric(10,2) := 0;
  new_order_id uuid;
  order_reference text;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión'; end if;
  if jsonb_typeof(cart_items) <> 'array' or jsonb_array_length(cart_items) = 0 then raise exception 'La bolsa está vacía'; end if;
  if coalesce(shipping_data ->> 'full_name','') = '' or coalesce(shipping_data ->> 'address_line1','') = '' or coalesce(shipping_data ->> 'postal_code','') = '' then
    raise exception 'Faltan datos de envío';
  end if;

  for item in select * from jsonb_array_elements(cart_items) loop
    qty := (item ->> 'quantity')::integer;
    if qty < 1 then raise exception 'Cantidad inválida'; end if;
    select * into product_row from public.products where id = (item ->> 'product_id')::uuid and active = true for update;
    if not found then raise exception 'Uno de los productos ya no está disponible'; end if;
    if product_row.status = 'stock' and product_row.stock < qty then raise exception 'Stock insuficiente para %', product_row.name; end if;
    calculated_total := calculated_total + (product_row.price * qty);
  end loop;

  order_reference := 'KRS-' || to_char(now(),'YYMMDD') || '-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,6));
  insert into public.orders(user_id,reference,total,shipping) values(auth.uid(),order_reference,calculated_total,shipping_data) returning id into new_order_id;

  for item in select * from jsonb_array_elements(cart_items) loop
    qty := (item ->> 'quantity')::integer;
    select * into product_row from public.products where id = (item ->> 'product_id')::uuid for update;
    insert into public.order_items(order_id,product_id,product_name,unit_price,quantity) values(new_order_id,product_row.id,product_row.name,product_row.price,qty);
    if product_row.status = 'stock' then update public.products set stock = stock - qty where id = product_row.id; end if;
  end loop;
  return jsonb_build_object('id',new_order_id,'reference',order_reference,'total',calculated_total);
end;
$$;

revoke all on function public.create_store_order(jsonb,jsonb) from public;
grant execute on function public.create_store_order(jsonb,jsonb) to authenticated;
