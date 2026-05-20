begin;

alter table if exists public.saved_videos enable row level security;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'saved_videos'
  ) and not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'saved_videos'
      and policyname = 'saved_videos_select_own'
  ) then
    create policy saved_videos_select_own
      on public.saved_videos
      for select
      to authenticated
      using (user_id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'saved_videos'
  ) and not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'saved_videos'
      and policyname = 'saved_videos_insert_own'
  ) then
    create policy saved_videos_insert_own
      on public.saved_videos
      for insert
      to authenticated
      with check (user_id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'saved_videos'
  ) and not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'saved_videos'
      and policyname = 'saved_videos_update_own'
  ) then
    create policy saved_videos_update_own
      on public.saved_videos
      for update
      to authenticated
      using (user_id::text = auth.uid()::text)
      with check (user_id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'saved_videos'
  ) and not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'saved_videos'
      and policyname = 'saved_videos_delete_own'
  ) then
    create policy saved_videos_delete_own
      on public.saved_videos
      for delete
      to authenticated
      using (user_id::text = auth.uid()::text);
  end if;
end $$;

commit;
