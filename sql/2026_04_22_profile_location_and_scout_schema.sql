begin;

do $$
declare
  col text;
begin
  if to_regclass('public.users') is not null then
    alter table public.users add column if not exists city text;
    alter table public.users add column if not exists ciudad text;
    alter table public.users add column if not exists country text;
    alter table public.users add column if not exists pais text;
    alter table public.users add column if not exists state text;
    alter table public.users add column if not exists estado text;
    alter table public.users add column if not exists province text;
    alter table public.users add column if not exists provincia text;
    alter table public.users add column if not exists region text;

    alter table public.users add column if not exists "current_role" text;
    alter table public.users add column if not exists rol_actual text;
    alter table public.users add column if not exists organization_type text;
    alter table public.users add column if not exists tipo_organizacion text;
    alter table public.users add column if not exists work_zone text;
    alter table public.users add column if not exists zona_trabajo text;
    alter table public.users add column if not exists interest_categories text;
    alter table public.users add column if not exists categorias_interes text;
    alter table public.users add column if not exists interest_positions text;
    alter table public.users add column if not exists posiciones_interes text;

    update public.users
    set
      ciudad = coalesce(nullif(ciudad, ''), nullif(city, '')),
      city = coalesce(nullif(city, ''), nullif(ciudad, '')),
      estado = coalesce(nullif(estado, ''), nullif(state, ''), nullif(province, ''), nullif(provincia, ''), nullif(region, '')),
      state = coalesce(nullif(state, ''), nullif(estado, ''), nullif(province, ''), nullif(provincia, ''), nullif(region, '')),
      province = coalesce(nullif(province, ''), nullif(state, ''), nullif(estado, ''), nullif(provincia, ''), nullif(region, '')),
      provincia = coalesce(nullif(provincia, ''), nullif(state, ''), nullif(estado, ''), nullif(province, ''), nullif(region, '')),
      pais = coalesce(nullif(pais, ''), nullif(country, '')),
      country = coalesce(nullif(country, ''), nullif(pais, ''))
    where true;
  end if;

  if to_regclass('public.scouts') is not null then
    alter table public.scouts add column if not exists organization_type text;
    alter table public.scouts add column if not exists "current_role" text;
    alter table public.scouts add column if not exists work_zone text;
    alter table public.scouts add column if not exists interest_categories text;
    alter table public.scouts add column if not exists interest_positions text;
    alter table public.scouts add column if not exists url_profesional text;
    alter table public.scouts add column if not exists city text;
    alter table public.scouts add column if not exists ciudad text;
    alter table public.scouts add column if not exists country text;
    alter table public.scouts add column if not exists pais text;
    alter table public.scouts add column if not exists state text;
    alter table public.scouts add column if not exists estado text;
    alter table public.scouts add column if not exists province text;
    alter table public.scouts add column if not exists provincia text;
    alter table public.scouts add column if not exists region text;

    update public.scouts
    set
      ciudad = coalesce(nullif(ciudad, ''), nullif(city, '')),
      city = coalesce(nullif(city, ''), nullif(ciudad, '')),
      estado = coalesce(nullif(estado, ''), nullif(state, ''), nullif(province, ''), nullif(provincia, ''), nullif(region, '')),
      state = coalesce(nullif(state, ''), nullif(estado, ''), nullif(province, ''), nullif(provincia, ''), nullif(region, '')),
      province = coalesce(nullif(province, ''), nullif(state, ''), nullif(estado, ''), nullif(provincia, ''), nullif(region, '')),
      provincia = coalesce(nullif(provincia, ''), nullif(state, ''), nullif(estado, ''), nullif(province, ''), nullif(region, '')),
      pais = coalesce(nullif(pais, ''), nullif(country, '')),
      country = coalesce(nullif(country, ''), nullif(pais, ''))
    where true;
  end if;

  if to_regclass('public.clubes') is not null then
    foreach col in array array[
      'id',
      'email',
      'telephone',
      'nombre_corto',
      'liga',
      'sitio_web',
      'state',
      'city',
      'country',
      'estado',
      'ciudad',
      'pais'
    ] loop
      if exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'clubes'
          and column_name = col
          and data_type = 'character varying'
          and coalesce(character_maximum_length, 0) > 0
          and character_maximum_length < 128
      ) then
        execute format(
          'alter table public.clubes alter column %I type text using %I::text',
          col,
          col
        );
      end if;
    end loop;
  end if;
end $$;

commit;
