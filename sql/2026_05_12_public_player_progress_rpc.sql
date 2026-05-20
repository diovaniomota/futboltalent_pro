-- =====================================================================
-- FutbolTalent Pro - Public player progress for cross-role profile views
-- Fixes BUG-SCO-002: Scouts/Clubs should see the same player stats that
-- players see, without opening raw user_progress reads to anonymous users.
-- =====================================================================

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
  select
    up.user_id,
    coalesce(up.total_xp, 0)::integer as total_xp,
    coalesce(up.current_level_id, 1)::integer as current_level_id,
    coalesce(up.courses_completed, 0)::integer as courses_completed,
    coalesce(up.exercises_completed, 0)::integer as exercises_completed
  from public.user_progress up
  where up.user_id::text = any(coalesce(p_player_ids, array[]::text[]))
    and auth.uid() is not null
    and public.is_player_guardian_approved(up.user_id::text)
    and (
      up.user_id::text = auth.uid()::text
      or public.viewer_has_player_profile_access(up.user_id::text)
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
            'club'
          )
      )
    );
$$;

revoke all on function public.get_player_public_progress(text[]) from public;
revoke execute on function public.get_player_public_progress(text[]) from anon;
grant execute on function public.get_player_public_progress(text[]) to authenticated;

commit;
