begin;

create extension if not exists pgcrypto;

-- Detecta a coluna de tipo de usuário na tabela public.users
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

-- ===============================
-- user_challenge_attempts
-- ===============================
do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'user_challenge_attempts'
  ) and not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_challenge_attempts'
      and policyname = 'user_challenge_attempts_select_admin_all'
  ) then
    create policy user_challenge_attempts_select_admin_all
      on public.user_challenge_attempts
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
      and table_name = 'user_challenge_attempts'
  ) and not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_challenge_attempts'
      and policyname = 'user_challenge_attempts_update_admin_all'
  ) then
    create policy user_challenge_attempts_update_admin_all
      on public.user_challenge_attempts
      for update
      to authenticated
      using (public.is_admin_user(auth.uid()))
      with check (public.is_admin_user(auth.uid()));
  end if;
end $$;

-- ===============================
-- user_challenge_goals
-- ===============================
do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'user_challenge_goals'
  ) and not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_challenge_goals'
      and policyname = 'user_challenge_goals_select_admin_all'
  ) then
    create policy user_challenge_goals_select_admin_all
      on public.user_challenge_goals
      for select
      to authenticated
      using (public.is_admin_user(auth.uid()));
  end if;
end $$;

-- ===============================
-- courses / exercises (admin CRUD)
-- ===============================
do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'courses'
  ) and not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'courses'
      and policyname = 'courses_admin_manage'
  ) then
    create policy courses_admin_manage
      on public.courses
      for all
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
      and table_name = 'exercises'
  ) and not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'exercises'
      and policyname = 'exercises_admin_manage'
  ) then
    create policy exercises_admin_manage
      on public.exercises
      for all
      to authenticated
      using (public.is_admin_user(auth.uid()))
      with check (public.is_admin_user(auth.uid()));
  end if;
end $$;

commit;
