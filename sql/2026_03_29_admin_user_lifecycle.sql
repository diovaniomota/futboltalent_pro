begin;

create extension if not exists pgcrypto;

create or replace function public.admin_get_capabilities()
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_is_admin boolean := public.is_admin_user(auth.uid());
begin
  return jsonb_build_object(
    'is_admin', v_is_admin,
    'can_create_users', v_is_admin,
    'can_edit_users', v_is_admin,
    'can_delete_users', v_is_admin,
    'can_create_auth_users', v_is_admin,
    'can_delete_auth_users', v_is_admin,
    'can_manage_admin_settings', v_is_admin,
    'mode', case when v_is_admin then 'full' else 'restricted' end
  );
end;
$$;

revoke all on function public.admin_get_capabilities() from public;
grant execute on function public.admin_get_capabilities() to authenticated;

create or replace function public.admin_create_managed_user(
  p_email text,
  p_password text,
  p_name text,
  p_lastname text default '',
  p_username text default null,
  p_user_type text default 'jugador',
  p_plan_id integer default 1,
  p_city text default null,
  p_country text default null,
  p_position text default null,
  p_category text default null,
  p_birthday timestamptz default null,
  p_is_verified boolean default false,
  p_create_auth_user boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := gen_random_uuid();
  v_now timestamptz := now();
  v_email text := lower(nullif(trim(coalesce(p_email, '')), ''));
  v_password text := coalesce(p_password, '');
  v_name text := nullif(trim(coalesce(p_name, '')), '');
  v_lastname text := trim(coalesce(p_lastname, ''));
  v_username text := nullif(trim(coalesce(p_username, '')), '');
  v_user_type text := lower(trim(coalesce(p_user_type, 'jugador')));
  v_plan_id integer := greatest(coalesce(p_plan_id, 1), 1);
begin
  if not public.is_admin_user(auth.uid()) then
    raise exception 'admin_only';
  end if;

  if v_name is null then
    v_name := 'Usuario';
  end if;

  if v_user_type not in ('jugador', 'profesional', 'club', 'admin') then
    v_user_type := 'jugador';
  end if;

  if v_username is null then
    if v_email is not null then
      v_username := split_part(v_email, '@', 1);
    else
      v_username := regexp_replace(
        lower(v_name || '_' || left(v_user_id::text, 8)),
        '[^a-z0-9_]+',
        '_',
        'g'
      );
    end if;
  end if;

  if p_create_auth_user then
    if v_email is null then
      raise exception 'email_required';
    end if;

    if length(v_password) < 8 then
      raise exception 'password_too_short';
    end if;

    if exists (
      select 1
      from auth.users
      where lower(coalesce(email, '')) = v_email
    ) then
      raise exception 'email_exists';
    end if;

    insert into auth.users (
      id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at
    )
    values (
      v_user_id,
      'authenticated',
      'authenticated',
      v_email,
      crypt(v_password, gen_salt('bf')),
      v_now,
      jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email')),
      jsonb_build_object(
        'name', v_name,
        'lastname', v_lastname,
        'userType', v_user_type
      ),
      v_now,
      v_now
    );

    insert into auth.identities (
      provider_id,
      user_id,
      identity_data,
      provider,
      last_sign_in_at,
      created_at,
      updated_at
    )
    values (
      v_user_id::text,
      v_user_id,
      jsonb_build_object(
        'sub', v_user_id::text,
        'email', v_email
      ),
      'email',
      v_now,
      v_now,
      v_now
    );
  end if;

  insert into public.users (
    user_id,
    name,
    lastname,
    username,
    "userType",
    plan_id,
    role_id,
    country_id,
    created_at,
    city,
    country,
    pais,
    posicion,
    categoria,
    birthday,
    verification_status,
    is_verified,
    is_admin
  )
  values (
    v_user_id,
    v_name,
    v_lastname,
    v_username,
    v_user_type,
    v_plan_id,
    1,
    1,
    v_now,
    nullif(trim(coalesce(p_city, '')), ''),
    nullif(trim(coalesce(p_country, '')), ''),
    nullif(trim(coalesce(p_country, '')), ''),
    nullif(trim(coalesce(p_position, '')), ''),
    nullif(trim(coalesce(p_category, '')), ''),
    p_birthday,
    case when p_is_verified then 'verified' else 'pending' end,
    p_is_verified,
    v_user_type = 'admin'
  );

  if v_user_type = 'jugador' then
    insert into public.players (id, created_at)
    values (v_user_id, v_now)
    on conflict do nothing;
  elsif v_user_type = 'profesional' then
    insert into public.scouts (id, created_at, telephone, club)
    values (v_user_id, v_now, '', '')
    on conflict do nothing;
  elsif v_user_type = 'club' then
    insert into public.clubs (owner_id, nombre, created_at)
    values (v_user_id, v_name, v_now)
    on conflict do nothing;
  end if;

  return jsonb_build_object(
    'user_id', v_user_id,
    'created_auth_account', p_create_auth_user,
    'message', case
      when p_create_auth_user then 'Usuario creado con acceso al app.'
      else 'Perfil operativo creado.'
    end
  );
end;
$$;

revoke all on function public.admin_create_managed_user(text, text, text, text, text, text, integer, text, text, text, text, timestamptz, boolean, boolean) from public;
grant execute on function public.admin_create_managed_user(text, text, text, text, text, text, integer, text, text, text, text, timestamptz, boolean, boolean) to authenticated;

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
