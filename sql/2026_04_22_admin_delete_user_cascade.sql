begin;

create or replace function public.admin_delete_rows_by_text_values(
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

revoke all on function public.admin_delete_rows_by_text_values(text, text, text[]) from public;

create or replace function public.admin_delete_managed_user(
  p_user_id uuid,
  p_delete_auth_user boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id text := p_user_id::text;
  v_legacy_club_id text;
  v_identity_ids text[] := array[]::text[];
  v_club_ids text[] := array[]::text[];
  v_video_ids text[] := array[]::text[];
  v_comment_ids text[] := array[]::text[];
  v_convocatoria_ids text[] := array[]::text[];
  v_lista_ids text[] := array[]::text[];
  v_lista_club_ids text[] := array[]::text[];
  v_deleted_rows integer := 0;
  v_target_is_admin boolean := false;
  rec record;
begin
  if not public.is_admin_user(auth.uid()) then
    raise exception 'admin_only';
  end if;

  if auth.uid()::text = v_user_id then
    raise exception 'cannot_delete_self';
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'users'
      and column_name = 'is_admin'
  ) then
    execute
      'select exists (
         select 1
         from public.users
         where user_id::text = $1
           and coalesce(is_admin, false) = true
       )'
    into v_target_is_admin
    using v_user_id;
  end if;

  if not coalesce(v_target_is_admin, false) then
    for rec in
      select column_name
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'users'
        and column_name in ('userType', 'usertype', 'user_type')
    loop
      execute format(
        'select exists (
           select 1
           from public.users
           where user_id::text = $1
             and lower(coalesce(%I::text, '''')) = ''admin''
         )',
        rec.column_name
      )
      into v_target_is_admin
      using v_user_id;

      exit when coalesce(v_target_is_admin, false);
    end loop;
  end if;

  if v_target_is_admin then
    raise exception 'cannot_delete_admin_user';
  end if;

  v_legacy_club_id := left(regexp_replace(v_user_id, '[^a-zA-Z0-9]', '', 'g'), 10);
  v_identity_ids := array(
    select distinct u.value
    from unnest(array[v_user_id, v_legacy_club_id]) as u(value)
    where nullif(btrim(u.value), '') is not null
  );

  begin
    execute
      'select coalesce(array_agg(id::text), array[]::text[])
       from public.clubs
       where owner_id::text = $1 or id::text = $1'
    into v_club_ids
    using v_user_id;
  exception
    when undefined_table or undefined_column then
      v_club_ids := array[]::text[];
  end;

  v_club_ids := array(
    select distinct u.value
    from unnest(coalesce(v_club_ids, array[]::text[]) || v_identity_ids) as u(value)
    where nullif(btrim(u.value), '') is not null
  );

  begin
    execute
      'select coalesce(array_agg(id::text), array[]::text[])
       from public.videos
       where user_id::text = $1'
    into v_video_ids
    using v_user_id;
  exception
    when undefined_table or undefined_column then
      v_video_ids := array[]::text[];
  end;

  begin
    execute
      'select coalesce(array_agg(id::text), array[]::text[])
       from public.comments
       where user_id::text = $1 or video_id::text = any($2)'
    into v_comment_ids
    using v_user_id, v_video_ids;
  exception
    when undefined_table or undefined_column then
      v_comment_ids := array[]::text[];
  end;

  begin
    execute
      'select coalesce(array_agg(id::text), array[]::text[])
       from public.convocatorias
       where club_id::text = any($1)'
    into v_convocatoria_ids
    using v_club_ids;
  exception
    when undefined_table or undefined_column then
      v_convocatoria_ids := array[]::text[];
  end;

  begin
    execute
      'select coalesce(array_agg(id::text), array[]::text[])
       from public.listas
       where profesional_id::text = $1 or convocatoria_id::text = any($2)'
    into v_lista_ids
    using v_user_id, v_convocatoria_ids;
  exception
    when undefined_table or undefined_column then
      v_lista_ids := array[]::text[];
  end;

  begin
    execute
      'select coalesce(array_agg(id::text), array[]::text[])
       from public.listas_club
       where club_id::text = any($1)'
    into v_lista_club_ids
    using v_club_ids;
  exception
    when undefined_table or undefined_column then
      v_lista_club_ids := array[]::text[];
  end;

  -- Content children first.
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('comment_reports', 'comment_id', v_comment_ids);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('comment_reports', 'reporter_user_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('comments', 'video_id', v_video_ids);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('comments', 'user_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('likes', 'video_id', v_video_ids);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('likes', 'user_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('user_videos_saved', 'video_id', v_video_ids);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('user_videos_saved', 'user_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('user_challenge_attempts', 'video_id', v_video_ids);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('user_challenge_attempts', 'user_id', array[v_user_id]);

  -- User-owned activity and gamification.
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('activity_notifications', 'user_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('activity_notifications', 'entity_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('activity_notifications', 'entity_id', v_club_ids);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('activity_notifications', 'entity_id', v_video_ids);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('activity_notifications', 'entity_id', v_comment_ids);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('activity_notifications', 'entity_id', v_convocatoria_ids);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('activity_notifications', 'entity_id', v_lista_ids || v_lista_club_ids);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('feedback', 'user_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('admin_user_feature_overrides', 'user_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('user_badges', 'user_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('user_stats', 'user_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('user_challenge_goals', 'user_id', array[v_user_id]);

  -- Social graph and contact records.
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('followers', 'follower_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('followers', 'following_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('follows', 'follower_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('follows', 'following_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('contact_requests', 'from_user_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('contact_requests', 'to_user_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('player_profile_views', 'player_user_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('player_profile_views', 'viewer_user_id', array[v_user_id]);

  -- Player/scout/club operational relations.
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('guardians', 'player_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('jugadores_guardados', 'scout_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('jugadores_guardados', 'jugador_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('listas_jugadores', 'jugador_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('listas_jugadores', 'lista_id', v_lista_ids);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('listas_jugadores', 'lista_id', v_lista_club_ids);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('aplicaciones_convocatoria', 'jugador_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('aplicaciones_convocatoria', 'convocatoria_id', v_convocatoria_ids);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('postulaciones', 'player_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('postulaciones', 'convocatoria_id', v_convocatoria_ids);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('listas', 'profesional_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('listas', 'convocatoria_id', v_convocatoria_ids);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('listas_club', 'club_id', v_club_ids);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('convocatorias', 'club_id', v_club_ids);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('club_staff', 'user_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('club_staff', 'club_id', v_club_ids);

  -- Generic safety net for tables added later with common relationship columns.
  for rec in
    select c.table_name, c.column_name
    from information_schema.columns c
    join information_schema.tables t
      on t.table_schema = c.table_schema
     and t.table_name = c.table_name
    where c.table_schema = 'public'
      and t.table_type = 'BASE TABLE'
      and c.column_name in ('video_id', 'comment_id', 'lista_id', 'convocatoria_id')
  loop
    if rec.column_name = 'video_id' then
      v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values(rec.table_name, rec.column_name, v_video_ids);
    elsif rec.column_name = 'comment_id' then
      v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values(rec.table_name, rec.column_name, v_comment_ids);
    elsif rec.column_name = 'lista_id' then
      v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values(rec.table_name, rec.column_name, v_lista_ids || v_lista_club_ids);
    elsif rec.column_name = 'convocatoria_id' then
      v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values(rec.table_name, rec.column_name, v_convocatoria_ids);
    end if;
  end loop;

  for rec in
    select c.table_name, c.column_name
    from information_schema.columns c
    join information_schema.tables t
      on t.table_schema = c.table_schema
     and t.table_name = c.table_name
    where c.table_schema = 'public'
      and t.table_type = 'BASE TABLE'
      and c.column_name in (
        'user_id',
        'player_id',
        'jugador_id',
        'scout_id',
        'profesional_id',
        'follower_id',
        'following_id',
        'from_user_id',
        'to_user_id',
        'viewer_user_id',
        'player_user_id',
        'reporter_user_id'
      )
      and c.table_name not in ('users')
  loop
    v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values(rec.table_name, rec.column_name, array[v_user_id]);
  end loop;

  for rec in
    select c.table_name, c.column_name
    from information_schema.columns c
    join information_schema.tables t
      on t.table_schema = c.table_schema
     and t.table_name = c.table_name
    where c.table_schema = 'public'
      and t.table_type = 'BASE TABLE'
      and c.column_name in ('club_id', 'owner_id')
      and c.table_name not in ('clubs')
  loop
    if rec.column_name = 'club_id' then
      v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values(rec.table_name, rec.column_name, v_club_ids);
    else
      v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values(rec.table_name, rec.column_name, array[v_user_id]);
    end if;
  end loop;

  -- Main profile rows last.
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('videos', 'user_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('players', 'id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('scouts', 'id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('clubs', 'id', v_club_ids);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('clubs', 'owner_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('clubes', 'id', v_identity_ids);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('users', 'user_id', array[v_user_id]);

  if p_delete_auth_user then
    begin
      delete from auth.sessions where user_id = p_user_id;
    exception
      when undefined_table then null;
    end;

    begin
      delete from auth.refresh_tokens where user_id = p_user_id;
    exception
      when undefined_table then null;
    end;

    delete from auth.identities
    where user_id = p_user_id;

    delete from auth.users
    where id = p_user_id;
  end if;

  return jsonb_build_object(
    'user_id', p_user_id,
    'deleted_auth_account', p_delete_auth_user,
    'deleted_related_rows', v_deleted_rows,
    'message', case
      when p_delete_auth_user then 'Usuario, acceso y datos relacionados eliminados correctamente.'
      else 'Perfil operativo y datos relacionados eliminados.'
    end
  );
end;
$$;

revoke all on function public.admin_delete_managed_user(uuid, boolean) from public;
grant execute on function public.admin_delete_managed_user(uuid, boolean) to authenticated;

commit;
