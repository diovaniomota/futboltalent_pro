-- =====================================================================
-- FutbolTalent Pro - Scout requests for convocatorias
-- Fix BUG-SCO-003: Scout "Solicitar" must not reuse player application
-- tables/triggers that validate required player challenges.
-- =====================================================================

begin;

create table if not exists public.convocatoria_scout_requests (
  id uuid primary key default gen_random_uuid(),
  convocatoria_id text not null,
  scout_id text not null,
  club_user_id text,
  status text not null default 'pending',
  message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.convocatoria_scout_requests
  add column if not exists convocatoria_id text,
  add column if not exists scout_id text,
  add column if not exists club_user_id text,
  add column if not exists status text default 'pending',
  add column if not exists message text,
  add column if not exists created_at timestamptz default now(),
  add column if not exists updated_at timestamptz default now();

update public.convocatoria_scout_requests
set status = 'pending'
where nullif(trim(coalesce(status, '')), '') is null;

alter table public.convocatoria_scout_requests
  alter column status set default 'pending';

create unique index if not exists convocatoria_scout_requests_unique_idx
  on public.convocatoria_scout_requests (convocatoria_id, scout_id);

create index if not exists convocatoria_scout_requests_convocatoria_idx
  on public.convocatoria_scout_requests (convocatoria_id, created_at desc);

create index if not exists convocatoria_scout_requests_scout_idx
  on public.convocatoria_scout_requests (scout_id, created_at desc);

create index if not exists convocatoria_scout_requests_club_user_idx
  on public.convocatoria_scout_requests (club_user_id, created_at desc);

alter table public.convocatoria_scout_requests enable row level security;

drop policy if exists convocatoria_scout_requests_select_actor
  on public.convocatoria_scout_requests;
create policy convocatoria_scout_requests_select_actor
  on public.convocatoria_scout_requests
  for select
  to authenticated
  using (
    scout_id::text = auth.uid()::text
    or club_user_id::text = auth.uid()::text
    or exists (
      select 1
      from public.convocatorias c
      left join public.clubs cl on cl.id::text = c.club_id::text
      left join public.club_staff cs on cs.club_id::text = c.club_id::text
        and cs.user_id::text = auth.uid()::text
      where c.id::text = convocatoria_scout_requests.convocatoria_id::text
        and (
          c.club_id::text = auth.uid()::text
          or cl.owner_id::text = auth.uid()::text
          or cs.user_id is not null
        )
    )
  );

drop policy if exists convocatoria_scout_requests_insert_scout
  on public.convocatoria_scout_requests;
create policy convocatoria_scout_requests_insert_scout
  on public.convocatoria_scout_requests
  for insert
  to authenticated
  with check (
    scout_id::text = auth.uid()::text
    and lower(coalesce((
      select u."userType"
      from public.users u
      where u.user_id::text = auth.uid()::text
      limit 1
    ), '')) in ('profesional', 'profissional', 'professional', 'scout', 'scouter', 'scouting', 'oleador', 'ojeador')
  );

drop policy if exists convocatoria_scout_requests_update_scout_pending
  on public.convocatoria_scout_requests;
create policy convocatoria_scout_requests_update_scout_pending
  on public.convocatoria_scout_requests
  for update
  to authenticated
  using (
    scout_id::text = auth.uid()::text
    and lower(coalesce(status, 'pending')) in ('pending', 'pendiente')
  )
  with check (
    scout_id::text = auth.uid()::text
    and lower(coalesce(status, 'pending')) in ('pending', 'pendiente')
  );

drop policy if exists convocatoria_scout_requests_update_club
  on public.convocatoria_scout_requests;
create policy convocatoria_scout_requests_update_club
  on public.convocatoria_scout_requests
  for update
  to authenticated
  using (
    club_user_id::text = auth.uid()::text
    or exists (
      select 1
      from public.convocatorias c
      left join public.clubs cl on cl.id::text = c.club_id::text
      left join public.club_staff cs on cs.club_id::text = c.club_id::text
        and cs.user_id::text = auth.uid()::text
      where c.id::text = convocatoria_scout_requests.convocatoria_id::text
        and (
          c.club_id::text = auth.uid()::text
          or cl.owner_id::text = auth.uid()::text
          or cs.user_id is not null
        )
    )
  )
  with check (true);

do $$
begin
  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'set_updated_at'
  ) then
    drop trigger if exists set_updated_at_convocatoria_scout_requests
      on public.convocatoria_scout_requests;
    create trigger set_updated_at_convocatoria_scout_requests
      before update on public.convocatoria_scout_requests
      for each row
      execute procedure public.set_updated_at();
  end if;
end $$;

revoke all on public.convocatoria_scout_requests from anon;
revoke all on public.convocatoria_scout_requests from authenticated;
grant select, insert, update on public.convocatoria_scout_requests to authenticated;

commit;
