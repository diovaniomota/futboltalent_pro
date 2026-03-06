begin;

-- Garante RLS ativado (sem alterar schema além disso)
alter table if exists public.players enable row level security;
alter table if exists public.guardians enable row level security;

-- PLAYERS: cada usuário autenticado gerencia apenas sua própria linha (id = auth.uid)
do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'players'
  ) and not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'players'
      and policyname = 'players_select_own'
  ) then
    create policy players_select_own
      on public.players
      for select
      to authenticated
      using (id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'players'
  ) and not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'players'
      and policyname = 'players_insert_own'
  ) then
    create policy players_insert_own
      on public.players
      for insert
      to authenticated
      with check (id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'players'
  ) and not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'players'
      and policyname = 'players_update_own'
  ) then
    create policy players_update_own
      on public.players
      for update
      to authenticated
      using (id::text = auth.uid()::text)
      with check (id::text = auth.uid()::text);
  end if;
end $$;

-- GUARDIANS: cada usuário autenticado gerencia o guardian vinculado ao seu player_id
do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'guardians'
  ) and not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'guardians'
      and policyname = 'guardians_select_own_player'
  ) then
    create policy guardians_select_own_player
      on public.guardians
      for select
      to authenticated
      using (player_id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'guardians'
  ) and not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'guardians'
      and policyname = 'guardians_insert_own_player'
  ) then
    create policy guardians_insert_own_player
      on public.guardians
      for insert
      to authenticated
      with check (player_id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'guardians'
  ) and not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'guardians'
      and policyname = 'guardians_update_own_player'
  ) then
    create policy guardians_update_own_player
      on public.guardians
      for update
      to authenticated
      using (player_id::text = auth.uid()::text)
      with check (player_id::text = auth.uid()::text);
  end if;
end $$;

commit;
