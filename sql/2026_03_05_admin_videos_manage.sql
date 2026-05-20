begin;

-- Cria helper para verificar se o usuario autenticado e admin
do $$
declare
  user_type_col text;
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'users'
      and column_name = 'userType'
  ) then
    user_type_col := '"userType"';
  elsif exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'users'
      and column_name = 'usertype'
  ) then
    user_type_col := 'usertype';
  else
    return;
  end if;

  execute format(
    $sql$
      create or replace function public.is_admin_user(target_uid uuid default auth.uid())
      returns boolean
      language sql
      stable
      security definer
      set search_path = public
      as $fn$
        select exists (
          select 1
          from public.users u
          where u.user_id::text = target_uid::text
            and lower(coalesce(u.%1$s::text, '')) = 'admin'
        );
      $fn$;
    $sql$,
    user_type_col
  );
end $$;

grant execute on function public.is_admin_user(uuid) to authenticated;

-- Permissoes de admin para gerenciar videos
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
      and policyname = 'videos_admin_select_all'
  ) then
    create policy videos_admin_select_all
      on public.videos
      for select
      to authenticated
      using (public.is_admin_user(auth.uid()));
  end if;
end $$;

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
      and policyname = 'videos_admin_update_all'
  ) then
    create policy videos_admin_update_all
      on public.videos
      for update
      to authenticated
      using (public.is_admin_user(auth.uid()))
      with check (public.is_admin_user(auth.uid()));
  end if;
end $$;

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
      and policyname = 'videos_admin_delete_all'
  ) then
    create policy videos_admin_delete_all
      on public.videos
      for delete
      to authenticated
      using (public.is_admin_user(auth.uid()));
  end if;
end $$;

commit;
