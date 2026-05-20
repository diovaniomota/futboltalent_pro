-- =====================================================================
-- FutbolTalent Pro - Security Hardening
-- Corrige RLS e GRANTs da tabela public.likes.
--
-- Objetivo:
--   - anon pode apenas ler likes de videos que ele ja pode ver.
--   - authenticated pode ler likes de videos visiveis.
--   - authenticated pode inserir/remover apenas o proprio like.
--   - admin pode remover likes para fluxos administrativos.
-- =====================================================================

begin;

alter table if exists public.likes enable row level security;

drop policy if exists "Users can insert their own likes" on public.likes;
drop policy if exists delete_own_like on public.likes;
drop policy if exists insert_own_like on public.likes;
drop policy if exists select_own_like on public.likes;
drop policy if exists "true" on public.likes;
drop policy if exists likes_select_visible_video on public.likes;
drop policy if exists likes_insert_own_visible_video on public.likes;
drop policy if exists likes_delete_own_or_admin on public.likes;

create policy likes_select_visible_video
  on public.likes
  for select
  to anon, authenticated
  using (
    exists (
      select 1
      from public.videos v
      where v.id = likes.video_id
    )
    or (
      auth.uid() is not null
      and public.is_admin_user(auth.uid())
    )
  );

create policy likes_insert_own_visible_video
  on public.likes
  for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1
      from public.videos v
      where v.id = likes.video_id
    )
  );

create policy likes_delete_own_or_admin
  on public.likes
  for delete
  to authenticated
  using (
    user_id = auth.uid()
    or (
      auth.uid() is not null
      and public.is_admin_user(auth.uid())
    )
  );

revoke all on public.likes from anon;
revoke all on public.likes from authenticated;

grant select on public.likes to anon, authenticated;
grant insert, delete on public.likes to authenticated;

commit;
