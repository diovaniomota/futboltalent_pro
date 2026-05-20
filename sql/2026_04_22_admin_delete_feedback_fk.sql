begin;

do $$
begin
  if to_regclass('public.feedback') is not null
     and exists (
       select 1
       from information_schema.columns
       where table_schema = 'public'
         and table_name = 'feedback'
         and column_name = 'user_id'
     ) then
    alter table public.feedback alter column user_id drop not null;

    if exists (
      select 1
      from pg_constraint
      where conname = 'feedback_user_id_fkey'
        and conrelid = 'public.feedback'::regclass
    ) then
      alter table public.feedback drop constraint feedback_user_id_fkey;
    end if;

    if to_regclass('public.users') is not null
       and not exists (
         select 1
         from pg_constraint
         where conname = 'feedback_user_id_fkey'
           and conrelid = 'public.feedback'::regclass
       ) then
      alter table public.feedback
        add constraint feedback_user_id_fkey
        foreign key (user_id)
        references public.users(user_id)
        on update cascade
        on delete set null;
    end if;
  end if;
end $$;

create or replace function public.admin_delete_managed_user(
  p_user_id uuid,
  p_delete_auth_user boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.is_admin_user(auth.uid()) then
    raise exception 'admin_only';
  end if;

  delete from public.admin_user_feature_overrides
  where user_id::text = p_user_id::text;

  if to_regclass('public.feedback') is not null
     and exists (
       select 1
       from information_schema.columns
       where table_schema = 'public'
         and table_name = 'feedback'
         and column_name = 'user_id'
     ) then
    execute
      'update public.feedback set user_id = null where user_id::text = $1::text'
      using p_user_id;
  end if;

  delete from public.players
  where id::text = p_user_id::text;

  delete from public.scouts
  where id::text = p_user_id::text;

  delete from public.clubs
  where owner_id::text = p_user_id::text;

  delete from public.users
  where user_id::text = p_user_id::text;

  if p_delete_auth_user then
    begin
      delete from auth.sessions where user_id = p_user_id;
    exception
      when undefined_table then null;
    end;

    begin
      delete from auth.refresh_tokens where user_id = p_user_id;
    exception
      when undefined_table then null;
    end;

    delete from auth.identities
    where user_id = p_user_id;

    delete from auth.users
    where id = p_user_id;
  end if;

  return jsonb_build_object(
    'user_id', p_user_id,
    'deleted_auth_account', p_delete_auth_user,
    'message', case
      when p_delete_auth_user then 'Usuario y acceso eliminados correctamente.'
      else 'Perfil operativo eliminado.'
    end
  );
end;
$$;

revoke all on function public.admin_delete_managed_user(uuid, boolean) from public;
grant execute on function public.admin_delete_managed_user(uuid, boolean) to authenticated;

commit;
