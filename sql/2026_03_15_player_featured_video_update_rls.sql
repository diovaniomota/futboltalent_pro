begin;

alter table if exists public.videos enable row level security;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'videos'
  ) and not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'videos'
      and policyname = 'videos_player_update_own'
  ) then
    create policy videos_player_update_own
      on public.videos
      for update
      to authenticated
      using (user_id::text = auth.uid()::text)
      with check (user_id::text = auth.uid()::text);
  end if;
end $$;

commit;
