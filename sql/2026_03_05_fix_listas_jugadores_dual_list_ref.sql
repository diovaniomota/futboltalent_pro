begin;

-- Em alguns ambientes, listas_jugadores.lista_id ficou preso por FK
-- a apenas uma tabela (listas ou listas_club). Para suportar os dois
-- fluxos (Scout e Club), removemos a FK rígida e validamos por trigger.

do $$
begin
  if exists (
    select 1
    from pg_constraint
    where conrelid = 'public.listas_jugadores'::regclass
      and conname = 'listas_jugadores_lista_id_fkey'
  ) then
    alter table public.listas_jugadores
      drop constraint listas_jugadores_lista_id_fkey;
  end if;
end $$;

create or replace function public.validate_lista_id_in_any_list()
returns trigger
language plpgsql
as $$
declare
  exists_in_listas boolean := false;
  exists_in_listas_club boolean := false;
begin
  if new.lista_id is null or btrim(new.lista_id::text) = '' then
    raise exception 'lista_id inválido';
  end if;

  if to_regclass('public.listas') is not null then
    select exists (
      select 1
      from public.listas l
      where l.id::text = new.lista_id::text
    ) into exists_in_listas;
  end if;

  if to_regclass('public.listas_club') is not null then
    select exists (
      select 1
      from public.listas_club lc
      where lc.id::text = new.lista_id::text
    ) into exists_in_listas_club;
  end if;

  if not exists_in_listas and not exists_in_listas_club then
    raise exception using
      errcode = '23503',
      message = format(
        'lista_id %s não existe em listas nem em listas_club',
        quote_literal(new.lista_id::text)
      );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_lista_id_in_any_list on public.listas_jugadores;

create trigger trg_validate_lista_id_in_any_list
before insert or update of lista_id
on public.listas_jugadores
for each row
execute function public.validate_lista_id_in_any_list();

commit;

