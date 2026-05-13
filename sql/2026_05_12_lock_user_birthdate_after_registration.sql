-- =====================================================================
-- FutbolTalent Pro - Profile security hardening
-- BUG-PRF-002: fecha de nacimiento no editable después del registro
--
-- APLICAR NO SUPABASE SQL EDITOR:
-- Dashboard -> SQL Editor -> New query -> Colar e executar
-- =====================================================================

begin;

do $$
begin
  if to_regclass('public.users') is not null then
    -- Normaliza registros antigos usando birthday como fonte principal.
    with normalized as (
      select
        user_id,
        coalesce(birthday, birth_date::date) as locked_birth
      from public.users
    )
    update public.users u
    set
      birthday = n.locked_birth,
      birth_date = n.locked_birth::timestamptz
    from normalized n
    where u.user_id = n.user_id
      and n.locked_birth is not null
      and (
        u.birthday is distinct from n.locked_birth
        or u.birth_date is null
        or u.birth_date::date is distinct from n.locked_birth
      );
  end if;
end;
$$;

create or replace function public.sync_users_birth_fields()
returns trigger
language plpgsql
as $$
declare
  locked_birth date;
begin
  if tg_op = 'UPDATE' then
    locked_birth := coalesce(old.birthday, old.birth_date::date);

    if locked_birth is not null then
      if new.birthday is not null and new.birthday is distinct from locked_birth then
        raise exception 'birthdate_is_immutable'
          using errcode = '23514';
      end if;

      if new.birth_date is not null and new.birth_date::date is distinct from locked_birth then
        raise exception 'birthdate_is_immutable'
          using errcode = '23514';
      end if;

      new.birthday := locked_birth;
      new.birth_date := locked_birth::timestamptz;
    else
      if new.birthday is not null
          and new.birth_date is not null
          and new.birth_date::date is distinct from new.birthday then
        raise exception 'birthdate_fields_mismatch'
          using errcode = '23514';
      end if;

      if new.birth_date is null and new.birthday is not null then
        new.birth_date := new.birthday::timestamptz;
      end if;

      if new.birthday is null and new.birth_date is not null then
        new.birthday := new.birth_date::date;
      end if;
    end if;
  else
    if new.birthday is not null
        and new.birth_date is not null
        and new.birth_date::date is distinct from new.birthday then
      raise exception 'birthdate_fields_mismatch'
        using errcode = '23514';
    end if;

    if new.birth_date is null and new.birthday is not null then
      new.birth_date := new.birthday::timestamptz;
    end if;

    if new.birthday is null and new.birth_date is not null then
      new.birthday := new.birth_date::date;
    end if;
  end if;

  new.updated_at := now();
  return new;
end;
$$;

do $$
begin
  if to_regclass('public.users') is not null then
    drop trigger if exists sync_users_birth_fields_trigger on public.users;

    create trigger sync_users_birth_fields_trigger
      before insert or update on public.users
      for each row
      execute function public.sync_users_birth_fields();
  end if;
end;
$$;

commit;

-- VERIFICAÇÃO:
-- Tentar atualizar birthday/birth_date de um usuário que já tem data deve falhar:
-- update public.users set birthday = date '2014-01-01' where user_id = '<uid>';
