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

alter function public.admin_delete_rows_by_text_values(text, text, text[])
owner to postgres;

revoke all on function public.admin_delete_rows_by_text_values(text, text, text[]) from public;
revoke execute on function public.admin_delete_rows_by_text_values(text, text, text[]) from anon;
revoke execute on function public.admin_delete_rows_by_text_values(text, text, text[]) from authenticated;

create or replace function public.delete_own_account()
returns jsonb
language plpgsql
security definer
set search_path = public, auth, storage
as $$
declare
  p_user_id uuid := auth.uid();
  v_user_id text;
  v_legacy_club_id text;
  v_identity_ids text[] := array[]::text[];
  v_club_ids text[] := array[]::text[];
  v_video_ids text[] := array[]::text[];
  v_comment_ids text[] := array[]::text[];
  v_convocatoria_ids text[] := array[]::text[];
  v_lista_ids text[] := array[]::text[];
  v_lista_club_ids text[] := array[]::text[];
  v_deleted_rows integer := 0;
  v_deleted_storage_objects integer := 0;
  v_deleted_auth_account boolean := false;
  rec record;
begin
  if p_user_id is null then
    raise exception 'auth_required';
  end if;

  v_user_id := p_user_id::text;
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

  -- Storage objects must be removed through the Storage API, not by deleting
  -- from storage.objects directly. The delete-own-account Edge Function handles
  -- that with the service role key before deleting the Auth account.

  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('comment_reports', 'comment_id', v_comment_ids);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('comment_reports', 'reporter_user_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('comments', 'video_id', v_video_ids);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('comments', 'user_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('likes', 'video_id', v_video_ids);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('likes', 'user_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('saved_videos', 'user_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('user_videos_saved', 'video_id', v_video_ids);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('user_videos_saved', 'user_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('user_challenge_attempts', 'video_id', v_video_ids);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('user_challenge_attempts', 'user_id', array[v_user_id]);
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
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('user_progress', 'user_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('user_courses', 'user_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('user_exercises', 'user_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('user_challenge_goals', 'user_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('followers', 'follower_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('followers', 'following_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('follows', 'follower_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('follows', 'following_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('contact_requests', 'requester_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('contact_requests', 'target_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('contact_requests', 'from_user_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('contact_requests', 'to_user_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('player_profile_views', 'player_user_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('player_profile_views', 'viewer_user_id', array[v_user_id]);
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
        'reporter_user_id',
        'requester_id',
        'target_id'
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

  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('videos', 'user_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('players', 'id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('scouts', 'id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('clubs', 'id', v_club_ids);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('clubs', 'owner_id', array[v_user_id]);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('clubes', 'id', v_identity_ids);
  v_deleted_rows := v_deleted_rows + public.admin_delete_rows_by_text_values('users', 'user_id', array[v_user_id]);

  return jsonb_build_object(
    'user_id', p_user_id,
    'deleted_auth_account', v_deleted_auth_account,
    'deleted_related_rows', v_deleted_rows,
    'deleted_storage_objects', v_deleted_storage_objects,
    'message', 'Datos relacionados eliminados correctamente. La cuenta Auth debe eliminarse con una operación admin del servidor.'
  );
end;
$$;

alter function public.delete_own_account()
owner to postgres;

revoke all on function public.delete_own_account() from public;
revoke execute on function public.delete_own_account() from anon;
grant execute on function public.delete_own_account() to authenticated;

commit;
