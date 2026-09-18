create table if not exists public.reviews (
 id uuid primary key default gen_random_uuid(),
 reviewer_name text not null,
 body text not null,
 rating integer not null default 5 check (rating between 1 and 5),
 image_url text,
 verified boolean not null default true,
 active boolean not null default true,
 created_at timestamptz not null default now()
);
alter table public.reviews enable row level security;
create policy "Public can read active reviews" on public.reviews for select using(active=true or auth.role()='authenticated');
create policy "Admins manage reviews" on public.reviews for all to authenticated using(true) with check(true);
insert into public.reviews(reviewer_name,body,rating,verified) values
('Sofía M.','El empaque llegó precioso y el álbum impecable. Se nota muchísimo el cuidado.',5,true),
('Andrea R.','Mi preventa llegó justo en el periodo indicado y siempre me mantuvieron al tanto.',5,true),
('Fernanda L.','Los posters vienen protegidos, sin dobleces. Ya es mi tienda favorita.',5,true);
