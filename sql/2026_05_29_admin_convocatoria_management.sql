begin;

create extension if not exists pgcrypto;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'convocatorias'
  ) then
    alter table public.convocatorias
      add column if not exists updated_at timestamptz default now(),
      add column if not exists categoria text,
      add column if not exists posicion text,
      add column if not exists pais text,
      add column if not exists ciudad text,
      add column if not exists estado text default 'activa',
      add column if not exists edad_min integer default 0;
  end if;
end $$;

create or replace function public.admin_delete_rows_for_values(
  p_table_name text,
  p_column_name text,
  p_values text[]
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_deleted integer := 0;
  v_values text[];
begin
  select coalesce(array_agg(distinct nullif(trim(value), '')), array[]::text[])
  into v_values
  from unnest(coalesce(p_values, array[]::text[])) as value
  where nullif(trim(value), '') is not null;

  if coalesce(array_length(v_values, 1), 0) = 0 then
    return 0;
  end if;

  if not exists (
    select 1
    from information_schema.columns c
    join information_schema.tables t
      on t.table_schema = c.table_schema
     and t.table_name = c.table_name
    where c.table_schema = 'public'
      and c.table_name = p_table_name
      and c.column_name = p_column_name
      and t.table_type = 'BASE TABLE'
  ) then
    return 0;
  end if;

  execute format(
    'delete from public.%I where %I::text = any($1)',
    p_table_name,
    p_column_name
  )
  using v_values;

  get diagnostics v_deleted = row_count;
  return coalesce(v_deleted, 0);
end;
$$;

revoke all on function public.admin_delete_rows_for_values(text, text, text[])
from public;

create or replace function public.admin_save_convocatoria(
  p_id text default null,
  p_titulo text default null,
  p_categoria text default null,
  p_posicion text default null,
  p_pais text default null,
  p_ciudad text default null,
  p_club_id text default null,
  p_is_active boolean default true,
  p_fecha_inicio timestamptz default null,
  p_fecha_fin timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_id text := nullif(trim(coalesce(p_id, '')), '');
  v_saved_id text;
  v_titulo text := coalesce(nullif(trim(coalesce(p_titulo, '')), ''), 'Convocatoria');
  v_ciudad text := coalesce(nullif(trim(coalesce(p_ciudad, '')), ''), 'Sin ubicación');
  v_estado text := case when coalesce(p_is_active, true) then 'activa' else 'cerrada' end;
begin
  if not public.is_admin_user(auth.uid()) then
    raise exception 'admin_only' using errcode = 'P0001';
  end if;

  if to_regclass('public.convocatorias') is null then
    raise exception 'convocatorias_table_missing' using errcode = 'P0001';
  end if;

  if v_id is null then
    insert into public.convocatorias (
      titulo,
      categoria,
      posicion,
      pais,
      ciudad,
      ubicacion,
      club_id,
      is_active,
      estado,
      fecha_inicio,
      fecha_fin,
      edad_min,
      created_at,
      updated_at
    )
    values (
      v_titulo,
      nullif(trim(coalesce(p_categoria, '')), ''),
      nullif(trim(coalesce(p_posicion, '')), ''),
      nullif(trim(coalesce(p_pais, '')), ''),
      v_ciudad,
      v_ciudad,
      nullif(trim(coalesce(p_club_id, '')), ''),
      coalesce(p_is_active, true),
      v_estado,
      p_fecha_inicio,
      p_fecha_fin,
      0,
      now(),
      now()
    )
    returning id::text into v_saved_id;
  else
    update public.convocatorias
    set
      titulo = v_titulo,
      categoria = nullif(trim(coalesce(p_categoria, '')), ''),
      posicion = nullif(trim(coalesce(p_posicion, '')), ''),
      pais = nullif(trim(coalesce(p_pais, '')), ''),
      ciudad = v_ciudad,
      ubicacion = v_ciudad,
      club_id = nullif(trim(coalesce(p_club_id, '')), ''),
      is_active = coalesce(p_is_active, true),
      estado = v_estado,
      fecha_inicio = p_fecha_inicio,
      fecha_fin = p_fecha_fin,
      updated_at = now()
    where id::text = v_id
    returning id::text into v_saved_id;

    if v_saved_id is null then
      raise exception 'convocatoria_not_found' using errcode = 'P0001';
    end if;
  end if;

  return jsonb_build_object(
    'id', v_saved_id,
    'message', 'Convocatoria guardada correctamente.'
  );
end;
$$;

revoke all on function public.admin_save_convocatoria(
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  boolean,
  timestamptz,
  timestamptz
) from public;
grant execute on function public.admin_save_convocatoria(
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  boolean,
  timestamptz,
  timestamptz
) to authenticated;

create or replace function public.admin_delete_convocatoria(
  p_convocatoria_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_id text := nullif(trim(coalesce(p_convocatoria_id, '')), '');
  v_deleted_rows integer := 0;
  v_deleted_convocatorias integer := 0;
  v_lista_ids text[] := array[]::text[];
  v_row_count integer := 0;
  rec record;
begin
  if not public.is_admin_user(auth.uid()) then
    raise exception 'admin_only' using errcode = 'P0001';
  end if;

  if v_id is null then
    raise exception 'convocatoria_id_required' using errcode = 'P0001';
  end if;

  if to_regclass('public.convocatorias') is null then
    raise exception 'convocatorias_table_missing' using errcode = 'P0001';
  end if;

  if to_regclass('public.listas') is not null then
    select coalesce(array_agg(id::text), array[]::text[])
    into v_lista_ids
    from public.listas
    where convocatoria_id::text = v_id;
  end if;

  v_deleted_rows := v_deleted_rows
    + public.admin_delete_rows_for_values(
      'activity_notifications',
      'entity_id',
      array[v_id] || v_lista_ids
    );

  v_deleted_rows := v_deleted_rows
    + public.admin_delete_rows_for_values(
      'listas_jugadores',
      'lista_id',
      v_lista_ids
    );

  for rec in
    select c.table_name
    from information_schema.columns c
    join information_schema.tables t
      on t.table_schema = c.table_schema
     and t.table_name = c.table_name
    where c.table_schema = 'public'
      and c.column_name = 'convocatoria_id'
      and c.table_name <> 'convocatorias'
      and t.table_type = 'BASE TABLE'
  loop
    v_deleted_rows := v_deleted_rows
      + public.admin_delete_rows_for_values(
        rec.table_name,
        'convocatoria_id',
        array[v_id]
      );
  end loop;

  if exists (
    select 1
    from information_schema.columns c
    join information_schema.tables t
      on t.table_schema = c.table_schema
     and t.table_name = c.table_name
    where c.table_schema = 'public'
      and c.table_name = 'activity_notifications'
      and c.column_name = 'payload'
      and t.table_type = 'BASE TABLE'
  ) then
    delete from public.activity_notifications
    where payload ->> 'convocatoria_id' = v_id;
    get diagnostics v_row_count = row_count;
    v_deleted_rows := v_deleted_rows + coalesce(v_row_count, 0);
  end if;

  delete from public.convocatorias
  where id::text = v_id;

  get diagnostics v_deleted_convocatorias = row_count;

  if coalesce(v_deleted_convocatorias, 0) = 0 then
    raise exception 'convocatoria_not_found' using errcode = 'P0001';
  end if;

  return jsonb_build_object(
    'id', v_id,
    'deleted_convocatorias', v_deleted_convocatorias,
    'deleted_related_rows', v_deleted_rows,
    'message', 'Convocatoria eliminada correctamente.'
  );
end;
$$;

revoke all on function public.admin_delete_convocatoria(text) from public;
grant execute on function public.admin_delete_convocatoria(text)
to authenticated;

commit;
