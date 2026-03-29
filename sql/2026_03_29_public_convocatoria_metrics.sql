begin;

create or replace function public.public_convocatoria_application_counts(
  p_convocatoria_ids text[] default null
)
returns table(
  convocatoria_id text,
  applications_count bigint
)
language plpgsql
security definer
set search_path = public
as $$
declare
  sources text[] := array[]::text[];
  query_text text;
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'aplicaciones_convocatoria'
  ) then
    sources := array_append(
      sources,
      'select convocatoria_id::text as convocatoria_id from public.aplicaciones_convocatoria'
    );
  end if;

  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'postulaciones'
  ) then
    sources := array_append(
      sources,
      'select convocatoria_id::text as convocatoria_id from public.postulaciones'
    );
  end if;

  if coalesce(array_length(sources, 1), 0) = 0 then
    return;
  end if;

  query_text :=
      'select convocatoria_id, count(*)::bigint as applications_count ' ||
      'from (' || array_to_string(sources, ' union all ') || ') src';

  if coalesce(array_length(p_convocatoria_ids, 1), 0) > 0 then
    query_text := query_text || ' where convocatoria_id = any ($1)';
  end if;

  query_text := query_text || ' group by convocatoria_id';

  if coalesce(array_length(p_convocatoria_ids, 1), 0) > 0 then
    return query execute query_text using p_convocatoria_ids;
  end if;

  return query execute query_text;
end;
$$;

revoke all on function public.public_convocatoria_application_counts(text[])
from public;

grant execute on function public.public_convocatoria_application_counts(text[])
to authenticated, anon;

commit;
