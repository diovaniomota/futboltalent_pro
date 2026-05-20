-- =====================================================================
-- FutbolTalent Pro - Onboarding guardian approval fix
-- BUG-ONB-012: aprovação de menores deve funcionar desde a tela de login
-- usando código + email do responsável, sem exigir sessão ativa do menor.
--
-- APLICAR NO SUPABASE SQL EDITOR:
-- Dashboard -> SQL Editor -> New query -> Colar e executar
-- =====================================================================

begin;

alter table if exists public.guardians
  add column if not exists approval_code_expires_at timestamptz,
  add column if not exists approval_code_used_at timestamptz;

update public.guardians
set approval_code_expires_at = coalesce(
  approval_code_expires_at,
  now() + interval '7 days'
)
where approval_code is not null
  and approval_code_used_at is null
  and lower(coalesce(status, 'pending')) = 'pending';

create index if not exists guardians_player_status_idx
  on public.guardians (player_id, status);

create index if not exists guardians_approval_code_idx
  on public.guardians (approval_code)
  where approval_code is not null;

drop function if exists public.approve_guardian_by_code(text);
drop function if exists public.approve_guardian_by_code(text, text, text);

create or replace function public.approve_guardian_by_code(
  p_approval_code text,
  p_player_id text,
  p_guardian_email text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text := upper(btrim(coalesce(p_approval_code, '')));
  v_player_id text := btrim(coalesce(p_player_id, ''));
  v_guardian_email text := lower(btrim(coalesce(p_guardian_email, '')));
  guardian_row public.guardians%rowtype;
  updated_guardian public.guardians%rowtype;
begin
  if v_code = '' then
    raise exception 'approval_code_required'
      using errcode = '22023';
  end if;

  if v_guardian_email = '' then
    raise exception 'guardian_email_required'
      using errcode = '22023';
  end if;

  select g.*
    into guardian_row
  from public.guardians g
  where (v_player_id = '' or g.player_id::text = v_player_id)
    and lower(btrim(coalesce(g.email, ''))) = v_guardian_email
    and upper(btrim(coalesce(g.approval_code, ''))) = v_code
  order by g.created_at desc nulls last
  limit 1;

  if not found then
    raise exception 'approval_code_not_found'
      using errcode = '22023';
  end if;

  if lower(coalesce(guardian_row.status, 'pending')) <> 'pending' then
    raise exception 'approval_not_pending'
      using errcode = '22023';
  end if;

  if guardian_row.approval_code_used_at is not null then
    raise exception 'approval_code_used'
      using errcode = '22023';
  end if;

  if coalesce(
    guardian_row.approval_code_expires_at,
    now() - interval '1 second'
  ) <= now() then
    raise exception 'approval_code_expired'
      using errcode = '22023';
  end if;

  if not exists (
    select 1
    from public.users u
    where (
        coalesce(u.user_id::text, '') = guardian_row.player_id::text
        or coalesce(u.id::text, '') = guardian_row.player_id::text
      )
      and coalesce(u.is_minor, false) = true
      and lower(coalesce(u.guardian_status, 'pending')) <> 'approved'
  ) then
    raise exception 'approval_player_not_pending'
      using errcode = '22023';
  end if;

  update public.guardians
  set status = 'approved',
      approved_at = now(),
      approval_code_used_at = now(),
      approval_code = null
  where id = guardian_row.id
    and lower(coalesce(status, 'pending')) = 'pending'
    and approval_code_used_at is null
    and upper(btrim(coalesce(approval_code, ''))) = v_code
  returning * into updated_guardian;

  if not found then
    raise exception 'approval_code_used'
      using errcode = '22023';
  end if;

  update public.guardians
  set approval_code_used_at = coalesce(approval_code_used_at, now()),
      approval_code = null
  where player_id::text = updated_guardian.player_id::text
    and id <> updated_guardian.id
    and lower(btrim(coalesce(email, ''))) = v_guardian_email
    and upper(btrim(coalesce(approval_code, ''))) = v_code;

  update public.users
  set guardian_status = 'approved',
      visibility_status = 'active',
      has_guardian = true,
      updated_at = now()
  where coalesce(user_id::text, '') = updated_guardian.player_id::text
     or coalesce(id::text, '') = updated_guardian.player_id::text;

  update public.videos
  set moderation_status = 'approved',
      updated_at = now()
  where user_id::text = updated_guardian.player_id::text
    and lower(coalesce(moderation_status, 'pending')) = 'pending';

  return jsonb_build_object(
    'success', true,
    'guardian_id', updated_guardian.id,
    'player_id', updated_guardian.player_id,
    'status', updated_guardian.status
  );
end;
$$;

revoke execute on function public.approve_guardian_by_code(text, text, text)
  from public;
grant execute on function public.approve_guardian_by_code(text, text, text)
  to anon, authenticated;

commit;

-- VERIFICAÇÃO:
-- select public.approve_guardian_by_code('RESP-123456', '', 'responsavel@email.com');
