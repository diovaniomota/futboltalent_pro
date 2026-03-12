begin;

alter table if exists public.videos
  add column if not exists featured_in_explorer boolean not null default false;

comment on column public.videos.featured_in_explorer is
  'Quando true, o video gera bonus de +100 XP para o jogador no MVP de gamificacao.';

commit;
