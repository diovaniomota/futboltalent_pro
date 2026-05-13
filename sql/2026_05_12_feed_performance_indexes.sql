-- =====================================================================
-- FutbolTalent Pro - Feed Performance
-- Reduz payload dos feeds principais e acelera contagem de comentários
-- usada no carregamento inicial.
-- =====================================================================

begin;

create index if not exists comments_video_id_visible_idx
  on public.comments (video_id)
  where deleted_at is null;

create index if not exists videos_public_feed_visible_idx
  on public.videos (created_at desc)
  where is_public is true
    and coalesce(is_deleted, false) = false
    and deleted_at is null;

create or replace function public.video_comment_counts(p_video_ids uuid[])
returns table(video_id uuid, comments_count bigint)
language sql
stable
security invoker
set search_path = public
as $$
  select c.video_id, count(*)::bigint as comments_count
  from public.comments c
  where c.video_id = any(coalesce(p_video_ids, array[]::uuid[]))
    and c.deleted_at is null
    and lower(coalesce(c.moderation_status, 'approved')) = 'approved'
  group by c.video_id
$$;

revoke all on function public.video_comment_counts(uuid[]) from public;
grant execute on function public.video_comment_counts(uuid[]) to anon, authenticated;

commit;
