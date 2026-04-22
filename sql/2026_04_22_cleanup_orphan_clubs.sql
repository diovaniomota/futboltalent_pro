begin;

create or replace function pg_temp.delete_rows_by_text_values(
  p_table_name text,
  p_column_name text,
  p_values text[]
)
returns integer
language plpgsql
as $$
declare
  v_values text[];
  v_deleted integer := 0;
begin
  select coalesce(array_agg(distinct v), array[]::text[])
  into v_values
  from (
    select nullif(btrim(u.value), '') as v
    from unnest(coalesce(p_values, array[]::text[])) as u(value)
  ) values_to_delete
  where v is not null;

  if coalesce(array_length(v_values, 1), 0) = 0 then
    return 0;
  end if;

  if to_regclass(format('public.%I', p_table_name)) is null then
    return 0;
  end if;

  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = p_table_name
      and column_name = p_column_name
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

do $$
declare
  v_user_type_col text;
  v_orphan_club_ids text[] := array[]::text[];
  v_orphan_owner_ids text[] := array[]::text[];
  v_orphan_legacy_ids text[] := array[]::text[];
  v_orphan_refs text[] := array[]::text[];
  v_convocatoria_ids text[] := array[]::text[];
  v_lista_ids text[] := array[]::text[];
  v_lista_club_ids text[] := array[]::text[];
begin
  if to_regclass('public.users') is null then
    return;
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'users'
      and column_name = 'userType'
  ) then
    v_user_type_col := '"userType"';
  elsif exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'users'
      and column_name = 'usertype'
  ) then
    v_user_type_col := 'usertype';
  elsif exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'users'
      and column_name = 'user_type'
  ) then
    v_user_type_col := 'user_type';
  else
    return;
  end if;

  create temp table tmp_valid_club_refs (
    ref text primary key
  ) on commit drop;

  execute format(
    $sql$
      insert into tmp_valid_club_refs (ref)
      select distinct ref
      from (
        select u.user_id::text as ref
        from public.users u
        where lower(coalesce(u.%1$s::text, '')) in ('club', 'clube', 'club_staff', 'club-staff', 'staff')
        union all
        select left(regexp_replace(u.user_id::text, '[^a-zA-Z0-9]', '', 'g'), 10) as ref
        from public.users u
        where lower(coalesce(u.%1$s::text, '')) in ('club', 'clube', 'club_staff', 'club-staff', 'staff')
      ) refs
      where nullif(btrim(ref), '') is not null
      on conflict do nothing
    $sql$,
    v_user_type_col
  );

  if to_regclass('public.clubs') is not null then
    select
      coalesce(array_agg(c.id::text), array[]::text[]),
      coalesce(array_agg(c.owner_id::text), array[]::text[])
    into v_orphan_club_ids, v_orphan_owner_ids
    from public.clubs c
    where nullif(btrim(c.owner_id::text), '') is null
       or not exists (
         select 1
         from tmp_valid_club_refs r
         where r.ref = c.owner_id::text
       );
  end if;

  if to_regclass('public.clubes') is not null then
    select coalesce(array_agg(c.id::text), array[]::text[])
    into v_orphan_legacy_ids
    from public.clubes c
    where not exists (
      select 1
      from tmp_valid_club_refs r
      where r.ref = c.id::text
    );
  end if;

  v_orphan_refs := array(
    select distinct u.value
    from unnest(
      coalesce(v_orphan_club_ids, array[]::text[]) ||
      coalesce(v_orphan_owner_ids, array[]::text[]) ||
      coalesce(v_orphan_legacy_ids, array[]::text[])
    ) as u(value)
    where nullif(btrim(u.value), '') is not null
  );

  if coalesce(array_length(v_orphan_refs, 1), 0) = 0 then
    return;
  end if;

  if to_regclass('public.convocatorias') is not null then
    select coalesce(array_agg(id::text), array[]::text[])
    into v_convocatoria_ids
    from public.convocatorias
    where club_id::text = any(v_orphan_refs);
  end if;

  if to_regclass('public.listas') is not null then
    select coalesce(array_agg(id::text), array[]::text[])
    into v_lista_ids
    from public.listas
    where convocatoria_id::text = any(v_convocatoria_ids);
  end if;

  if to_regclass('public.listas_club') is not null then
    select coalesce(array_agg(id::text), array[]::text[])
    into v_lista_club_ids
    from public.listas_club
    where club_id::text = any(v_orphan_refs);
  end if;

  perform pg_temp.delete_rows_by_text_values('activity_notifications', 'entity_id', v_orphan_refs);
  perform pg_temp.delete_rows_by_text_values('activity_notifications', 'entity_id', v_convocatoria_ids);
  perform pg_temp.delete_rows_by_text_values('activity_notifications', 'entity_id', v_lista_ids || v_lista_club_ids);
  perform pg_temp.delete_rows_by_text_values('listas_jugadores', 'lista_id', v_lista_ids || v_lista_club_ids);
  perform pg_temp.delete_rows_by_text_values('aplicaciones_convocatoria', 'convocatoria_id', v_convocatoria_ids);
  perform pg_temp.delete_rows_by_text_values('postulaciones', 'convocatoria_id', v_convocatoria_ids);
  perform pg_temp.delete_rows_by_text_values('listas', 'id', v_lista_ids);
  perform pg_temp.delete_rows_by_text_values('listas', 'convocatoria_id', v_convocatoria_ids);
  perform pg_temp.delete_rows_by_text_values('listas_club', 'id', v_lista_club_ids);
  perform pg_temp.delete_rows_by_text_values('listas_club', 'club_id', v_orphan_refs);
  perform pg_temp.delete_rows_by_text_values('club_staff', 'club_id', v_orphan_refs);
  perform pg_temp.delete_rows_by_text_values('convocatorias', 'id', v_convocatoria_ids);
  perform pg_temp.delete_rows_by_text_values('convocatorias', 'club_id', v_orphan_refs);
  perform pg_temp.delete_rows_by_text_values('clubs', 'id', v_orphan_club_ids);
  perform pg_temp.delete_rows_by_text_values('clubs', 'owner_id', v_orphan_owner_ids);
  perform pg_temp.delete_rows_by_text_values('clubes', 'id', v_orphan_legacy_ids);
end $$;

commit;
