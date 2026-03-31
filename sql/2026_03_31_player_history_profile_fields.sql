begin;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'users'
  ) then
    alter table public.users
      add column if not exists historial_clubes jsonb not null default '[]'::jsonb;
  end if;
end $$;

commit;
