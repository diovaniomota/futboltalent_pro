begin;

create or replace function public.get_player_public_progress(
  p_player_ids text[]
)
returns table (
  user_id uuid,
  total_xp integer,
  current_level_id integer,
  courses_completed integer,
  exercises_completed integer
)
language sql
stable
security definer
set search_path = public, auth
as $$
  with requested_players as (
    select distinct id::uuid as user_id
    from unnest(coalesce(p_player_ids, array[]::text[])) as raw(id)
    where nullif(btrim(raw.id), '') is not null
  ),
  completed_courses as (
    select
      uc.user_id,
      count(distinct uc.course_id)::integer as completed_count
    from public.user_courses uc
    join requested_players rp on rp.user_id = uc.user_id
    where lower(coalesce(uc.status::text, '')) = 'completed'
    group by uc.user_id
  ),
  completed_exercises as (
    select
      ue.user_id,
      count(distinct ue.exercise_id)::integer as completed_count
    from public.user_exercises ue
    join requested_players rp on rp.user_id = ue.user_id
    where lower(coalesce(ue.status::text, '')) = 'completed'
    group by ue.user_id
  )
  select
    rp.user_id,
    greatest(coalesce(up.total_xp, 0), 0)::integer as total_xp,
    greatest(coalesce(up.current_level_id, 1), 1)::integer as current_level_id,
    greatest(
      coalesce(up.courses_completed, 0),
      coalesce(cc.completed_count, 0)
    )::integer as courses_completed,
    greatest(
      coalesce(up.exercises_completed, 0),
      coalesce(ce.completed_count, 0)
    )::integer as exercises_completed
  from requested_players rp
  left join public.user_progress up on up.user_id = rp.user_id
  left join completed_courses cc on cc.user_id = rp.user_id
  left join completed_exercises ce on ce.user_id = rp.user_id
  where auth.uid() is not null
    and public.is_player_guardian_approved(rp.user_id::text)
    and (
      rp.user_id::text = auth.uid()::text
      or public.viewer_has_player_profile_access(rp.user_id::text)
      or exists (
        select 1
        from public.users viewer
        where viewer.user_id::text = auth.uid()::text
          and lower(coalesce(
            to_jsonb(viewer)->>'userType',
            to_jsonb(viewer)->>'usertype',
            to_jsonb(viewer)->>'user_type',
            ''
          )) in (
            'profesional',
            'professional',
            'scout',
            'club',
            'club_staff'
          )
      )
    );
$$;

revoke all on function public.get_player_public_progress(text[]) from public;
revoke execute on function public.get_player_public_progress(text[]) from anon;
grant execute on function public.get_player_public_progress(text[]) to authenticated;

commit;
