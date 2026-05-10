begin;

alter table if exists public.guardians
  add column if not exists approval_code_expires_at timestamptz,
  add column if not exists approval_code_used_at timestamptz;

update public.guardians
set approval_code_expires_at = coalesce(approval_code_expires_at, now() + interval '7 days')
where approval_code is not null
  and approval_code_used_at is null
  and lower(coalesce(status, 'pending')) = 'pending';

update public.guardians
set approval_code_used_at = coalesce(approval_code_used_at, approved_at, now()),
    approval_code = null
where approval_code is not null
  and lower(coalesce(status, '')) = 'approved';

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

  if v_player_id = '' or v_guardian_email = '' then
    raise exception 'approval_context_required'
      using errcode = '22023';
  end if;

  if auth.uid() is null or auth.uid()::text <> v_player_id then
    raise exception 'approval_context_required'
      using errcode = '42501';
  end if;

  select g.*
    into guardian_row
  from public.guardians g
  where g.player_id::text = v_player_id
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

  if coalesce(guardian_row.approval_code_expires_at, now() - interval '1 second') <= now() then
    raise exception 'approval_code_expired'
      using errcode = '22023';
  end if;

  if not exists (
    select 1
    from public.users u
    where u.user_id::text = v_player_id
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
  where player_id::text = v_player_id
    and id <> updated_guardian.id
    and lower(btrim(coalesce(email, ''))) = v_guardian_email
    and upper(btrim(coalesce(approval_code, ''))) = v_code;

  update public.users
  set guardian_status = 'approved',
      visibility_status = 'active',
      has_guardian = true,
      updated_at = now()
  where user_id::text = v_player_id;

  update public.videos
  set moderation_status = 'approved',
      updated_at = now()
  where user_id::text = v_player_id
    and lower(coalesce(moderation_status, 'pending')) = 'pending';

  return jsonb_build_object(
    'success', true,
    'guardian_id', updated_guardian.id,
    'player_id', updated_guardian.player_id,
    'status', updated_guardian.status
  );
end;
$$;

revoke execute on function public.approve_guardian_by_code(text, text, text) from public;
revoke execute on function public.approve_guardian_by_code(text, text, text) from anon;
grant execute on function public.approve_guardian_by_code(text, text, text) to authenticated;

create or replace function public.is_player_guardian_approved(p_player_id text)
returns boolean
language sql
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.users u
    where u.user_id::text = p_player_id
      and (
        coalesce(u.is_minor, false) = false
        or lower(coalesce(u.guardian_status, '')) = 'approved'
      )
      and lower(coalesce(u.visibility_status, 'active')) = 'active'
  );
$$;

create or replace function public.viewer_has_player_profile_access(p_player_id text)
returns boolean
language sql
stable
set search_path = public
as $$
  select
    auth.uid() is not null
    and public.is_player_guardian_approved(p_player_id)
    and (
      p_player_id = auth.uid()::text
      or exists (
        select 1
        from public.users viewer
        where viewer.user_id::text = auth.uid()::text
          and (
            coalesce(nullif(to_jsonb(viewer)->>'full_profile', '')::boolean, false) = true
            or case
              when coalesce(to_jsonb(viewer)->>'plan_id', '') ~ '^[0-9]+$'
              then (to_jsonb(viewer)->>'plan_id')::integer
              else 0
            end >= 2
            or coalesce(nullif(to_jsonb(viewer)->>'is_verified', '')::boolean, false) = true
            or lower(coalesce(to_jsonb(viewer)->>'verification_status', '')) in ('approved', 'aprobado', 'verified', 'verificado')
          )
      )
      or exists (
        select 1
        from public.jugadores_guardados js
        where js.scout_id::text = auth.uid()::text
          and js.jugador_id::text = p_player_id
      )
      or exists (
        select 1
        from public.listas_jugadores lj
        join public.listas l on l.id = lj.lista_id
        where lj.jugador_id::text = p_player_id
          and (
            l.profesional_id::text = auth.uid()::text
            or nullif(to_jsonb(l)->>'club_id', '') = auth.uid()::text
            or exists (
              select 1
              from public.club_staff cs
              where cs.club_id::text = nullif(to_jsonb(l)->>'club_id', '')
                and cs.user_id::text = auth.uid()::text
            )
          )
      )
      or exists (
        select 1
        from public.postulaciones p
        join public.convocatorias c on c.id = p.convocatoria_id
        left join public.club_staff cs on cs.club_id::text = nullif(to_jsonb(c)->>'club_id', '')
          and cs.user_id::text = auth.uid()::text
        where coalesce(
            nullif(to_jsonb(p)->>'player_id', ''),
            nullif(to_jsonb(p)->>'jugador_id', '')
          ) = p_player_id
          and (nullif(to_jsonb(c)->>'club_id', '') = auth.uid()::text or cs.user_id is not null)
          and lower(coalesce(to_jsonb(p)->>'status', 'pendiente')) in (
            'pendiente',
            'pending',
            'en_revision',
            'shortlisted',
            'aprobado',
            'approved',
            'accepted'
          )
      )
      or exists (
        select 1
        from public.aplicaciones_convocatoria a
        join public.convocatorias c on c.id = a.convocatoria_id
        left join public.club_staff cs on cs.club_id::text = nullif(to_jsonb(c)->>'club_id', '')
          and cs.user_id::text = auth.uid()::text
        where coalesce(
            nullif(to_jsonb(a)->>'player_id', ''),
            nullif(to_jsonb(a)->>'jugador_id', '')
          ) = p_player_id
          and (nullif(to_jsonb(c)->>'club_id', '') = auth.uid()::text or cs.user_id is not null)
          and lower(coalesce(to_jsonb(a)->>'status', 'pendiente')) in (
            'pendiente',
            'pending',
            'en_revision',
            'shortlisted',
            'aprobado',
            'approved',
            'accepted'
          )
      )
    );
$$;

revoke execute on function public.is_player_guardian_approved(text) from public;
revoke execute on function public.viewer_has_player_profile_access(text) from public;
grant execute on function public.is_player_guardian_approved(text) to anon, authenticated;
grant execute on function public.viewer_has_player_profile_access(text) to anon, authenticated;

do $$
begin
  if to_regclass('public.user_progress') is not null then
    alter table public.user_progress enable row level security;

    drop policy if exists user_progress_select_player_or_authorized_viewer on public.user_progress;
    drop policy if exists user_progress_select_player_or_authorized_viewer_restrictive on public.user_progress;
    drop policy if exists user_progress_insert_own on public.user_progress;
    drop policy if exists user_progress_update_own on public.user_progress;

    create policy user_progress_select_player_or_authorized_viewer
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

    create policy user_progress_select_player_or_authorized_viewer_restrictive
      on public.user_progress
      as restrictive
      for select
      to anon, authenticated
      using (
        (
          auth.uid() is not null
          and user_id::text = auth.uid()::text
          and public.is_player_guardian_approved(user_id::text)
        )
        or public.viewer_has_player_profile_access(user_id::text)
      );

    create policy user_progress_insert_own
      on public.user_progress
      for insert
      to authenticated
      with check (
        user_id::text = auth.uid()::text
        and public.is_player_guardian_approved(user_id::text)
      );

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

    grant select, insert, update on public.user_progress to authenticated;
  end if;
end;
$$;

do $$
begin
  if to_regclass('public.videos') is not null then
    alter table public.videos enable row level security;

    drop policy if exists videos_select_public_or_authorized on public.videos;
    drop policy if exists videos_select_public_or_authorized_restrictive on public.videos;

    create policy videos_select_public_or_authorized
      on public.videos
      for select
      to anon, authenticated
      using (
        (
          coalesce(is_public, false) = true
          and lower(coalesce(moderation_status, 'approved')) = 'approved'
          and public.is_player_guardian_approved(user_id::text)
        )
        or (
          auth.uid() is not null
          and user_id::text = auth.uid()::text
          and public.is_player_guardian_approved(user_id::text)
        )
        or (
          auth.uid() is not null
          and coalesce(is_public, false) = true
          and lower(coalesce(moderation_status, 'approved')) = 'approved'
          and public.viewer_has_player_profile_access(user_id::text)
        )
      );

    create policy videos_select_public_or_authorized_restrictive
      on public.videos
      as restrictive
      for select
      to anon, authenticated
      using (
        (
          coalesce(is_public, false) = true
          and lower(coalesce(moderation_status, 'approved')) = 'approved'
          and public.is_player_guardian_approved(user_id::text)
        )
        or (
          auth.uid() is not null
          and user_id::text = auth.uid()::text
          and public.is_player_guardian_approved(user_id::text)
        )
        or (
          auth.uid() is not null
          and coalesce(is_public, false) = true
          and lower(coalesce(moderation_status, 'approved')) = 'approved'
          and public.viewer_has_player_profile_access(user_id::text)
        )
      );

    create index if not exists videos_player_visibility_idx
      on public.videos (user_id, is_public, moderation_status);

    grant select on public.videos to anon, authenticated;
  end if;
end;
$$;

commit;
