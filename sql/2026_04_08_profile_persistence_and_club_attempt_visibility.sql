begin;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'users'
  ) then
    alter table public.users add column if not exists updated_at timestamptz default now();
    alter table public.users add column if not exists cover_url text;
    alter table public.users add column if not exists bio text;
    alter table public.users add column if not exists descripcion text;
    alter table public.users add column if not exists colaboraciones text;
    alter table public.users add column if not exists pie_dominante text;
    alter table public.users add column if not exists juega_en_club boolean default false;
    alter table public.users add column if not exists historial_clubes jsonb default '[]'::jsonb;
    alter table public.users add column if not exists player_status text;
    alter table public.users add column if not exists club_actual text;
    alter table public.users add column if not exists lugar text;
    alter table public.users add column if not exists birth_date timestamptz;

    update public.users
    set birth_date = birthday
    where birth_date is null
      and birthday is not null;

    update public.users
    set birthday = birth_date
    where birthday is null
      and birth_date is not null;

    update public.users
    set historial_clubes = '[]'::jsonb
    where historial_clubes is null;
  end if;
end $$;

create or replace function public.sync_users_birth_fields()
returns trigger
language plpgsql
as $$
begin
  if new.birth_date is null and new.birthday is not null then
    new.birth_date := new.birthday;
  end if;

  if new.birthday is null and new.birth_date is not null then
    new.birthday := new.birth_date;
  end if;

  new.updated_at := now();
  return new;
end;
$$;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'users'
  ) then
    if exists (
      select 1
      from pg_trigger
      where tgname = 'sync_users_birth_fields_trigger'
    ) then
      drop trigger sync_users_birth_fields_trigger on public.users;
    end if;

    create trigger sync_users_birth_fields_trigger
      before insert or update on public.users
      for each row
      execute function public.sync_users_birth_fields();
  end if;
end $$;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'clubs'
  ) then
    alter table public.clubs add column if not exists max_convocatorias integer default 20;

    update public.clubs
    set max_convocatorias = 20
    where max_convocatorias is null;
  end if;
end $$;

do $$
declare
  v_has_post_jugador_id boolean := false;
  v_has_post_player_id boolean := false;
  v_post_match_expr text;
  v_post_clause text := '';
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'user_challenge_attempts'
  ) then
    drop policy if exists user_challenge_attempts_select_club_convocatoria
      on public.user_challenge_attempts;

    select exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'postulaciones'
        and column_name = 'jugador_id'
    ) into v_has_post_jugador_id;

    select exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'postulaciones'
        and column_name = 'player_id'
    ) into v_has_post_player_id;

    if v_has_post_jugador_id and v_has_post_player_id then
      v_post_match_expr := 'coalesce(p.jugador_id::text, p.player_id::text)';
    elsif v_has_post_jugador_id then
      v_post_match_expr := 'p.jugador_id::text';
    elsif v_has_post_player_id then
      v_post_match_expr := 'p.player_id::text';
    end if;

    if v_post_match_expr is not null then
      v_post_clause := format(
        $post_clause$
          or exists (
            select 1
            from public.convocatorias c
            left join public.clubs cl
              on cl.id::text = c.club_id::text
            left join public.club_staff cs
              on cs.club_id::text = cl.id::text
             and cs.user_id::text = auth.uid()::text
            where (
                c.club_id::text = auth.uid()::text
                or cl.owner_id::text = auth.uid()::text
                or cs.user_id::text = auth.uid()::text
              )
              and exists (
                select 1
                from public.postulaciones p
                where p.convocatoria_id::text = c.id::text
                  and %s = user_challenge_attempts.user_id::text
              )
              and exists (
                select 1
                from jsonb_array_elements(coalesce(c.required_challenges, '[]'::jsonb)) as req(value)
                where lower(coalesce(req.value ->> 'type', '')) =
                        lower(coalesce(user_challenge_attempts.item_type, ''))
                  and coalesce(req.value ->> 'id', '') =
                        coalesce(user_challenge_attempts.item_id, '')
              )
          )
        $post_clause$,
        v_post_match_expr
      );
    end if;

    execute format(
      $policy$
      create policy user_challenge_attempts_select_club_convocatoria
        on public.user_challenge_attempts
        for select
        to authenticated
        using (
          user_id::text = auth.uid()::text
          or exists (
            select 1
            from public.convocatorias c
            left join public.clubs cl
              on cl.id::text = c.club_id::text
            left join public.club_staff cs
              on cs.club_id::text = cl.id::text
             and cs.user_id::text = auth.uid()::text
            where (
                c.club_id::text = auth.uid()::text
                or cl.owner_id::text = auth.uid()::text
                or cs.user_id::text = auth.uid()::text
              )
              and exists (
                select 1
                from public.aplicaciones_convocatoria ac
                where ac.convocatoria_id::text = c.id::text
                  and ac.jugador_id::text = user_challenge_attempts.user_id::text
              )
              and exists (
                select 1
                from jsonb_array_elements(coalesce(c.required_challenges, '[]'::jsonb)) as req(value)
                where lower(coalesce(req.value ->> 'type', '')) =
                        lower(coalesce(user_challenge_attempts.item_type, ''))
                  and coalesce(req.value ->> 'id', '') =
                        coalesce(user_challenge_attempts.item_id, '')
              )
          )
          %s
        )
      $policy$,
      v_post_clause
    );
  end if;
end $$;

commit;
