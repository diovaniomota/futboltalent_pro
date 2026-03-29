begin;

create extension if not exists pgcrypto;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'users'
  ) then
    alter table public.users
      add column if not exists player_status text;
  end if;
end $$;

create table if not exists public.player_profile_views (
  id uuid primary key default gen_random_uuid(),
  player_user_id text not null,
  viewer_user_id text not null,
  viewed_on date not null default current_date,
  viewed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (player_user_id, viewer_user_id, viewed_on)
);

create index if not exists player_profile_views_player_idx
  on public.player_profile_views (player_user_id, viewed_at desc);

create index if not exists player_profile_views_viewer_idx
  on public.player_profile_views (viewer_user_id, viewed_at desc);

alter table public.player_profile_views enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'player_profile_views'
      and policyname = 'player_profile_views_select_owner'
  ) then
    create policy player_profile_views_select_owner
      on public.player_profile_views
      for select
      to authenticated
      using (player_user_id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'player_profile_views'
      and policyname = 'player_profile_views_insert_viewer'
  ) then
    create policy player_profile_views_insert_viewer
      on public.player_profile_views
      for insert
      to authenticated
      with check (
        viewer_user_id::text = auth.uid()::text
        and player_user_id::text <> auth.uid()::text
      );
  end if;
end $$;

create or replace function public.register_player_profile_view(
  p_player_user_id text
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null then
    return;
  end if;

  if nullif(trim(coalesce(p_player_user_id, '')), '') is null then
    return;
  end if;

  if p_player_user_id::text = auth.uid()::text then
    return;
  end if;

  insert into public.player_profile_views (
    player_user_id,
    viewer_user_id,
    viewed_on,
    viewed_at
  )
  values (
    p_player_user_id,
    auth.uid()::text,
    current_date,
    now()
  )
  on conflict (player_user_id, viewer_user_id, viewed_on)
  do update
    set viewed_at = excluded.viewed_at;
end;
$$;

revoke all on function public.register_player_profile_view(text) from public;
grant execute on function public.register_player_profile_view(text)
to authenticated;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'convocatorias'
  ) then
    alter table public.convocatorias
      add column if not exists required_challenges jsonb not null default '[]'::jsonb;

    update public.convocatorias
    set required_challenges = '[]'::jsonb
    where required_challenges is null;
  end if;
end $$;

create or replace function public.convocatoria_required_challenges_completed(
  p_convocatoria_id text,
  p_user_id text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_required jsonb := '[]'::jsonb;
  v_item jsonb;
  v_item_id text;
  v_item_type text;
  v_is_completed boolean;
begin
  if nullif(trim(coalesce(p_convocatoria_id, '')), '') is null
     or nullif(trim(coalesce(p_user_id, '')), '') is null then
    return false;
  end if;

  select coalesce(required_challenges, '[]'::jsonb)
  into v_required
  from public.convocatorias
  where id::text = p_convocatoria_id
  limit 1;

  if coalesce(jsonb_array_length(v_required), 0) = 0 then
    return true;
  end if;

  for v_item in
    select value
    from jsonb_array_elements(v_required)
  loop
    v_item_id := nullif(trim(coalesce(v_item ->> 'id', '')), '');
    v_item_type := lower(trim(coalesce(v_item ->> 'type', '')));

    if v_item_id is null or v_item_type not in ('course', 'exercise') then
      continue;
    end if;

    if v_item_type = 'course' then
      if not exists (
        select 1
        from information_schema.tables
        where table_schema = 'public'
          and table_name = 'user_courses'
      ) then
        return false;
      end if;

      select exists (
        select 1
        from public.user_courses uc
        where uc.user_id::text = p_user_id
          and uc.course_id::text = v_item_id
          and lower(coalesce(uc.status::text, '')) = 'completed'
      )
      into v_is_completed;
    else
      if not exists (
        select 1
        from information_schema.tables
        where table_schema = 'public'
          and table_name = 'user_exercises'
      ) then
        return false;
      end if;

      select exists (
        select 1
        from public.user_exercises ue
        where ue.user_id::text = p_user_id
          and ue.exercise_id::text = v_item_id
          and lower(coalesce(ue.status::text, '')) = 'completed'
      )
      into v_is_completed;
    end if;

    if not coalesce(v_is_completed, false) then
      return false;
    end if;
  end loop;

  return true;
end;
$$;

revoke all on function public.convocatoria_required_challenges_completed(text, text)
from public;
grant execute on function public.convocatoria_required_challenges_completed(text, text)
to authenticated;

create or replace function public.enforce_convocatoria_requirements_before_apply()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if not public.convocatoria_required_challenges_completed(
    new.convocatoria_id::text,
    new.jugador_id::text
  ) then
    raise exception
      'Debes completar los desafíos requeridos antes de enviar tu postulación.'
      using errcode = 'P0001',
            hint = 'Completá todos los desafíos marcados como requeridos en la convocatoria.';
  end if;

  return new;
end;
$$;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'aplicaciones_convocatoria'
  ) then
    if exists (
      select 1
      from pg_trigger
      where tgname = 'trg_aplicaciones_convocatoria_requirements'
    ) then
      drop trigger trg_aplicaciones_convocatoria_requirements
        on public.aplicaciones_convocatoria;
    end if;

    create trigger trg_aplicaciones_convocatoria_requirements
      before insert on public.aplicaciones_convocatoria
      for each row
      execute function public.enforce_convocatoria_requirements_before_apply();
  end if;
end $$;

commit;
