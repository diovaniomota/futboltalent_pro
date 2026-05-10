-- =====================================================================
-- FutbolTalent Pro - Security Hardening FIX
-- Corrige policy de videos para anon funcionar sem chamar 
-- viewer_has_player_profile_access (anon não tem GRANT nessa função)
-- 
-- APLICAR NO SUPABASE SQL EDITOR:
-- Dashboard → SQL Editor → New query → Colar e executar
-- =====================================================================

begin;

-- ─── 1. Remover policies antigas de videos (PERMISSIVE e RESTRICTIVE) ───
do $$
begin
  if to_regclass('public.videos') is not null then
    -- Drop ALL existing select policies on videos to start clean
    drop policy if exists videos_select_public_or_authorized on public.videos;
    drop policy if exists videos_select_public_or_authorized_restrictive on public.videos;
    drop policy if exists "videos_select_public_or_authorized" on public.videos;
    drop policy if exists "videos_select_public_or_authorized_restrictive" on public.videos;
    -- Drop any legacy policies that might exist
    drop policy if exists "Enable read access for all users" on public.videos;
    drop policy if exists "videos_select" on public.videos;
    drop policy if exists "videos_public_read" on public.videos;
    drop policy if exists "videos_select_anon" on public.videos;
    drop policy if exists "videos_select_authenticated" on public.videos;
  end if;
end;
$$;

-- ─── 2. Remover policies antigas de user_progress ───
do $$
begin
  if to_regclass('public.user_progress') is not null then
    drop policy if exists user_progress_select_player_or_authorized_viewer on public.user_progress;
    drop policy if exists user_progress_select_player_or_authorized_viewer_restrictive on public.user_progress;
    drop policy if exists user_progress_insert_own on public.user_progress;
    drop policy if exists user_progress_update_own on public.user_progress;
    -- Legacy
    drop policy if exists "Enable read access for all users" on public.user_progress;
    drop policy if exists "user_progress_select" on public.user_progress;
  end if;
end;
$$;

-- ─── 3. Garantir RLS está ativo ───
alter table if exists public.videos enable row level security;
alter table if exists public.user_progress enable row level security;

-- ─── 4. Garantir GRANTs corretos ───
-- anon pode executar is_player_guardian_approved (leitura pública)
-- anon NÃO pode executar viewer_has_player_profile_access (só authenticated)
revoke execute on function public.is_player_guardian_approved(text) from public;
revoke execute on function public.viewer_has_player_profile_access(text) from public;
revoke execute on function public.viewer_has_player_profile_access(text) from anon;
grant execute on function public.is_player_guardian_approved(text) to anon, authenticated;
grant execute on function public.viewer_has_player_profile_access(text) to authenticated;

-- ─── 5. VIDEOS: Policy para ANON (apenas public+approved+guardian_ok) ───
-- Esta é uma policy SEPARADA para anon, sem chamar viewer_has_player_profile_access
create policy videos_select_anon
  on public.videos
  for select
  to anon
  using (
    coalesce(is_public, false) = true
    and lower(coalesce(moderation_status, 'pending')) = 'approved'
    and public.is_player_guardian_approved(user_id::text)
  );

-- ─── 6. VIDEOS: Policy para AUTHENTICATED ───
-- Authenticated pode ver:
--   a) Vídeos públicos+aprovados de jogadores com guardian aprovado
--   b) Seus próprios vídeos (se guardian aprovado)
--   c) Vídeos públicos+aprovados via relação Scout/Club/postulação
create policy videos_select_authenticated
  on public.videos
  for select
  to authenticated
  using (
    -- Branch A: vídeos públicos + aprovados + guardian ok (mesmo que anon)
    (
      coalesce(is_public, false) = true
      and lower(coalesce(moderation_status, 'pending')) = 'approved'
      and public.is_player_guardian_approved(user_id::text)
    )
    -- Branch B: dono do vídeo vê seus próprios (se guardian ok)
    or (
      user_id::text = auth.uid()::text
      and public.is_player_guardian_approved(user_id::text)
    )
    -- Branch C: viewer autorizado (Scout/Club com relação válida)
    or (
      coalesce(is_public, false) = true
      and lower(coalesce(moderation_status, 'pending')) = 'approved'
      and public.viewer_has_player_profile_access(user_id::text)
    )
  );

-- ─── 7. VIDEOS: RESTRICTIVE policy (dupla barreira de segurança) ───
-- Esta policy RESTRICTIVE garante que MESMO que uma permissiva passe,
-- as condições mínimas são atendidas.
create policy videos_select_restrictive_guard
  on public.videos
  as restrictive
  for select
  to anon, authenticated
  using (
    -- Condição 1: vídeo público+aprovado de jogador com guardian ok
    (
      coalesce(is_public, false) = true
      and lower(coalesce(moderation_status, 'pending')) = 'approved'
      and public.is_player_guardian_approved(user_id::text)
    )
    -- Condição 2: OU é o próprio dono do vídeo com guardian ok
    or (
      auth.uid() is not null
      and user_id::text = auth.uid()::text
      and public.is_player_guardian_approved(user_id::text)
    )
  );

-- ─── 8. USER_PROGRESS: Policies ───
do $$
begin
  if to_regclass('public.user_progress') is not null then
    -- SELECT: jogador vê seu próprio OU viewer autorizado
    create policy user_progress_select_own_or_authorized
      on public.user_progress
      for select
      to authenticated
      using (
        (
          user_id::text = auth.uid()::text
          and public.is_player_guardian_approved(user_id::text)
        )
        or public.viewer_has_player_profile_access(user_id::text)
      );

    -- RESTRICTIVE: bloqueia anon e reforça regra
    create policy user_progress_restrictive_guard
      on public.user_progress
      as restrictive
      for select
      to anon, authenticated
      using (
        auth.uid() is not null
        and (
          (
            user_id::text = auth.uid()::text
            and public.is_player_guardian_approved(user_id::text)
          )
          or public.viewer_has_player_profile_access(user_id::text)
        )
      );

    -- INSERT: só próprio jogador
    create policy user_progress_insert_own
      on public.user_progress
      for insert
      to authenticated
      with check (
        user_id::text = auth.uid()::text
        and public.is_player_guardian_approved(user_id::text)
      );

    -- UPDATE: só próprio jogador
    create policy user_progress_update_own
      on public.user_progress
      for update
      to authenticated
      using (
        user_id::text = auth.uid()::text
        and public.is_player_guardian_approved(user_id::text)
      )
      with check (
        user_id::text = auth.uid()::text
        and public.is_player_guardian_approved(user_id::text)
      );

    -- GRANTs
    revoke all on public.user_progress from anon;
    grant select on public.user_progress to authenticated;
    grant insert on public.user_progress to authenticated;
    grant update on public.user_progress to authenticated;
  end if;
end;
$$;

-- ─── 9. Confirmar GRANTs de videos ───
grant select on public.videos to anon, authenticated;

-- ─── 10. Index de performance ───
create index if not exists videos_player_visibility_idx
  on public.videos (user_id, is_public, moderation_status);

commit;

-- ═══════════════════════════════════════════
-- VERIFICAÇÃO PÓS-APLICAÇÃO:
-- Execute separadamente para confirmar:
-- ═══════════════════════════════════════════
-- SELECT policyname, permissive, roles, cmd, qual 
-- FROM pg_policies 
-- WHERE tablename = 'videos';
-- 
-- SELECT policyname, permissive, roles, cmd, qual 
-- FROM pg_policies 
-- WHERE tablename = 'user_progress';
