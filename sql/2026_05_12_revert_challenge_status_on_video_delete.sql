-- =====================================================================
-- FutbolTalent Pro - BUG-VID-001
-- Reverte status de desafio quando o vídeo associado é excluído/ocultado.
-- =====================================================================

begin;

create schema if not exists app_private;

alter table if exists public.videos
  add column if not exists is_deleted boolean not null default false;

alter table if exists public.videos
  add column if not exists deleted_at timestamptz;

create index if not exists user_challenge_attempts_video_ref_idx
  on public.user_challenge_attempts (user_id, video_id, video_url);

create or replace function app_private.revert_challenge_status_for_video(
  p_user_id uuid,
  p_video_id uuid,
  p_video_url text,
  p_description text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  r record;
  v_has_other_valid_attempt boolean;
  v_course_payload text;
  v_exercise_payload text;
begin
  if p_user_id is null then
    return;
  end if;

  for r in
    select distinct lower(coalesce(a.item_type, '')) as item_type,
           coalesce(a.item_id, '') as item_id
    from public.user_challenge_attempts a
    where a.user_id = p_user_id::text
      and (
        a.video_id = p_video_id::text
        or (
          coalesce(p_video_url, '') <> ''
          and coalesce(a.video_url, '') = p_video_url
        )
      )

    union

    select distinct lower((m)[1]) as item_type,
           (m)[2] as item_id
    from regexp_matches(
      coalesce(p_description, ''),
      '\[challenge_ref:(course|exercise):([^\]]+)\]',
      'g'
    ) as m
  loop
    if r.item_type not in ('course', 'exercise') or r.item_id = '' then
      continue;
    end if;

    select exists (
      select 1
      from public.user_challenge_attempts a
      join public.videos v
        on (
          (
            coalesce(a.video_id, '') <> ''
            and v.id::text = a.video_id
          )
          or (
            coalesce(a.video_url, '') <> ''
            and coalesce(v.video_url, '') = a.video_url
          )
        )
      where a.user_id = p_user_id::text
        and lower(coalesce(a.item_type, '')) = r.item_type
        and coalesce(a.item_id, '') = r.item_id
        and lower(coalesce(a.status, '')) in ('submitted', 'completed', 'in_progress')
        and coalesce(a.video_id, '') <> p_video_id::text
        and (
          coalesce(p_video_url, '') = ''
          or coalesce(a.video_url, '') <> p_video_url
        )
        and v.user_id = p_user_id
        and coalesce(v.is_public, false) = true
        and coalesce(v.is_deleted, false) = false
        and v.deleted_at is null
        and coalesce(v.video_url, '') <> ''
      limit 1
    )
    into v_has_other_valid_attempt;

    if v_has_other_valid_attempt then
      continue;
    end if;

    if r.item_type = 'course' and to_regclass('public.user_courses') is not null then
      v_course_payload := 'status = ''not_started''';

      if exists (
        select 1 from information_schema.columns
        where table_schema = 'public'
          and table_name = 'user_courses'
          and column_name = 'progress_percent'
      ) then
        v_course_payload := v_course_payload || ', progress_percent = 0';
      end if;

      if exists (
        select 1 from information_schema.columns
        where table_schema = 'public'
          and table_name = 'user_courses'
          and column_name = 'xp_earned'
      ) then
        v_course_payload := v_course_payload || ', xp_earned = 0';
      end if;

      execute format(
        'update public.user_courses set %s where user_id = $1 and course_id::text = $2 and lower(coalesce(status, '''')) in (''completed'', ''in_progress'')',
        v_course_payload
      )
      using p_user_id, r.item_id;
    elsif r.item_type = 'exercise' and to_regclass('public.user_exercises') is not null then
      v_exercise_payload := 'status = ''not_started''';

      if exists (
        select 1 from information_schema.columns
        where table_schema = 'public'
          and table_name = 'user_exercises'
          and column_name = 'total_xp_earned'
      ) then
        v_exercise_payload := v_exercise_payload || ', total_xp_earned = 0';
      end if;

      execute format(
        'update public.user_exercises set %s where user_id = $1 and exercise_id::text = $2 and lower(coalesce(status, '''')) in (''completed'', ''in_progress'')',
        v_exercise_payload
      )
      using p_user_id, r.item_id;
    end if;
  end loop;

  delete from public.user_challenge_attempts a
  where a.user_id = p_user_id::text
    and (
      a.video_id = p_video_id::text
      or (
        coalesce(p_video_url, '') <> ''
        and coalesce(a.video_url, '') = p_video_url
      )
    );
end;
$$;

create or replace function app_private.revert_challenge_status_for_video_trigger()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'DELETE' then
    perform app_private.revert_challenge_status_for_video(
      old.user_id,
      old.id,
      old.video_url,
      old.description
    );
    return old;
  end if;

  if tg_op = 'UPDATE' then
    if (
      coalesce(old.is_public, false) is distinct from coalesce(new.is_public, false)
      and coalesce(new.is_public, false) = false
    )
    or (
      coalesce(old.is_deleted, false) is distinct from coalesce(new.is_deleted, false)
      and coalesce(new.is_deleted, false) = true
    )
    or (
      old.deleted_at is distinct from new.deleted_at
      and new.deleted_at is not null
    ) then
      perform app_private.revert_challenge_status_for_video(
        old.user_id,
        old.id,
        old.video_url,
        old.description
      );
    end if;

    return new;
  end if;

  return null;
end;
$$;

drop trigger if exists videos_revert_challenge_status_on_delete
  on public.videos;

create trigger videos_revert_challenge_status_on_delete
  after delete on public.videos
  for each row
  execute function app_private.revert_challenge_status_for_video_trigger();

drop trigger if exists videos_revert_challenge_status_on_hide
  on public.videos;

create trigger videos_revert_challenge_status_on_hide
  after update of is_public, is_deleted, deleted_at on public.videos
  for each row
  execute function app_private.revert_challenge_status_for_video_trigger();

revoke all on schema app_private from public;
revoke all on all functions in schema app_private from public;

commit;

