-- ============================================================
-- Fechamento MVP — Migrations
-- 6.1  Snapshot table for convocatória applications (imutável)
-- 5.2  Challenge validity (90 days)
-- 5.3  Allow multiple attempts per challenge
-- 3.1  Video content_type column
-- 1.5  Age change triggers guardian check
-- ============================================================

begin;

create extension if not exists pgcrypto;

-- ============================================================
-- 3.1 Video content_type (video, desafio, convocatoria)
-- ============================================================

alter table if exists public.videos
  add column if not exists content_type text not null default 'video';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.videos'::regclass
      and conname = 'videos_content_type_check'
  ) then
    alter table public.videos
      add constraint videos_content_type_check
      check (content_type in ('video', 'desafio', 'convocatoria'));
  end if;
end $$;

-- Backfill: marcar vídeos de desafio existentes
update public.videos
set content_type = 'desafio'
where content_type = 'video'
  and (
    coalesce(description, '') ~ '\[challenge_ref:(course|exercise):[^\]]+\]'
    or lower(coalesce(title, '')) like 'desafío:%'
    or lower(coalesce(title, '')) like 'desafio:%'
    or lower(coalesce(title, '')) like 'challenge:%'
  );

create index if not exists videos_content_type_idx
  on public.videos (content_type);

-- ============================================================
-- 5.2 Challenge validity — add valid_until column
-- ============================================================

alter table if exists public.user_challenge_attempts
  add column if not exists valid_until timestamptz;

-- Backfill: set valid_until = submitted_at + 90 days for existing rows
update public.user_challenge_attempts
set valid_until = submitted_at + interval '90 days'
where valid_until is null
  and submitted_at is not null;

-- Trigger: auto-set valid_until on insert
create or replace function public.set_challenge_attempt_validity()
returns trigger
language plpgsql
as $$
begin
  if new.valid_until is null and new.submitted_at is not null then
    new.valid_until := new.submitted_at + interval '90 days';
  end if;
  return new;
end;
$$;

do $$
begin
  if exists (
    select 1 from pg_trigger
    where tgname = 'trg_set_challenge_attempt_validity'
  ) then
    drop trigger trg_set_challenge_attempt_validity
      on public.user_challenge_attempts;
  end if;

  create trigger trg_set_challenge_attempt_validity
    before insert or update on public.user_challenge_attempts
    for each row
    execute function public.set_challenge_attempt_validity();
end $$;

-- ============================================================
-- 5.3 Allow multiple attempts per challenge
-- Drop the unique constraint to allow multiple attempts
-- ============================================================

do $$
begin
  if exists (
    select 1
    from pg_constraint
    where conrelid = 'public.user_challenge_attempts'::regclass
      and conname = 'user_challenge_attempts_user_id_item_id_item_type_key'
  ) then
    alter table public.user_challenge_attempts
      drop constraint user_challenge_attempts_user_id_item_id_item_type_key;
  end if;
end $$;

-- Add a new non-unique index for lookups
create index if not exists user_challenge_attempts_multi_idx
  on public.user_challenge_attempts (user_id, item_id, item_type, submitted_at desc);

-- ============================================================
-- 6.1 Snapshot table for convocatória applications
-- ============================================================

create table if not exists public.convocatoria_application_snapshots (
  id uuid primary key default gen_random_uuid(),
  convocatoria_id text not null,
  player_id text not null,
  snapshot_data jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  unique (convocatoria_id, player_id)
);

create index if not exists conv_snapshot_convocatoria_idx
  on public.convocatoria_application_snapshots (convocatoria_id);

create index if not exists conv_snapshot_player_idx
  on public.convocatoria_application_snapshots (player_id);

alter table public.convocatoria_application_snapshots enable row level security;

-- Player can see their own snapshots
do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'convocatoria_application_snapshots'
      and policyname = 'snapshot_select_player'
  ) then
    create policy snapshot_select_player
      on public.convocatoria_application_snapshots
      for select
      to authenticated
      using (player_id::text = auth.uid()::text);
  end if;
end $$;

-- Player can insert their own snapshots
do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'convocatoria_application_snapshots'
      and policyname = 'snapshot_insert_player'
  ) then
    create policy snapshot_insert_player
      on public.convocatoria_application_snapshots
      for insert
      to authenticated
      with check (player_id::text = auth.uid()::text);
  end if;
end $$;

-- Club owner/staff can see snapshots for their convocatorias
do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'convocatoria_application_snapshots'
      and policyname = 'snapshot_select_club'
  ) then
    create policy snapshot_select_club
      on public.convocatoria_application_snapshots
      for select
      to authenticated
      using (
        exists (
          select 1
          from public.convocatorias c
          left join public.clubs cl on cl.id::text = c.club_id::text
          left join public.club_staff cs
            on cs.club_id::text = cl.id::text
            and cs.user_id::text = auth.uid()::text
          where c.id::text = convocatoria_application_snapshots.convocatoria_id::text
            and (
              c.club_id::text = auth.uid()::text
              or cl.owner_id::text = auth.uid()::text
              or cs.user_id::text = auth.uid()::text
            )
        )
      );
  end if;
end $$;

-- NO delete or update policy — snapshots are immutable (6.1)

-- ============================================================
-- 9.1 Age matching — add min/max age to convocatorias
-- ============================================================

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'convocatorias'
  ) then
    alter table public.convocatorias
      add column if not exists min_age integer;
    alter table public.convocatorias
      add column if not exists max_age integer;
  end if;
end $$;

commit;
