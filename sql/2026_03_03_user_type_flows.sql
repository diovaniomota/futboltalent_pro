begin;

create extension if not exists pgcrypto;

-- =========================================================
-- USER TYPE NORMALIZATION (Legacy compatibility)
-- =========================================================

do $$
declare
  user_type_col text;
begin
  if not exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'users'
  ) then
    return;
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'users'
      and column_name = 'userType'
  ) then
    user_type_col := '"userType"';
  elsif exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'users'
      and column_name = 'usertype'
  ) then
    user_type_col := 'usertype';
  else
    return;
  end if;

  execute format(
    $sql$
      update public.users
      set %1$s = case lower(trim(coalesce(%1$s::text, '')))
        when '' then null
        when 'jugador' then 'jugador'
        when 'jogador' then 'jugador'
        when 'player' then 'jugador'
        when 'athlete' then 'jugador'
        when 'atleta' then 'jugador'
        when 'profesional' then 'profesional'
        when 'professional' then 'profesional'
        when 'profissional' then 'profesional'
        when 'scout' then 'profesional'
        when 'scouter' then 'profesional'
        when 'scouting' then 'profesional'
        when 'oleador' then 'profesional'
        when 'ojeador' then 'profesional'
        when 'club' then 'club'
        when 'clube' then 'club'
        when 'club_staff' then 'club'
        when 'club-staff' then 'club'
        when 'staff' then 'club'
        when 'admin' then 'admin'
        when 'administrator' then 'admin'
        when 'administrador' then 'admin'
        else lower(trim(coalesce(%1$s::text, '')))
      end
      where coalesce(%1$s::text, '') <> ''
    $sql$,
    user_type_col
  );

  execute format(
    'create index if not exists users_user_type_idx on public.users (%s)',
    user_type_col
  );
end $$;

-- Keep updated_at in sync
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- =========================================================
-- CLUBS + STAFF (Club flow)
-- =========================================================

create table if not exists public.clubs (
  id uuid primary key default gen_random_uuid(),
  owner_id text not null,
  nombre text not null default 'Club',
  nombre_corto text,
  pais text,
  liga text,
  descripcion text,
  sitio_web text,
  logo_url text,
  max_staff integer not null default 10,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.clubs add column if not exists owner_id text;
alter table public.clubs add column if not exists nombre text;
alter table public.clubs add column if not exists nombre_corto text;
alter table public.clubs add column if not exists pais text;
alter table public.clubs add column if not exists liga text;
alter table public.clubs add column if not exists descripcion text;
alter table public.clubs add column if not exists sitio_web text;
alter table public.clubs add column if not exists logo_url text;
alter table public.clubs add column if not exists max_staff integer;
alter table public.clubs add column if not exists created_at timestamptz default now();
alter table public.clubs add column if not exists updated_at timestamptz default now();

update public.clubs
set max_staff = 10
where max_staff is null;

alter table public.clubs
  alter column max_staff set default 10;

create index if not exists clubs_owner_id_unique_idx
  on public.clubs (owner_id);

create index if not exists clubs_owner_id_idx
  on public.clubs (owner_id);

alter table public.clubs enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'clubs'
      and policyname = 'clubs_select_authenticated'
  ) then
    create policy clubs_select_authenticated
      on public.clubs
      for select
      to authenticated
      using (true);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'clubs'
      and policyname = 'clubs_insert_owner'
  ) then
    create policy clubs_insert_owner
      on public.clubs
      for insert
      to authenticated
      with check (owner_id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'clubs'
      and policyname = 'clubs_update_owner'
  ) then
    create policy clubs_update_owner
      on public.clubs
      for update
      to authenticated
      using (owner_id::text = auth.uid()::text)
      with check (owner_id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'clubs'
      and policyname = 'clubs_delete_owner'
  ) then
    create policy clubs_delete_owner
      on public.clubs
      for delete
      to authenticated
      using (owner_id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgname = 'set_updated_at_clubs'
  ) then
    create trigger set_updated_at_clubs
      before update on public.clubs
      for each row
      execute procedure public.set_updated_at();
  end if;
end $$;

create table if not exists public.club_staff (
  id uuid primary key default gen_random_uuid(),
  club_id text not null,
  user_id text not null,
  cargo text not null default 'Staff',
  is_admin boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.club_staff add column if not exists club_id text;
alter table public.club_staff add column if not exists user_id text;
alter table public.club_staff add column if not exists cargo text;
alter table public.club_staff add column if not exists is_admin boolean default false;
alter table public.club_staff add column if not exists created_at timestamptz default now();
alter table public.club_staff add column if not exists updated_at timestamptz default now();

create index if not exists club_staff_unique_member_idx
  on public.club_staff (club_id, user_id);

create index if not exists club_staff_club_id_idx
  on public.club_staff (club_id);

create index if not exists club_staff_user_id_idx
  on public.club_staff (user_id);

alter table public.club_staff enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'club_staff'
      and policyname = 'club_staff_select_member_or_owner'
  ) then
    create policy club_staff_select_member_or_owner
      on public.club_staff
      for select
      to authenticated
      using (
        user_id::text = auth.uid()::text
        or exists (
          select 1
          from public.clubs c
          where c.id::text = club_staff.club_id::text
            and c.owner_id::text = auth.uid()::text
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'club_staff'
      and policyname = 'club_staff_insert_owner'
  ) then
    create policy club_staff_insert_owner
      on public.club_staff
      for insert
      to authenticated
      with check (
        exists (
          select 1
          from public.clubs c
          where c.id::text = club_staff.club_id::text
            and c.owner_id::text = auth.uid()::text
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'club_staff'
      and policyname = 'club_staff_update_owner'
  ) then
    create policy club_staff_update_owner
      on public.club_staff
      for update
      to authenticated
      using (
        exists (
          select 1
          from public.clubs c
          where c.id::text = club_staff.club_id::text
            and c.owner_id::text = auth.uid()::text
        )
      )
      with check (
        exists (
          select 1
          from public.clubs c
          where c.id::text = club_staff.club_id::text
            and c.owner_id::text = auth.uid()::text
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'club_staff'
      and policyname = 'club_staff_delete_owner'
  ) then
    create policy club_staff_delete_owner
      on public.club_staff
      for delete
      to authenticated
      using (
        exists (
          select 1
          from public.clubs c
          where c.id::text = club_staff.club_id::text
            and c.owner_id::text = auth.uid()::text
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgname = 'set_updated_at_club_staff'
  ) then
    create trigger set_updated_at_club_staff
      before update on public.club_staff
      for each row
      execute procedure public.set_updated_at();
  end if;
end $$;

-- =========================================================
-- FOLLOWS (Jugador/Scout social flow)
-- =========================================================

create table if not exists public.follows (
  id uuid primary key default gen_random_uuid(),
  follower_id text not null,
  following_id text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.follows add column if not exists follower_id text;
alter table public.follows add column if not exists following_id text;
alter table public.follows add column if not exists created_at timestamptz default now();
alter table public.follows add column if not exists updated_at timestamptz default now();

create index if not exists follows_unique_idx
  on public.follows (follower_id, following_id);

create index if not exists follows_follower_idx
  on public.follows (follower_id);

create index if not exists follows_following_idx
  on public.follows (following_id);

alter table public.follows enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'follows'
      and policyname = 'follows_select_actor'
  ) then
    create policy follows_select_actor
      on public.follows
      for select
      to authenticated
      using (
        follower_id::text = auth.uid()::text
        or following_id::text = auth.uid()::text
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'follows'
      and policyname = 'follows_insert_owner'
  ) then
    create policy follows_insert_owner
      on public.follows
      for insert
      to authenticated
      with check (
        follower_id::text = auth.uid()::text
        and following_id::text <> auth.uid()::text
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'follows'
      and policyname = 'follows_delete_owner'
  ) then
    create policy follows_delete_owner
      on public.follows
      for delete
      to authenticated
      using (follower_id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgname = 'set_updated_at_follows'
  ) then
    create trigger set_updated_at_follows
      before update on public.follows
      for each row
      execute procedure public.set_updated_at();
  end if;
end $$;

-- =========================================================
-- CONTACT REQUESTS (Scout -> Jugador flow)
-- =========================================================

create table if not exists public.contact_requests (
  id uuid primary key default gen_random_uuid(),
  from_user_id text not null,
  to_user_id text not null,
  status text not null default 'pending',
  guardian_notified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  responded_at timestamptz
);

alter table public.contact_requests add column if not exists from_user_id text;
alter table public.contact_requests add column if not exists to_user_id text;
alter table public.contact_requests add column if not exists status text;
alter table public.contact_requests add column if not exists guardian_notified boolean default false;
alter table public.contact_requests add column if not exists created_at timestamptz default now();
alter table public.contact_requests add column if not exists updated_at timestamptz default now();
alter table public.contact_requests add column if not exists responded_at timestamptz;

create index if not exists contact_requests_from_idx
  on public.contact_requests (from_user_id, created_at desc);

create index if not exists contact_requests_to_idx
  on public.contact_requests (to_user_id, created_at desc);

create index if not exists contact_requests_status_idx
  on public.contact_requests (status);

alter table public.contact_requests enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'contact_requests'
      and policyname = 'contact_requests_select_participants'
  ) then
    create policy contact_requests_select_participants
      on public.contact_requests
      for select
      to authenticated
      using (from_user_id::text = auth.uid()::text or to_user_id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'contact_requests'
      and policyname = 'contact_requests_insert_sender'
  ) then
    create policy contact_requests_insert_sender
      on public.contact_requests
      for insert
      to authenticated
      with check (from_user_id::text = auth.uid()::text and to_user_id::text <> auth.uid()::text);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'contact_requests'
      and policyname = 'contact_requests_update_receiver'
  ) then
    create policy contact_requests_update_receiver
      on public.contact_requests
      for update
      to authenticated
      using (to_user_id::text = auth.uid()::text)
      with check (to_user_id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'contact_requests'
      and policyname = 'contact_requests_update_sender_reopen'
  ) then
    create policy contact_requests_update_sender_reopen
      on public.contact_requests
      for update
      to authenticated
      using (from_user_id::text = auth.uid()::text)
      with check (
        from_user_id::text = auth.uid()::text
        and lower(coalesce(status, 'pending')) in ('pending', 'pendiente')
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'contact_requests'
      and policyname = 'contact_requests_delete_sender'
  ) then
    create policy contact_requests_delete_sender
      on public.contact_requests
      for delete
      to authenticated
      using (from_user_id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgname = 'set_updated_at_contact_requests'
  ) then
    create trigger set_updated_at_contact_requests
      before update on public.contact_requests
      for each row
      execute procedure public.set_updated_at();
  end if;
end $$;

-- =========================================================
-- CONVOCATORIAS APPLICATIONS (Jugador -> Club flow)
-- =========================================================

create table if not exists public.aplicaciones_convocatoria (
  id uuid primary key default gen_random_uuid(),
  convocatoria_id text not null,
  jugador_id text not null,
  estado text not null default 'pendiente',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.aplicaciones_convocatoria add column if not exists convocatoria_id text;
alter table public.aplicaciones_convocatoria add column if not exists jugador_id text;
alter table public.aplicaciones_convocatoria add column if not exists estado text;
alter table public.aplicaciones_convocatoria add column if not exists created_at timestamptz default now();
alter table public.aplicaciones_convocatoria add column if not exists updated_at timestamptz default now();

create index if not exists aplicaciones_convocatoria_unique_idx
  on public.aplicaciones_convocatoria (convocatoria_id, jugador_id);

create index if not exists aplicaciones_convocatoria_conv_idx
  on public.aplicaciones_convocatoria (convocatoria_id);

create index if not exists aplicaciones_convocatoria_jugador_idx
  on public.aplicaciones_convocatoria (jugador_id);

alter table public.aplicaciones_convocatoria enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'aplicaciones_convocatoria'
      and policyname = 'aplicaciones_select_actor'
  ) then
    create policy aplicaciones_select_actor
      on public.aplicaciones_convocatoria
      for select
      to authenticated
      using (
        jugador_id::text = auth.uid()::text
        or exists (
          select 1
          from public.convocatorias c
          where c.id::text = aplicaciones_convocatoria.convocatoria_id::text
            and c.club_id::text = auth.uid()::text
        )
        or exists (
          select 1
          from public.convocatorias c
          join public.clubs cl on cl.id::text = c.club_id::text
          where c.id::text = aplicaciones_convocatoria.convocatoria_id::text
            and cl.owner_id::text = auth.uid()::text
        )
        or exists (
          select 1
          from public.convocatorias c
          join public.clubs cl on cl.id::text = c.club_id::text
          join public.club_staff cs on cs.club_id::text = cl.id::text
          where c.id::text = aplicaciones_convocatoria.convocatoria_id::text
            and cs.user_id::text = auth.uid()::text
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'aplicaciones_convocatoria'
      and policyname = 'aplicaciones_insert_jugador'
  ) then
    create policy aplicaciones_insert_jugador
      on public.aplicaciones_convocatoria
      for insert
      to authenticated
      with check (jugador_id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'aplicaciones_convocatoria'
      and policyname = 'aplicaciones_update_club'
  ) then
    create policy aplicaciones_update_club
      on public.aplicaciones_convocatoria
      for update
      to authenticated
      using (
        exists (
          select 1
          from public.convocatorias c
          where c.id::text = aplicaciones_convocatoria.convocatoria_id::text
            and c.club_id::text = auth.uid()::text
        )
        or exists (
          select 1
          from public.convocatorias c
          join public.clubs cl on cl.id::text = c.club_id::text
          where c.id::text = aplicaciones_convocatoria.convocatoria_id::text
            and cl.owner_id::text = auth.uid()::text
        )
        or exists (
          select 1
          from public.convocatorias c
          join public.clubs cl on cl.id::text = c.club_id::text
          join public.club_staff cs on cs.club_id::text = cl.id::text
          where c.id::text = aplicaciones_convocatoria.convocatoria_id::text
            and cs.user_id::text = auth.uid()::text
        )
      )
      with check (true);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgname = 'set_updated_at_aplicaciones_convocatoria'
  ) then
    create trigger set_updated_at_aplicaciones_convocatoria
      before update on public.aplicaciones_convocatoria
      for each row
      execute procedure public.set_updated_at();
  end if;
end $$;

-- =========================================================
-- SCOUT LISTS + SAVED PLAYERS (Scout flow)
-- =========================================================

create table if not exists public.listas (
  id uuid primary key default gen_random_uuid(),
  profesional_id text not null,
  nombre text not null,
  convocatoria_id text,
  is_private boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.listas add column if not exists profesional_id text;
alter table public.listas add column if not exists nombre text;
alter table public.listas add column if not exists convocatoria_id text;
alter table public.listas add column if not exists is_private boolean default true;
alter table public.listas add column if not exists created_at timestamptz default now();
alter table public.listas add column if not exists updated_at timestamptz default now();

create index if not exists listas_profesional_idx
  on public.listas (profesional_id, created_at desc);

alter table public.listas enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'listas'
      and policyname = 'listas_select_owner'
  ) then
    create policy listas_select_owner
      on public.listas
      for select
      to authenticated
      using (profesional_id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'listas'
      and policyname = 'listas_insert_owner'
  ) then
    create policy listas_insert_owner
      on public.listas
      for insert
      to authenticated
      with check (profesional_id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'listas'
      and policyname = 'listas_update_owner'
  ) then
    create policy listas_update_owner
      on public.listas
      for update
      to authenticated
      using (profesional_id::text = auth.uid()::text)
      with check (profesional_id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'listas'
      and policyname = 'listas_delete_owner'
  ) then
    create policy listas_delete_owner
      on public.listas
      for delete
      to authenticated
      using (profesional_id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgname = 'set_updated_at_listas'
  ) then
    create trigger set_updated_at_listas
      before update on public.listas
      for each row
      execute procedure public.set_updated_at();
  end if;
end $$;

create table if not exists public.listas_club (
  id uuid primary key default gen_random_uuid(),
  club_id text not null,
  nombre text not null,
  descripcion text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.listas_club add column if not exists club_id text;
alter table public.listas_club add column if not exists nombre text;
alter table public.listas_club add column if not exists descripcion text;
alter table public.listas_club add column if not exists created_at timestamptz default now();
alter table public.listas_club add column if not exists updated_at timestamptz default now();

create index if not exists listas_club_club_idx
  on public.listas_club (club_id, created_at desc);

alter table public.listas_club enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'listas_club'
      and policyname = 'listas_club_select_staff_or_owner'
  ) then
    create policy listas_club_select_staff_or_owner
      on public.listas_club
      for select
      to authenticated
      using (
        exists (
          select 1 from public.clubs c
          where c.id::text = listas_club.club_id::text
            and c.owner_id::text = auth.uid()::text
        )
        or exists (
          select 1 from public.club_staff cs
          where cs.club_id::text = listas_club.club_id::text
            and cs.user_id::text = auth.uid()::text
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'listas_club'
      and policyname = 'listas_club_insert_staff_or_owner'
  ) then
    create policy listas_club_insert_staff_or_owner
      on public.listas_club
      for insert
      to authenticated
      with check (
        exists (
          select 1 from public.clubs c
          where c.id::text = listas_club.club_id::text
            and c.owner_id::text = auth.uid()::text
        )
        or exists (
          select 1 from public.club_staff cs
          where cs.club_id::text = listas_club.club_id::text
            and cs.user_id::text = auth.uid()::text
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'listas_club'
      and policyname = 'listas_club_update_staff_or_owner'
  ) then
    create policy listas_club_update_staff_or_owner
      on public.listas_club
      for update
      to authenticated
      using (
        exists (
          select 1 from public.clubs c
          where c.id::text = listas_club.club_id::text
            and c.owner_id::text = auth.uid()::text
        )
        or exists (
          select 1 from public.club_staff cs
          where cs.club_id::text = listas_club.club_id::text
            and cs.user_id::text = auth.uid()::text
        )
      )
      with check (true);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'listas_club'
      and policyname = 'listas_club_delete_staff_or_owner'
  ) then
    create policy listas_club_delete_staff_or_owner
      on public.listas_club
      for delete
      to authenticated
      using (
        exists (
          select 1 from public.clubs c
          where c.id::text = listas_club.club_id::text
            and c.owner_id::text = auth.uid()::text
        )
        or exists (
          select 1 from public.club_staff cs
          where cs.club_id::text = listas_club.club_id::text
            and cs.user_id::text = auth.uid()::text
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgname = 'set_updated_at_listas_club'
  ) then
    create trigger set_updated_at_listas_club
      before update on public.listas_club
      for each row
      execute procedure public.set_updated_at();
  end if;
end $$;

create table if not exists public.listas_jugadores (
  id uuid primary key default gen_random_uuid(),
  lista_id text not null,
  jugador_id text not null,
  nota text,
  calificacion integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.listas_jugadores add column if not exists lista_id text;
alter table public.listas_jugadores add column if not exists jugador_id text;
alter table public.listas_jugadores add column if not exists nota text;
alter table public.listas_jugadores add column if not exists calificacion integer default 0;
alter table public.listas_jugadores add column if not exists created_at timestamptz default now();
alter table public.listas_jugadores add column if not exists updated_at timestamptz default now();

create index if not exists listas_jugadores_unique_idx
  on public.listas_jugadores (lista_id, jugador_id);

create index if not exists listas_jugadores_lista_idx
  on public.listas_jugadores (lista_id, created_at desc);

create index if not exists listas_jugadores_jugador_idx
  on public.listas_jugadores (jugador_id);

alter table public.listas_jugadores enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'listas_jugadores'
      and policyname = 'listas_jugadores_select_owner'
  ) then
    create policy listas_jugadores_select_owner
      on public.listas_jugadores
      for select
      to authenticated
      using (
        exists (
          select 1
          from public.listas l
          where l.id::text = listas_jugadores.lista_id::text
            and l.profesional_id::text = auth.uid()::text
        )
        or exists (
          select 1
          from public.listas_club lc
          join public.clubs c on c.id::text = lc.club_id::text
          where lc.id::text = listas_jugadores.lista_id::text
            and (
              c.owner_id::text = auth.uid()::text
              or exists (
                select 1
                from public.club_staff cs
                where cs.club_id::text = lc.club_id::text
                  and cs.user_id::text = auth.uid()::text
              )
            )
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'listas_jugadores'
      and policyname = 'listas_jugadores_insert_owner'
  ) then
    create policy listas_jugadores_insert_owner
      on public.listas_jugadores
      for insert
      to authenticated
      with check (
        exists (
          select 1
          from public.listas l
          where l.id::text = listas_jugadores.lista_id::text
            and l.profesional_id::text = auth.uid()::text
        )
        or exists (
          select 1
          from public.listas_club lc
          join public.clubs c on c.id::text = lc.club_id::text
          where lc.id::text = listas_jugadores.lista_id::text
            and (
              c.owner_id::text = auth.uid()::text
              or exists (
                select 1
                from public.club_staff cs
                where cs.club_id::text = lc.club_id::text
                  and cs.user_id::text = auth.uid()::text
              )
            )
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'listas_jugadores'
      and policyname = 'listas_jugadores_update_owner'
  ) then
    create policy listas_jugadores_update_owner
      on public.listas_jugadores
      for update
      to authenticated
      using (
        exists (
          select 1
          from public.listas l
          where l.id::text = listas_jugadores.lista_id::text
            and l.profesional_id::text = auth.uid()::text
        )
        or exists (
          select 1
          from public.listas_club lc
          join public.clubs c on c.id::text = lc.club_id::text
          where lc.id::text = listas_jugadores.lista_id::text
            and (
              c.owner_id::text = auth.uid()::text
              or exists (
                select 1
                from public.club_staff cs
                where cs.club_id::text = lc.club_id::text
                  and cs.user_id::text = auth.uid()::text
              )
            )
        )
      )
      with check (true);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'listas_jugadores'
      and policyname = 'listas_jugadores_delete_owner'
  ) then
    create policy listas_jugadores_delete_owner
      on public.listas_jugadores
      for delete
      to authenticated
      using (
        exists (
          select 1
          from public.listas l
          where l.id::text = listas_jugadores.lista_id::text
            and l.profesional_id::text = auth.uid()::text
        )
        or exists (
          select 1
          from public.listas_club lc
          join public.clubs c on c.id::text = lc.club_id::text
          where lc.id::text = listas_jugadores.lista_id::text
            and (
              c.owner_id::text = auth.uid()::text
              or exists (
                select 1
                from public.club_staff cs
                where cs.club_id::text = lc.club_id::text
                  and cs.user_id::text = auth.uid()::text
              )
            )
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgname = 'set_updated_at_listas_jugadores'
  ) then
    create trigger set_updated_at_listas_jugadores
      before update on public.listas_jugadores
      for each row
      execute procedure public.set_updated_at();
  end if;
end $$;

create table if not exists public.jugadores_guardados (
  id uuid primary key default gen_random_uuid(),
  scout_id text not null,
  jugador_id text not null,
  nota text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.jugadores_guardados add column if not exists scout_id text;
alter table public.jugadores_guardados add column if not exists jugador_id text;
alter table public.jugadores_guardados add column if not exists nota text;
alter table public.jugadores_guardados add column if not exists created_at timestamptz default now();
alter table public.jugadores_guardados add column if not exists updated_at timestamptz default now();

create index if not exists jugadores_guardados_unique_idx
  on public.jugadores_guardados (scout_id, jugador_id);

create index if not exists jugadores_guardados_scout_idx
  on public.jugadores_guardados (scout_id, created_at desc);

alter table public.jugadores_guardados enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'jugadores_guardados'
      and policyname = 'jugadores_guardados_select_owner'
  ) then
    create policy jugadores_guardados_select_owner
      on public.jugadores_guardados
      for select
      to authenticated
      using (scout_id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'jugadores_guardados'
      and policyname = 'jugadores_guardados_insert_owner'
  ) then
    create policy jugadores_guardados_insert_owner
      on public.jugadores_guardados
      for insert
      to authenticated
      with check (scout_id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'jugadores_guardados'
      and policyname = 'jugadores_guardados_update_owner'
  ) then
    create policy jugadores_guardados_update_owner
      on public.jugadores_guardados
      for update
      to authenticated
      using (scout_id::text = auth.uid()::text)
      with check (scout_id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'jugadores_guardados'
      and policyname = 'jugadores_guardados_delete_owner'
  ) then
    create policy jugadores_guardados_delete_owner
      on public.jugadores_guardados
      for delete
      to authenticated
      using (scout_id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgname = 'set_updated_at_jugadores_guardados'
  ) then
    create trigger set_updated_at_jugadores_guardados
      before update on public.jugadores_guardados
      for each row
      execute procedure public.set_updated_at();
  end if;
end $$;

commit;
