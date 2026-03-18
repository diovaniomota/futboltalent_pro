begin;

alter table if exists public.videos
  add column if not exists "videoType" text;

update public.videos
set "videoType" = case
  when coalesce(description, '') ~ '\\[challenge_ref:(course|exercise):[^\\]]+\\]' then 'challenge'
  when lower(coalesce(title, '')) like 'desafío:%' then 'challenge'
  when lower(coalesce(title, '')) like 'desafio:%' then 'challenge'
  when lower(coalesce(title, '')) like 'challenge:%' then 'challenge'
  else 'ugc'
end
where "videoType" is null
   or btrim("videoType") = ''
   or lower("videoType") not in ('ugc', 'challenge');

alter table if exists public.videos
  alter column "videoType" set default 'ugc';

update public.videos
set "videoType" = 'ugc'
where "videoType" is null;

alter table if exists public.videos
  alter column "videoType" set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.videos'::regclass
      and conname = 'videos_videoType_check'
  ) then
    alter table public.videos
      add constraint videos_videoType_check
      check ("videoType" in ('ugc', 'challenge'));
  end if;
end $$;

create index if not exists videos_videoType_idx
  on public.videos ("videoType");

comment on column public.videos."videoType" is
  'Origem do vídeo publicado pelo jogador: ugc ou challenge.';

commit;
