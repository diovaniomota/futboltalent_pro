begin;

create extension if not exists pgcrypto;

create table if not exists public.user_challenge_goals (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  item_id text not null,
  item_type text not null check (item_type in ('course', 'exercise')),
  saved_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, item_id, item_type)
);

create table if not exists public.user_challenge_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  item_id text not null,
  item_type text not null check (item_type in ('course', 'exercise')),
  video_id text,
  video_url text not null,
  status text not null default 'submitted'
    check (status in ('draft', 'submitted', 'rejected')),
  submitted_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, item_id, item_type)
);

create index if not exists user_challenge_goals_user_idx
  on public.user_challenge_goals (user_id);

create index if not exists user_challenge_attempts_user_idx
  on public.user_challenge_attempts (user_id);

create index if not exists user_challenge_attempts_lookup_idx
  on public.user_challenge_attempts (user_id, item_type, item_id, status);

create or replace function public.set_challenge_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
begin
  if not exists (
    select 1 from pg_trigger where tgname = 'set_updated_at_user_challenge_goals'
  ) then
    create trigger set_updated_at_user_challenge_goals
      before update on public.user_challenge_goals
      for each row
      execute function public.set_challenge_updated_at();
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_trigger where tgname = 'set_updated_at_user_challenge_attempts'
  ) then
    create trigger set_updated_at_user_challenge_attempts
      before update on public.user_challenge_attempts
      for each row
      execute function public.set_challenge_updated_at();
  end if;
end $$;

alter table public.user_challenge_goals enable row level security;
alter table public.user_challenge_attempts enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_challenge_goals'
      and policyname = 'user_challenge_goals_select_own'
  ) then
    create policy user_challenge_goals_select_own
      on public.user_challenge_goals
      for select
      to authenticated
      using (user_id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_challenge_goals'
      and policyname = 'user_challenge_goals_insert_own'
  ) then
    create policy user_challenge_goals_insert_own
      on public.user_challenge_goals
      for insert
      to authenticated
      with check (user_id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_challenge_goals'
      and policyname = 'user_challenge_goals_update_own'
  ) then
    create policy user_challenge_goals_update_own
      on public.user_challenge_goals
      for update
      to authenticated
      using (user_id::text = auth.uid()::text)
      with check (user_id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_challenge_goals'
      and policyname = 'user_challenge_goals_delete_own'
  ) then
    create policy user_challenge_goals_delete_own
      on public.user_challenge_goals
      for delete
      to authenticated
      using (user_id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_challenge_attempts'
      and policyname = 'user_challenge_attempts_select_own'
  ) then
    create policy user_challenge_attempts_select_own
      on public.user_challenge_attempts
      for select
      to authenticated
      using (user_id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_challenge_attempts'
      and policyname = 'user_challenge_attempts_insert_own'
  ) then
    create policy user_challenge_attempts_insert_own
      on public.user_challenge_attempts
      for insert
      to authenticated
      with check (user_id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_challenge_attempts'
      and policyname = 'user_challenge_attempts_update_own'
  ) then
    create policy user_challenge_attempts_update_own
      on public.user_challenge_attempts
      for update
      to authenticated
      using (user_id::text = auth.uid()::text)
      with check (user_id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_challenge_attempts'
      and policyname = 'user_challenge_attempts_delete_own'
  ) then
    create policy user_challenge_attempts_delete_own
      on public.user_challenge_attempts
      for delete
      to authenticated
      using (user_id::text = auth.uid()::text);
  end if;
end $$;

create or replace function public.enforce_exercise_completion_requires_attempt()
returns trigger
language plpgsql
as $$
begin
  if lower(coalesce(new.status::text, '')) = 'completed' then
    if not exists (
      select 1
      from public.user_challenge_attempts a
      where a.user_id::text = new.user_id::text
        and a.item_type = 'exercise'
        and a.item_id::text = new.exercise_id::text
        and a.status = 'submitted'
    ) then
      raise exception
        'No se puede completar el ejercicio sin un video de intento enviado.'
        using errcode = 'P0001',
              hint = 'Primero usá "Tentar desafío" y subí tu video.';
    end if;
  end if;
  return new;
end;
$$;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'user_exercises'
  ) then
    if exists (
      select 1 from pg_trigger
      where tgname = 'trg_user_exercises_require_attempt'
    ) then
      drop trigger trg_user_exercises_require_attempt on public.user_exercises;
    end if;

    create trigger trg_user_exercises_require_attempt
      before insert or update of status on public.user_exercises
      for each row
      execute function public.enforce_exercise_completion_requires_attempt();
  end if;
end $$;

commit;
