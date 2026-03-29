begin;

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'users'
  ) then
    alter table public.users add column if not exists updated_at timestamptz default now();
    alter table public.users add column if not exists posicion text;
    alter table public.users add column if not exists categoria text;
    alter table public.users add column if not exists country text;
    alter table public.users add column if not exists pais text;
    alter table public.users add column if not exists full_profile boolean default false;
    alter table public.users add column if not exists is_test_account boolean default false;
    alter table public.users add column if not exists verification_status text default 'pending';
    alter table public.users add column if not exists is_verified boolean default false;
    alter table public.users add column if not exists banned_until timestamptz;
    alter table public.users add column if not exists is_admin boolean default false;
  end if;
end $$;

do $$
declare
  user_type_col text;
  admin_checks text[] := array[]::text[];
  admin_predicate text;
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
    user_type_col := null;
  end if;

  if user_type_col is not null then
    admin_checks := array_append(
      admin_checks,
      format(
        'lower(coalesce(u.%s::text, '''')) = ''admin''',
        user_type_col
      )
    );
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'users'
      and column_name = 'is_admin'
  ) then
    admin_checks := array_append(
      admin_checks,
      'coalesce(u.is_admin, false) = true'
    );
  end if;

  admin_predicate := case
    when array_length(admin_checks, 1) is null then 'false'
    else array_to_string(admin_checks, ' or ')
  end;

  execute format(
    $sql$
      create or replace function public.is_admin_user(target_uid uuid default auth.uid())
      returns boolean
      language sql
      stable
      security definer
      set search_path = public
      as $fn$
        select exists (
          select 1
          from public.users u
          where u.user_id::text = target_uid::text
            and (%1$s)
        );
      $fn$;
    $sql$,
    admin_predicate
  );
end $$;

do $$
begin
  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'is_admin_user'
  ) then
    grant execute on function public.is_admin_user(uuid) to authenticated;
  end if;
end $$;

update public.users
set verification_status = case
    when coalesce(is_verified, false) then 'verified'
    when coalesce(lower(verification_status), '') = '' then 'pending'
    else verification_status
  end
where coalesce(lower(verification_status), '') = ''
   or (coalesce(is_verified, false) = true and coalesce(lower(verification_status), '') <> 'verified');

update public.users
set is_verified = true
where lower(coalesce(verification_status, '')) in ('verified', 'verificado', 'approved', 'aprobado', 'ativo', 'active');

do $$
declare
  user_type_col text;
begin
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
  end if;

  if user_type_col is null then
    return;
  end if;

  execute format(
    'update public.users set is_admin = true where lower(coalesce(%s::text, '''')) = ''admin'';',
    user_type_col
  );
end $$;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'users'
  ) then
    alter table public.users enable row level security;
  end if;
end $$;

do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public'
      and table_name = 'users'
  ) and not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'users'
      and policyname = 'users_admin_manage_all'
  ) then
    create policy users_admin_manage_all
      on public.users
      for all
      to authenticated
      using (public.is_admin_user(auth.uid()))
      with check (public.is_admin_user(auth.uid()));
  end if;
end $$;

do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public'
      and table_name = 'users'
  ) and not exists (
    select 1 from pg_trigger
    where tgname = 'set_updated_at_users_admin'
  ) then
    create trigger set_updated_at_users_admin
      before update on public.users
      for each row
      execute procedure public.set_updated_at();
  end if;
end $$;

create table if not exists public.challenge_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (name),
  unique (slug)
);

alter table public.challenge_categories add column if not exists description text;
alter table public.challenge_categories add column if not exists is_active boolean default true;
alter table public.challenge_categories add column if not exists created_at timestamptz default now();
alter table public.challenge_categories add column if not exists updated_at timestamptz default now();

insert into public.challenge_categories (name, slug, description)
values
  ('Agilidad', 'agilidad', 'Retos de coordinación y cambios de ritmo'),
  ('Velocidad', 'velocidad', 'Retos de aceleración y velocidad máxima'),
  ('Técnica', 'tecnica', 'Retos de control, pase y dominio'),
  ('Definición', 'definicion', 'Retos de finalización y remate')
on conflict (slug) do nothing;

alter table public.challenge_categories enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'challenge_categories'
      and policyname = 'challenge_categories_select_authenticated'
  ) then
    create policy challenge_categories_select_authenticated
      on public.challenge_categories
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
      and tablename = 'challenge_categories'
      and policyname = 'challenge_categories_admin_manage'
  ) then
    create policy challenge_categories_admin_manage
      on public.challenge_categories
      for all
      to authenticated
      using (public.is_admin_user(auth.uid()))
      with check (public.is_admin_user(auth.uid()));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgname = 'set_updated_at_challenge_categories'
  ) then
    create trigger set_updated_at_challenge_categories
      before update on public.challenge_categories
      for each row
      execute procedure public.set_updated_at();
  end if;
end $$;

do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public'
      and table_name = 'courses'
  ) then
    alter table public.courses add column if not exists category_id uuid references public.challenge_categories(id) on delete set null;
    alter table public.courses add column if not exists validity_days integer default 60;
    alter table public.courses add column if not exists updated_at timestamptz default now();
  end if;
end $$;

do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public'
      and table_name = 'exercises'
  ) then
    alter table public.exercises add column if not exists category_id uuid references public.challenge_categories(id) on delete set null;
    alter table public.exercises add column if not exists validity_days integer default 60;
    alter table public.exercises add column if not exists updated_at timestamptz default now();
  end if;
end $$;

create table if not exists public.admin_settings (
  setting_key text primary key,
  value_json jsonb not null default '{}'::jsonb,
  description text,
  updated_at timestamptz not null default now(),
  updated_by text
);

alter table public.admin_settings add column if not exists value_json jsonb not null default '{}'::jsonb;
alter table public.admin_settings add column if not exists description text;
alter table public.admin_settings add column if not exists updated_at timestamptz not null default now();
alter table public.admin_settings add column if not exists updated_by text;

insert into public.admin_settings (setting_key, value_json, description)
values
  (
    'pilot_mode',
    '{"enabled": false}'::jsonb,
    'Toggle global para desactivar paywalls durante pilotos'
  ),
  (
    'feature_flags',
    '{"feed": true, "desafios": true, "convocatorias": true}'::jsonb,
    'Feature flags básicos del producto'
  ),
  (
    'ui_texts',
    '{
      "blocked_action_title": "Acción bloqueada",
      "blocked_action_message": "Para acciones sensibles necesitas cuenta verificada y plan activo.",
      "challenge_upload_message": "Se abrirá la cámara para grabar tu intento.",
      "challenge_upload_success": "Intento enviado.",
      "feed_empty_label": "No hay videos disponibles por ahora."
    }'::jsonb,
    'Textos operativos editables desde admin'
  )
on conflict (setting_key) do nothing;

alter table public.admin_settings enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'admin_settings'
      and policyname = 'admin_settings_select_authenticated'
  ) then
    create policy admin_settings_select_authenticated
      on public.admin_settings
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
      and tablename = 'admin_settings'
      and policyname = 'admin_settings_admin_manage'
  ) then
    create policy admin_settings_admin_manage
      on public.admin_settings
      for all
      to authenticated
      using (public.is_admin_user(auth.uid()))
      with check (public.is_admin_user(auth.uid()));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgname = 'set_updated_at_admin_settings'
  ) then
    create trigger set_updated_at_admin_settings
      before update on public.admin_settings
      for each row
      execute procedure public.set_updated_at();
  end if;
end $$;

create table if not exists public.admin_user_feature_overrides (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  feature_key text not null,
  is_enabled boolean not null default true,
  notes text,
  updated_at timestamptz not null default now(),
  updated_by text,
  unique (user_id, feature_key)
);

alter table public.admin_user_feature_overrides add column if not exists notes text;
alter table public.admin_user_feature_overrides add column if not exists updated_at timestamptz not null default now();
alter table public.admin_user_feature_overrides add column if not exists updated_by text;

alter table public.admin_user_feature_overrides enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'admin_user_feature_overrides'
      and policyname = 'admin_user_feature_overrides_select_owner_or_admin'
  ) then
    create policy admin_user_feature_overrides_select_owner_or_admin
      on public.admin_user_feature_overrides
      for select
      to authenticated
      using (
        user_id::text = auth.uid()::text
        or public.is_admin_user(auth.uid())
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'admin_user_feature_overrides'
      and policyname = 'admin_user_feature_overrides_admin_manage'
  ) then
    create policy admin_user_feature_overrides_admin_manage
      on public.admin_user_feature_overrides
      for all
      to authenticated
      using (public.is_admin_user(auth.uid()))
      with check (public.is_admin_user(auth.uid()));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgname = 'set_updated_at_admin_user_feature_overrides'
  ) then
    create trigger set_updated_at_admin_user_feature_overrides
      before update on public.admin_user_feature_overrides
      for each row
      execute procedure public.set_updated_at();
  end if;
end $$;

do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public'
      and table_name = 'convocatorias'
  ) then
    alter table public.convocatorias add column if not exists updated_at timestamptz default now();
    alter table public.convocatorias add column if not exists categoria text;
    alter table public.convocatorias add column if not exists posicion text;
    alter table public.convocatorias add column if not exists pais text;
    alter table public.convocatorias add column if not exists ciudad text;
    alter table public.convocatorias add column if not exists imagen_url text;
    alter table public.convocatorias add column if not exists estado text default 'activa';
  end if;
end $$;

do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public'
      and table_name = 'convocatorias'
  ) then
    update public.convocatorias
    set estado = case when coalesce(is_active, true) then 'activa' else 'cerrada' end
    where coalesce(estado, '') = '';
  end if;
end $$;

do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public'
      and table_name = 'convocatorias'
  ) and not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'convocatorias'
      and policyname = 'convocatorias_admin_manage'
  ) then
    create policy convocatorias_admin_manage
      on public.convocatorias
      for all
      to authenticated
      using (public.is_admin_user(auth.uid()))
      with check (public.is_admin_user(auth.uid()));
  end if;
end $$;

do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public'
      and table_name = 'convocatorias'
  ) and not exists (
    select 1 from pg_trigger
    where tgname = 'set_updated_at_convocatorias_admin'
  ) then
    create trigger set_updated_at_convocatorias_admin
      before update on public.convocatorias
      for each row
      execute procedure public.set_updated_at();
  end if;
end $$;

do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public'
      and table_name = 'aplicaciones_convocatoria'
  ) and not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'aplicaciones_convocatoria'
      and policyname = 'aplicaciones_convocatoria_admin_select_all'
  ) then
    create policy aplicaciones_convocatoria_admin_select_all
      on public.aplicaciones_convocatoria
      for select
      to authenticated
      using (public.is_admin_user(auth.uid()));
  end if;
end $$;

do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public'
      and table_name = 'players'
  ) and not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'players'
      and policyname = 'players_admin_manage_all'
  ) then
    create policy players_admin_manage_all
      on public.players
      for all
      to authenticated
      using (public.is_admin_user(auth.uid()))
      with check (public.is_admin_user(auth.uid()));
  end if;
end $$;

do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public'
      and table_name = 'scouts'
  ) and not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'scouts'
      and policyname = 'scouts_admin_manage_all'
  ) then
    create policy scouts_admin_manage_all
      on public.scouts
      for all
      to authenticated
      using (public.is_admin_user(auth.uid()))
      with check (public.is_admin_user(auth.uid()));
  end if;
end $$;

do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public'
      and table_name = 'clubs'
  ) and not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'clubs'
      and policyname = 'clubs_admin_manage_all'
  ) then
    create policy clubs_admin_manage_all
      on public.clubs
      for all
      to authenticated
      using (public.is_admin_user(auth.uid()))
      with check (public.is_admin_user(auth.uid()));
  end if;
end $$;

commit;
