-- Krescendo: Almacén privado para clientes.
-- Ejecuta este archivo completo una sola vez en Supabase > SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.warehouse_cycles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  customer_email text not null,
  started_at timestamptz not null default now(),
  free_until timestamptz not null default (now() + interval '1 month'),
  choice text check (choice in ('storage','shipping')),
  status text not null default 'active' check (status in ('active','shipped')),
  closed_at timestamptz,
  created_at timestamptz not null default now()
);

create unique index if not exists one_active_warehouse_per_customer
  on public.warehouse_cycles(user_id) where status = 'active';

create table if not exists public.warehouse_items (
  id uuid primary key default gen_random_uuid(),
  cycle_id uuid not null references public.warehouse_cycles(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  product_name text not null,
  quantity integer not null default 1 check (quantity > 0),
  image_url text,
  notes text,
  arrived_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.warehouse_cycles enable row level security;
alter table public.warehouse_items enable row level security;

drop policy if exists "Customers read own warehouse" on public.warehouse_cycles;
drop policy if exists "Customers read own warehouse items" on public.warehouse_items;
drop policy if exists "Store admin manages warehouse" on public.warehouse_cycles;
drop policy if exists "Store admin manages warehouse items" on public.warehouse_items;

create policy "Customers read own warehouse" on public.warehouse_cycles
  for select to authenticated using (user_id = auth.uid());
create policy "Customers read own warehouse items" on public.warehouse_items
  for select to authenticated using (user_id = auth.uid());
create policy "Store admin manages warehouse" on public.warehouse_cycles
  for all to authenticated
  using ((auth.jwt() ->> 'email') = 'yoonmendo@gmail.com')
  with check ((auth.jwt() ->> 'email') = 'yoonmendo@gmail.com');
create policy "Store admin manages warehouse items" on public.warehouse_items
  for all to authenticated
  using ((auth.jwt() ->> 'email') = 'yoonmendo@gmail.com')
  with check ((auth.jwt() ->> 'email') = 'yoonmendo@gmail.com');

create or replace function public.list_warehouse_clients()
returns table(user_id uuid, email text)
language plpgsql security definer set search_path = public, auth as $$
begin
  if (auth.jwt() ->> 'email') is distinct from 'yoonmendo@gmail.com' then raise exception 'Acceso denegado'; end if;
  return query select u.id, u.email::text from auth.users u
    where u.email is not null and lower(u.email) <> 'yoonmendo@gmail.com'
    order by u.email;
end;
$$;
revoke all on function public.list_warehouse_clients() from public;
grant execute on function public.list_warehouse_clients() to authenticated;

create or replace function public.add_warehouse_item(
  client_email text,
  item_name text,
  item_quantity integer,
  item_image text,
  item_notes text,
  item_arrived_at date
) returns uuid
language plpgsql security definer set search_path = public, auth as $$
declare client_id uuid; active_cycle uuid; arrival timestamptz;
begin
  if (auth.jwt() ->> 'email') is distinct from 'yoonmendo@gmail.com' then raise exception 'Acceso denegado'; end if;
  select id into client_id from auth.users where lower(email)=lower(trim(client_email)) limit 1;
  if client_id is null then raise exception 'Cliente no encontrado'; end if;
  if trim(coalesce(item_name,''))='' or coalesce(item_quantity,0)<1 then raise exception 'Producto o cantidad inválidos'; end if;
  arrival := coalesce(item_arrived_at,current_date)::timestamptz;
  select id into active_cycle from public.warehouse_cycles where user_id=client_id and status='active' limit 1;
  if active_cycle is null then
    insert into public.warehouse_cycles(user_id,customer_email,started_at,free_until)
    values(client_id,lower(trim(client_email)),arrival,arrival + interval '1 month') returning id into active_cycle;
  end if;
  insert into public.warehouse_items(cycle_id,user_id,product_name,quantity,image_url,notes,arrived_at)
  values(active_cycle,client_id,trim(item_name),item_quantity,nullif(trim(coalesce(item_image,'')),''),nullif(trim(coalesce(item_notes,'')),''),arrival);
  return active_cycle;
end;
$$;
revoke all on function public.add_warehouse_item(text,text,integer,text,text,date) from public;
grant execute on function public.add_warehouse_item(text,text,integer,text,text,date) to authenticated;

create or replace function public.set_warehouse_choice(requested_choice text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión'; end if;
  if requested_choice not in ('storage','shipping') then raise exception 'Opción inválida'; end if;
  update public.warehouse_cycles set choice=requested_choice
    where user_id=auth.uid() and status='active';
  if not found then raise exception 'No tienes un almacén activo'; end if;
end;
$$;
revoke all on function public.set_warehouse_choice(text) from public;
grant execute on function public.set_warehouse_choice(text) to authenticated;

create or replace function public.close_warehouse_cycle(warehouse_cycle_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if (auth.jwt() ->> 'email') is distinct from 'yoonmendo@gmail.com' then raise exception 'Acceso denegado'; end if;
  update public.warehouse_cycles set status='shipped',closed_at=now()
    where id=warehouse_cycle_id and status='active';
  if not found then raise exception 'Almacén no encontrado o ya cerrado'; end if;
end;
$$;
revoke all on function public.close_warehouse_cycle(uuid) from public;
grant execute on function public.close_warehouse_cycle(uuid) to authenticated;
